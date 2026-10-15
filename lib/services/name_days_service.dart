import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/orthodox_easter.dart';
import '../utils/debug_overrides.dart';
import 'notification_service.dart';
import 'pro_service.dart';
import 'contact_name_index.dart';

/// Един запис за имен ден: празник + имена, които празнуват.
class NameDay {
  final String feast;
  final List<String> names;

  const NameDay({required this.feast, required this.names});
}

/// „и още N" за списъка с контакти (локализирано, 13 ез.).
const _andMore = {
  'en': 'and {n} more', 'nl': 'en nog {n}', 'uk': 'і ще {n}',
  'bg': 'и още {n}',
  'de': 'und {n} weitere',
  'fr': 'et {n} de plus',
  'it': 'e altri {n}',
  'el': 'και {n} ακόμη',
  'es': 'y {n} más',
  'pt': 'e mais {n}',
  'ru': 'и ещё {n}',
  'tr': 've {n} kişi daha', 'ja': 'ほか{n}人',
};

/// До 3 имена на контакти + „и още N" (ако са повече).
String _contactsSummary(List<ContactMatch> contacts, String lang) {
  final names = contacts.map((c) => c.name).toList();
  if (names.length <= 3) return names.join(', ');
  final shown = names.take(3).join(', ');
  final more = names.length - 3;
  final tail = (_andMore[lang] ?? _andMore['en']!).replaceAll('{n}', '$more');
  return '$shown $tail';
}

// ── Текстове за имен-ден нотификациите (ползвани и от debug „изпрати сега") ──
const _ndTitle = {
  'en': 'Name day 🎉', 'nl': 'Naamdag 🎉', 'uk': 'Іменини 🎉', 'bg': 'Имен ден 🎉', 'de': 'Namenstag 🎉',
  'fr': 'Fête du prénom 🎉', 'it': 'Onomastico 🎉',
  'el': 'Ονομαστική εορτή 🎉', 'es': 'Onomástica 🎉',
  'pt': 'Dia do nome 🎉', 'ru': 'Именины 🎉', 'tr': 'İsim günü 🎉', 'ja': '聖名祝日 🎉',
};
const _ndBodyTpl = {
  'en': 'Today {names} celebrate — send your wishes? 🎉', 'nl': 'Vandaag vieren {names} — je wensen sturen? 🎉', 'uk': 'Сьогодні {names} святкують — надіслати побажання? 🎉',
  'bg': 'Днес имен ден празнуват {names} — да честитиш? 🎉',
  'de': 'Heute feiern {names} Namenstag — gratulierst du? 🎉',
  'fr': "Aujourd'hui {names} fêtent leur prénom — un petit mot? 🎉",
  'it': 'Oggi {names} festeggiano l\'onomastico — fai gli auguri? 🎉',
  'el': 'Σήμερα γιορτάζουν {names} — να ευχηθείς; 🎉',
  'es': 'Hoy celebran su santo {names} — ¿felicitas? 🎉',
  'pt': 'Hoje {names} fazem anos do nome — parabeniza? 🎉',
  'ru': 'Сегодня именины у {names} — поздравишь? 🎉',
  'tr': 'Bugün {names} isim gününü kutluyor — tebrik eder misin? 🎉', 'ja': '今日は{names}が聖名祝日です — お祝いを送りますか？🎉',
};
const _ndFreeLocked = {
  'en': '{names} celebrate today — {n} of your contacts too 🔒', 'nl': '{names} vieren vandaag — {n} van je contacten ook 🔒', 'uk': 'Сьогодні святкують {names} — {n} ваших контактів теж 🔒',
  'bg': 'Днес празнуват {names} — {n} от контактите ти също 🔒',
  'de': 'Heute feiern {names} — {n} deiner Kontakte auch 🔒',
  'fr': "Aujourd'hui {names} fêtent — {n} de tes contacts aussi 🔒",
  'it': 'Oggi festeggiano {names} — anche {n} dei tuoi contatti 🔒',
  'el': 'Σήμερα γιορτάζουν {names} — {n} επαφές σου επίσης 🔒',
  'es': 'Hoy celebran {names} — {n} de tus contactos también 🔒',
  'pt': 'Hoje {names} celebram — {n} dos teus contactos também 🔒',
  'ru': 'Сегодня празднуют {names} — {n} ваших контактов тоже 🔒',
  'tr': 'Bugün {names} kutluyor — kişilerinden {n} kişi de 🔒', 'ja': '今日は{names}がお祝い — 連絡先{n}人も 🔒',
};
const _ndProContacts = {
  'en': 'Name day for {contacts} — send your wishes? 🎉', 'nl': 'Naamdag voor {contacts} — je wensen sturen? 🎉', 'uk': 'Іменини у {contacts} — надіслати побажання? 🎉',
  'bg': 'Имен ден имат {contacts} — да честитиш? 🎉',
  'de': 'Namenstag für {contacts} — gratulierst du? 🎉',
  'fr': 'Fête du prénom pour {contacts} — un petit mot ? 🎉',
  'it': 'Onomastico per {contacts} — fai gli auguri? 🎉',
  'el': 'Ονομαστική εορτή για {contacts} — να ευχηθείς; 🎉',
  'es': 'Santo de {contacts} — ¿felicitas? 🎉',
  'pt': 'Dia do nome de {contacts} — parabeniza? 🎉',
  'ru': 'Именины у {contacts} — поздравишь? 🎉',
  'tr': '{contacts} isim gününü kutluyor — tebrik eder misin? 🎉', 'ja': '{contacts}が聖名祝日です — お祝いを送りますか？🎉',
};

String _ndTitleFor(String lang) => _ndTitle[lang] ?? _ndTitle['en']!;

/// Единна логика за тялото на нотификацията (Pro/контакти/free).
String _ndBodyFor({
  required NameDay nameDay,
  required String lang,
  required bool isPro,
  required List<ContactMatch> contacts,
}) {
  final names = nameDay.names.join(', ');
  if (isPro && contacts.isNotEmpty) {
    return (_ndProContacts[lang] ?? _ndProContacts['en']!)
        .replaceAll('{contacts}', _contactsSummary(contacts, lang));
  } else if (!isPro && contacts.isNotEmpty) {
    return (_ndFreeLocked[lang] ?? _ndFreeLocked['en']!)
        .replaceAll('{names}', names)
        .replaceAll('{n}', '${contacts.length}');
  }
  return (_ndBodyTpl[lang] ?? _ndBodyTpl['en']!).replaceAll('{names}', names);
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
        // Новият Wikipedia dataset ползва поле "offset"; стария — "offsetFromOrthodoxEaster".
        // Приемаме и двете, за да е консистентно при бъдеща смяна на източника.
        final offset = m['offset'] ?? m['offsetFromOrthodoxEaster'];
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

    final t = _ndTitleFor(lang);

    // Pro статус + индекс на контактите определят текста.
    final isPro = ProService().isPro;
    final contactsEnabled = ContactNameIndex().isEnabled;
    if (contactsEnabled) await ContactNameIndex().ensureLoaded();

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

      final List<ContactMatch> contacts = contactsEnabled
          ? ContactNameIndex().contactsForNames(nameDay.names)
          : const <ContactMatch>[];
      final body = _ndBodyFor(
          nameDay: nameDay, lang: lang, isPro: isPro, contacts: contacts);

      await NotificationService().scheduleNotification(
        id: _notifIdBase + scheduled,
        title: t,
        body: body,
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

  /// ★DEBUG★ Показва веднага (след ~2 сек) имен-ден нотификацията за „днес"
  /// (с евентуален debug override на датата, напр. 8 ноември), със същия
  /// Pro-aware текст като сутрешната. За ръчен тест без да се чака 08:00.
  Future<void> debugSendNow({required String lang}) async {
    if (!_loaded) await load();
    final today = DebugOverrides.now();
    final nameDay = forDate(today);
    final isPro = ProService().isPro;
    final contactsEnabled = ContactNameIndex().isEnabled;
    if (contactsEnabled) await ContactNameIndex().ensureLoaded();

    final String body;
    if (nameDay == null || nameDay.names.isEmpty) {
      body = 'DEBUG: днес (${today.day}.${today.month}) няма имен ден';
    } else {
      final contacts = contactsEnabled
          ? ContactNameIndex().contactsForNames(nameDay.names)
          : const <ContactMatch>[];
      body = _ndBodyFor(
          nameDay: nameDay, lang: lang, isPro: isPro, contacts: contacts);
    }
    await NotificationService().scheduleNotification(
      id: _notifIdBase + _notifMaxCount + 1, // извън диапазона на планираните
      title: _ndTitleFor(lang),
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 2)),
    );
  }
}
