import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Firestore не е наличен на всеки build → remote refresh е guard-нат в try/catch
// и НИКОГА не блокира load(). Функцията работи офлайн с вградения asset.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/school_calendar.dart';

/// „Училищен режим" — данни за българската учебна година (ваканции, срокове,
/// НВО/ДЗИ), с обратно броене до следваща ваканция.
///
/// Източник (по приоритет, като [RenewalService]): пресен кеш (24ч) →
/// Firestore колекция `school_calendar` (документ по учебна година) → вграден
/// asset `assets/data/school_calendar_bg.json`. Иво актуализира един документ
/// веднъж годишно по заповед на МОН — без нов билд.
///
/// ★НЕ гадаем★: при липсващ документ за текущата година или `enabled:false`
/// приложението показва празно състояние, не измисля дати.
///
/// Всичко е чист Dart → работи еднакво на Android и iOS (Firestore вече е в
/// iOS Podfile). Никакъв native код / нови permissions.
class SchoolCalendarService {
  SchoolCalendarService._internal();
  static final SchoolCalendarService _instance =
      SchoolCalendarService._internal();
  factory SchoolCalendarService() => _instance;

  static const String _assetPath = 'assets/data/school_calendar_bg.json';
  static const String _firestoreCollection = 'school_calendar';

  static const String _prefEnabled = 'school_mode_enabled';
  static const String _prefGrade = 'school_grade';
  static const String _prefSchool = 'school_name';
  static const String _kCacheJson = 'school_calendar_cache';
  static const String _kCacheTs = 'school_calendar_cache_ts';
  static const String _kCacheKey = 'school_calendar_cache_key';

  /// Кешираният remote се смята за пресен 24 часа.
  static const Duration cacheTtl = Duration(hours: 24);

  /// Държава — засега само България (данните са за БГ учебната година).
  static const String country = 'bg';

  /// Глобален превключвател „Училищен режим вкл/изкл". UI-ят слуша този notifier
  /// за мигновен отговор (екраните живеят в IndexedStack).
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// Бумва се при всяка промяна на данните/класа → картата се пре-оценява без
  /// рестарт (реактивност, като `renewal_offers.revision`).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SchoolYear? _year;
  int? _grade;
  String? _school; // име на училището (опционално, за бъдещи функции)
  bool _loaded = false;

  /// Заредената учебна година (или null → празно състояние).
  SchoolYear? get currentYear => _year;

  /// Избраният клас (1–12) или null, ако още не е избран.
  int? get grade => _grade;

  /// Училище (опционално, свободен текст) или null.
  String? get school => _school;

  bool get enabled => enabledNotifier.value;

  @visibleForTesting
  void setYearForTest(SchoolYear? y) {
    _year = y;
    _loaded = true;
  }

  // ── Настройки: вкл/изкл + клас ─────────────────────────────────────────────

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefEnabled) ?? false;
    final g = prefs.getInt(_prefGrade);
    _grade = (g != null && g >= 1 && g <= 12) ? g : null;
    _school = prefs.getString(_prefSchool);
    enabledNotifier.value = v;
    return v;
  }

  Future<void> setSchool(String? name) async {
    final trimmed = name?.trim();
    _school = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (_school == null) {
      await prefs.remove(_prefSchool);
    } else {
      await prefs.setString(_prefSchool, _school!);
    }
    revision.value++;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    enabledNotifier.value = value;
    revision.value++;
  }

  Future<void> setGrade(int grade) async {
    if (grade < 1 || grade > 12) return;
    _grade = grade;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefGrade, grade);
    revision.value++;
  }

  // ── Ключ на учебната година ───────────────────────────────────────────────

  /// Идентификатор на текущата учебна година спрямо [now]: българската година
  /// започва през септември, затова месеците преди септември принадлежат на
  /// предходната учебна година. Пример: „bg_2026_2027".
  static String yearKeyFor(DateTime now) {
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    return 'bg_${startYear}_${startYear + 1}';
  }

  String get currentYearKey => yearKeyFor(DateTime.now());

  // ── Зареждане ────────────────────────────────────────────────────────────

  /// Зарежда данните еднократно: пресен кеш (за същата година) → вграден asset.
  /// Пуска фоново remote refresh. Безопасно при повторно извикване.
  Future<void> load() async {
    if (_loaded) return;
    final key = currentYearKey;
    final prefs = await SharedPreferences.getInstance();

    // 1) Пресен кеш от предишен remote refresh (само за същата учебна година).
    final cached = prefs.getString(_kCacheJson);
    final ts = prefs.getInt(_kCacheTs);
    final cachedKey = prefs.getString(_kCacheKey);
    if (cached != null &&
        ts != null &&
        cachedKey == key &&
        _isFresh(ts)) {
      final y = _parseYear(cached);
      if (y != null) {
        _year = y;
        _loaded = true;
        unawaited(refreshFromRemote());
        return;
      }
    }

    // 2) Вграден fallback за текущата година (може да липсва → null → празно).
    _year = await _loadBundled(key);
    _loaded = true;

    // 3) Фоново обновяване за тази сесия/следващата (не чакаме).
    unawaited(refreshFromRemote());
  }

  bool _isFresh(int tsMillis) =>
      DateTime.now().millisecondsSinceEpoch - tsMillis < cacheTtl.inMilliseconds;

  /// Зарежда документа за учебна година [key] от вградения asset (или null).
  Future<SchoolYear?> _loadBundled(String key) async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = json.decode(raw);
      if (data is! Map) return null;
      final docs = data['documents'];
      if (docs is! Map) return null;
      final doc = docs[key];
      if (doc is! Map) return null;
      return SchoolYear.fromJson(Map<String, dynamic>.from(doc));
    } catch (e) {
      debugPrint('SchoolCalendarService: bundled load failed → $e');
      return null;
    }
  }

  SchoolYear? _parseYear(String rawJson) {
    try {
      final m = json.decode(rawJson);
      if (m is Map) return SchoolYear.fromJson(Map<String, dynamic>.from(m));
    } catch (_) {}
    return null;
  }

  /// Тегли документа за текущата учебна година от Firestore, нормализира
  /// `Timestamp`→ISO, кешира и обновява. Изцяло guard-нат — при грешка/липса
  /// остава вграденото/кешираното (offline-first).
  Future<void> refreshFromRemote() async {
    final key = currentYearKey;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .doc(key)
          .get();
      if (!snap.exists) return; // няма данни за тази година → не пипаме нищо
      final data = snap.data();
      if (data == null) return;

      final normalized = _normalizeTimestamps(data);
      final y = SchoolYear.fromJson(Map<String, dynamic>.from(normalized));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheJson, json.encode(normalized));
      await prefs.setInt(_kCacheTs, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_kCacheKey, key);

      _year = y;
      revision.value++; // → картата се пре-оценява веднага
    } catch (e) {
      debugPrint('SchoolCalendarService: remote refresh skipped → $e');
    }
  }

  /// Рекурсивно превръща Firestore `Timestamp` в ISO низ, за да е JSON-сериализуем
  /// (кешът е обикновен JSON, а моделът приема ISO низове).
  dynamic _normalizeTimestamps(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _normalizeTimestamps(val)));
    }
    if (v is List) return v.map(_normalizeTimestamps).toList();
    return v;
  }

  // ── Обратно броене ────────────────────────────────────────────────────────

  /// Изчислява обратното броене за избрания клас спрямо „сега" (или null клас →
  /// празно състояние). Чистата логика е в [computeCountdown].
  SchoolCountdown countdown([DateTime? now]) {
    final g = _grade;
    if (g == null) return SchoolCountdown.none;
    return computeCountdown(
      now: now ?? DateTime.now(),
      year: _year,
      grade: g,
    );
  }

  /// Предстоящите изпити (НВО/ДЗИ) за избрания клас (може да е празен списък).
  List<SchoolExam> upcomingExams([DateTime? now]) {
    final g = _grade;
    final y = _year;
    if (g == null || y == null || !y.hasData) return const [];
    return y.upcomingExamsFor(g, now ?? DateTime.now());
  }
}
