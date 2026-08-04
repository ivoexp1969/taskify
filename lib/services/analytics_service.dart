import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';

/// Минимален, целенасочен Firebase Analytics слой.
///
/// Отговаря на 2 бизнес въпроса:
///   1. Retention (D1/D7/D30) — `app_first_open`, `day_2_active`.
///   2. Onboarding funnel до първа задача/режим — `onboarding_started`,
///      `onboarding_completed`, `first_task_created`, `first_mode_activated`.
///
/// Принципи (потвърдени с Иво):
///   • НУЛА лични данни. Логваме само тип на задача (`task_type`), НЕ съдържание.
///   • Без IDFA / Google signals / cross-device (default off — не ги пипаме).
///   • Singleton, викан глобално `AnalyticsService().logX()` (като ProService).
///
/// Малка Hive кутия `analytics_flags` пази еднократните маркери
/// (`is_first_open_logged`, `first_open_date`, `first_task_logged`,
/// `first_mode_logged`), за да не се дублират „first" събитията между сесии.
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  static const String _boxName = 'analytics_flags';

  FirebaseAnalytics? _fa;

  /// Единственият observer, който закачаме на MaterialApp.navigatorObservers.
  /// null на web / при неинициализиран Analytics → извикващият пропуска.
  FirebaseAnalyticsObserver? _observer;
  FirebaseAnalyticsObserver? get observer => _observer;

  Box? _box;

  bool _ready = false;

  /// Инициализация — вика се веднъж от `main()` СЛЕД `Firebase.initializeApp()`.
  /// Не блокира старта при грешка (analytics е незадължителна телеметрия).
  Future<void> initialize() async {
    if (_ready) return;
    // Web го оставяме изключен — метриките ни интересуват за мобилните инсталации,
    // а web винаги е Pro/различен профил (виж kIsWeb навсякъде в проекта).
    if (kIsWeb) {
      _ready = true;
      return;
    }
    try {
      _fa = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _fa!);
      _box = await Hive.openBox(_boxName);
      await _fa!.setAnalyticsCollectionEnabled(true);
      _ready = true;
      await _logFirstOpenAndRetention();
    } catch (e) {
      // Тиха телеметрия — грешка тук не бива да чупи приложението.
      debugPrint('AnalyticsService init failed: $e');
      _ready = true;
    }
  }

  bool get _enabled => _ready && !kIsWeb && _fa != null;

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_enabled) return;
    try {
      await _fa!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics logEvent($name) failed: $e');
    }
  }

  // ── Retention ──────────────────────────────────────────────────────────

  /// `app_first_open` (веднъж на инсталация) + `day_2_active` (връщане на
  /// различен календарен ден от първото отваряне).
  Future<void> _logFirstOpenAndRetention() async {
    final box = _box;
    if (box == null) return;
    final today = _dayKey(DateTime.now());

    final firstLogged = box.get('is_first_open_logged') as bool? ?? false;
    if (!firstLogged) {
      await box.put('is_first_open_logged', true);
      await box.put('first_open_date', today);
      await _log('app_first_open');
    } else {
      final firstDay = box.get('first_open_date') as int?;
      final day2Logged = box.get('day_2_logged') as bool? ?? false;
      if (firstDay != null && !day2Logged && today > firstDay) {
        await box.put('day_2_logged', true);
        await _log('day_2_active');
      }
    }
  }

  /// Ден като цяло число YYYYMMDD (сравнимо, локална дата, без час/часова зона).
  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  // ── Onboarding funnel ──────────────────────────────────────────────────

  Future<void> logOnboardingStarted() => _log('onboarding_started');

  Future<void> logOnboardingCompleted(int stepsCompleted) =>
      _log('onboarding_completed', {'steps_completed': stepsCompleted});

  // ── Задачи ─────────────────────────────────────────────────────────────

  /// Хелпер, викан на всеки `taskBox.add(task)` (~11 места). Логва `task_created`
  /// + еднократно `first_task_created`. Изпраща само ТИПА, не съдържанието.
  Future<void> logTaskCreated(Task task) async {
    if (!_enabled) return;
    final type = _taskType(task);
    await _log('task_created', {'task_type': type});
    final box = _box;
    if (box != null && (box.get('first_task_logged') as bool? ?? false) == false) {
      await box.put('first_task_logged', true);
      await _log('first_task_created', {'task_type': type});
    }
  }

  Future<void> logTaskCompleted() => _log('task_completed');

  String _taskType(Task task) {
    final t = task.template;
    if (t != null && t.isNotEmpty) return t;
    return 'standard';
  }

  // ── Режими (Уча) ───────────────────────────────────────────────────────

  /// Викано ВЪТРЕ в `SchoolCalendarService.setEnabled` / `UniversityService.setEnabled`.
  /// `mode` ∈ {pupil, student}. Логва еднократно `first_mode_activated`,
  /// после `mode_changed`, и обновява user prop `active_mode`.
  Future<void> logModeActivated(String mode) async {
    if (!_enabled) return;
    final box = _box;
    if (box != null && (box.get('first_mode_logged') as bool? ?? false) == false) {
      await box.put('first_mode_logged', true);
      await _log('first_mode_activated', {'mode': mode});
    } else {
      await _log('mode_changed', {'mode': mode});
    }
    await setActiveMode(mode);
  }

  Future<void> logModeDeactivated(String mode) => _log('mode_changed', {'mode': 'none'});

  // ── User properties ────────────────────────────────────────────────────

  /// `active_mode` ∈ {pupil, student, none}.
  Future<void> setActiveMode(String mode) async {
    if (!_enabled) return;
    try {
      await _fa!.setUserProperty(name: 'active_mode', value: mode);
    } catch (e) {
      debugPrint('Analytics setActiveMode failed: $e');
    }
  }

  /// `app_locale` — езиков код (bg/en/…), викан от LanguageController.
  Future<void> setAppLocale(String localeCode) async {
    if (!_enabled) return;
    try {
      await _fa!.setUserProperty(name: 'app_locale', value: localeCode);
    } catch (e) {
      debugPrint('Analytics setAppLocale failed: $e');
    }
  }
}
