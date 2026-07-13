import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/orthodox_easter.dart';

/// Официални празници по държава от Nager.Date (безплатно, без ключ, без
/// rate limit). Offline-first: тегли само при липсващ кеш, иначе ползва Hive.
///
/// Това е чиста HTTP заявка — НЕ брои към дневния AI лимит.
///
/// Кеш: Hive box "holidays", ключ "{country}_{year}" → JSON map
/// { "YYYY-MM-DD": "localName" }.
class HolidaysService {
  HolidaysService._internal();
  static final HolidaysService _instance = HolidaysService._internal();
  factory HolidaysService() => _instance;

  static const String boxName = 'holidays';
  static const String _prefEnabled = 'holidays_enabled';
  static const String _prefCountry = 'holidays_country';
  static const String _prefPromptShown = 'holidays_prompt_shown';

  /// Цвят на слоя „Официални празници" (различен от именните дни).
  static const int colorValue = 0xFFE53935; // червено

  /// Глобален превключвател — календарът слуша за мигновен отговор
  /// (екраните живеят в IndexedStack).
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// Увеличава се при всяка промяна на заредените данни (нова държава, нов
  /// fetch). Календарът слуша този notifier, за да пререндерира маркерите
  /// след асинхронното зареждане.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Заредени празници за бърз достъп: "YYYY-MM-DD" → localName.
  final Map<String, String> _byDate = {};
  String _country = 'BG';

  String get country => _country;

  /// Авто-определя държавата от device locale (БЕЗ GPS/permission).
  static String detectCountry() {
    final cc = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (cc != null && cc.trim().isNotEmpty) return cc.toUpperCase();
    return 'BG';
  }

  // --- Настройки ---

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefEnabled) ?? false;
    _country = prefs.getString(_prefCountry) ?? detectCountry();
    enabledNotifier.value = v;
    return v;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    enabledNotifier.value = value;
  }

  Future<void> setCountry(String countryCode) async {
    _country = countryCode.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCountry, _country);
    _byDate.clear(); // ще се презаредят за новата държава
  }

  Future<bool> isPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefPromptShown) ?? false;
  }

  Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefPromptShown, true);
  }

  // --- Зареждане / кеш ---

  /// Зарежда празниците за текущата и следващата година в паметта.
  /// Offline-first: ползва Hive кеша; тегли само липсващите години.
  Future<void> loadForCurrentYears() async {
    final year = DateTime.now().year;
    _byDate.clear();
    await _loadYear(year);
    await _loadYear(year + 1);
    revision.value++; // събужда календара да пререндерира маркерите
  }

  /// Фиксирани официални празници на България (винаги на тези дати — БЕЗ
  /// observed-shifting, което Nager прилага грешно когато паднат в неделя).
  static const Map<String, String> _bgFixed = {
    '01-01': 'Нова година',
    '03-03': 'Ден на Освобождението на България',
    '05-01': 'Ден на труда и на международната работническа солидарност',
    '05-06': 'Гергьовден, ден на храбростта и Българската армия',
    '05-24': 'Ден на българската просвета и култура и на славянската писменост',
    '09-06': 'Ден на Съединението',
    '09-22': 'Ден на независимостта на България',
    '12-24': 'Бъдни вечер',
    '12-25': 'Рождество Христово',
    '12-26': 'Рождество Христово (втори ден)',
  };

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Генерира официалните празници на България локално (точно + офлайн).
  /// Фиксираните + подвижните около православния Великден.
  void _loadBgYear(int year) {
    _bgFixed.forEach((mmdd, name) {
      _byDate['$year-$mmdd'] = name;
    });
    final e = orthodoxEaster(year);
    // Календарна аритметика (без Duration) — заради DST.
    _byDate[_dateKey(DateTime(e.year, e.month, e.day - 2))] = 'Разпети петък';
    _byDate[_dateKey(DateTime(e.year, e.month, e.day - 1))] = 'Велика събота';
    _byDate[_dateKey(e)] = 'Великден';
    _byDate[_dateKey(DateTime(e.year, e.month, e.day + 1))] =
        'Велики понеделник';
  }

  Future<void> _loadYear(int year) async {
    // България: генерираме локално на истинските дати (не разчитаме на Nager,
    // който мести фиксираните празници при неделя).
    if (_country == 'BG') {
      _loadBgYear(year);
      return;
    }

    final key = '${_country}_$year';
    final box = await _openBox();

    // 1) Опит от кеша
    final cached = box.get(key);
    if (cached is String && cached.isNotEmpty) {
      _mergeJson(cached);
      // Обновяваме веднъж годишно: ако кешът е от друга година — рефрешваме
      // на заден план, но UI вече има данни (offline-first).
      final stamp = box.get('${key}_stamp');
      final fresh = stamp is String &&
          stamp.isNotEmpty &&
          DateTime.tryParse(stamp) != null &&
          DateTime.now().difference(DateTime.parse(stamp)).inDays < 365;
      if (fresh) return;
    }

    // 2) Тегли от мрежата (ако няма кеш или е стар)
    try {
      final fetched = await _fetch(year);
      if (fetched != null && fetched.isNotEmpty) {
        await box.put(key, json.encode(fetched));
        await box.put('${key}_stamp', DateTime.now().toIso8601String());
        _byDate.addAll(fetched);
      }
    } catch (e) {
      debugPrint('HolidaysService fetch error ($key): $e');
      // Остава кешът (ако имаше) — offline-first.
    }
  }

  /// HTTP GET към Nager.Date. Връща { "YYYY-MM-DD": localName } или null.
  Future<Map<String, String>?> _fetch(int year) async {
    final uri = Uri.parse(
        'https://date.nager.at/api/v3/PublicHolidays/$year/$_country');
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200 || resp.body.isEmpty) return null;

    final decoded = json.decode(resp.body);
    if (decoded is! List) return null;

    final map = <String, String>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final date = item['date'];
      final localName = item['localName'] ?? item['name'];
      if (date is String && localName is String) {
        map[date] = localName;
      }
    }
    return map;
  }

  void _mergeJson(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (k is String && v is String) _byDate[k] = v;
        });
      }
    } catch (_) {/* повреден кеш — игнорираме */}
  }

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  /// Има ли изобщо заредени празници в паметта (widget-ът проверява, за да не
  /// тегли излишно при всеки синхрон).
  bool get hasData => _byDate.isNotEmpty;

  /// Името на официалния празник за дадена дата (или null).
  String? forDate(DateTime date) {
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _byDate[key];
  }
}
