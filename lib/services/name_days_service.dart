import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/orthodox_easter.dart';
import 'notification_service.dart';

/// Един запис за имен ден: празник + имена, които празнуват.
class NameDay {
  final String feast;
  final List<String> names;

  const NameDay({required this.feast, required this.names});
}

/// Зарежда българските именни дни от вградения dataset
/// (assets/data/bg_name_days.json) и ги предоставя по дата.
///
/// Фиксираните празници са по "MM-DD". Подвижните се изчисляват спрямо
/// православния Великден за конкретната година (Великден + offset).
///
/// HTTP не се ползва — данните са локални, нищо не брои към AI лимита.
class NameDaysService {
  NameDaysService._internal();
  static final NameDaysService _instance = NameDaysService._internal();
  factory NameDaysService() => _instance;

  static const String _assetPath = 'assets/data/bg_name_days.json';

  /// Глобален превключвател „Именни дни вкл/изкл". Календарът слуша този
  /// notifier, за да реагира веднага щом toggle-ът в Настройки се смени
  /// (екраните живеят в IndexedStack и не се пресъздават).
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// Зарежда запазената стойност на toggle-а в notifier-а.
  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool('name_days_enabled') ?? false;
    enabledNotifier.value = v;
    return v;
  }

  /// Записва стойността и обновява notifier-а (за мигновен UI отговор).
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('name_days_enabled', value);
    enabledNotifier.value = value;
  }

  // Фиксирани: ключ "MM-DD" → NameDay
  final Map<String, NameDay> _fixed = {};
  // Подвижни: offset от Великден → NameDay
  final List<({int offset, NameDay nameDay})> _movable = [];
  bool _loaded = false;

  /// Зарежда и парсва dataset-а еднократно. Безопасно при повторно извикване.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = json.decode(raw) as Map<String, dynamic>;

      final fixedList = (data['fixed'] as List?) ?? const [];
      for (final item in fixedList) {
        final m = item as Map<String, dynamic>;
        final date = m['date'] as String?;
        if (date == null) continue;
        _fixed[date] = NameDay(
          feast: (m['feast'] as String?) ?? '',
          names: _stringList(m['names']),
        );
      }

      final movableList = (data['movable'] as List?) ?? const [];
      for (final item in movableList) {
        final m = item as Map<String, dynamic>;
        final offset = m['offsetFromOrthodoxEaster'];
        if (offset is! int) continue;
        _movable.add((
          offset: offset,
          nameDay: NameDay(
            feast: (m['feast'] as String?) ?? '',
            names: _stringList(m['names']),
          ),
        ));
      }
      _loaded = true;
    } catch (_) {
      // При повреден/липсващ asset — оставяме празно, UI просто не показва нищо.
      _loaded = true;
    }
  }

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  /// Връща именния ден за дадена дата (или null, ако няма).
  /// Първо проверява фиксираните, после подвижните спрямо Великден.
  NameDay? forDate(DateTime date) {
    if (!_loaded) return null;

    final mmdd =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final fixed = _fixed[mmdd];
    if (fixed != null) return fixed;

    if (_movable.isNotEmpty) {
      final easter = orthodoxEaster(date.year);
      final target = DateTime(date.year, date.month, date.day);
      for (final entry in _movable) {
        // Календарна аритметика (без Duration) — иначе DST дрейфът измества
        // подвижните празници с един ден (напр. Тодоровден 27 вместо 28 февр.).
        final d =
            DateTime(easter.year, easter.month, easter.day + entry.offset);
        if (d.year == target.year &&
            d.month == target.month &&
            d.day == target.day) {
          return entry.nameDay;
        }
      }
    }
    return null;
  }

  /// Има ли изобщо зареден dataset (за условно показване в UI).
  bool get hasData => _fixed.isNotEmpty || _movable.isNotEmpty;

  // --- Сутрешни нотификации за именни дни (опционално, premium) ---

  /// Диапазон за резервираните notification id-та (за да можем да ги отменим).
  static const int _notifIdBase = 9100;
  static const int _notifMaxCount = 20; // макс брой насрочени напред
  static const int _lookAheadDays = 60; // колко дни напред да сканираме
  static const int _notifHour = 8; // час на нотификацията

  /// Отменя всички предишно насрочени нотификации за именни дни.
  Future<void> cancelNotifications() async {
    for (var i = 0; i < _notifMaxCount; i++) {
      await NotificationService().cancelNotification(_notifIdBase + i);
    }
  }

  /// Пренасрочва сутрешните нотификации за следващите дни с имен ден.
  /// Текстът е локализиран; имената идват от dataset-а.
  Future<void> scheduleNotifications({required String lang}) async {
    await cancelNotifications();
    if (!_loaded) await load();
    if (!hasData) return;

    const title = {
      'en': 'Name day 🎉', 'bg': 'Имен ден 🎉', 'de': 'Namenstag 🎉',
      'fr': 'Fête du prénom 🎉', 'it': 'Onomastico 🎉',
      'el': 'Ονομαστική εορτή 🎉', 'es': 'Onomástica 🎉',
      'pt': 'Dia do nome 🎉', 'ru': 'Именины 🎉', 'tr': 'İsim günü 🎉',
    };
    // {names} се заменя с имената; тонът е топъл и личен.
    const bodyTpl = {
      'en': 'Today {names} celebrate — send your wishes? 🎉',
      'bg': 'Днес имен ден празнуват {names} — да честитиш? 🎉',
      'de': 'Heute feiern {names} Namenstag — gratulierst du? 🎉',
      'fr': "Aujourd'hui {names} fêtent leur prénom — un petit mot? 🎉",
      'it': 'Oggi {names} festeggiano l\'onomastico — fai gli auguri? 🎉',
      'el': 'Σήμερα γιορτάζουν {names} — να ευχηθείς; 🎉',
      'es': 'Hoy celebran su santo {names} — ¿felicitas? 🎉',
      'pt': 'Hoje {names} fazem anos do nome — parabeniza? 🎉',
      'ru': 'Сегодня именины у {names} — поздравишь? 🎉',
      'tr': 'Bugün {names} isim gününü kutluyor — tebrik eder misin? 🎉',
    };
    final t = title[lang] ?? title['en']!;
    final tpl = bodyTpl[lang] ?? bodyTpl['en']!;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int scheduled = 0;

    for (var i = 0; i <= _lookAheadDays && scheduled < _notifMaxCount; i++) {
      // Календарна аритметика, за да не дрейфне денят при DST преход.
      final day = DateTime(today.year, today.month, today.day + i);
      final nameDay = forDate(day);
      if (nameDay == null || nameDay.names.isEmpty) continue;

      final fireAt = DateTime(day.year, day.month, day.day, _notifHour);
      if (fireAt.isBefore(now)) continue; // днес, ако часът е минал — пропусни

      final names = nameDay.names.join(', ');
      await NotificationService().scheduleNotification(
        id: _notifIdBase + scheduled,
        title: t,
        body: tpl.replaceAll('{names}', names),
        scheduledDate: fireAt,
      );
      scheduled++;
    }
  }

  /// Удобен помощник: пренасрочва според запазената настройка.
  Future<void> refreshNotificationsFromPrefs(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('name_days_enabled') ?? false;
    if (enabled) {
      await scheduleNotifications(lang: lang);
    } else {
      await cancelNotifications();
    }
  }
}
