import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/university.dart';
import '../models/weekly_schedule.dart';
import 'auth_service.dart';
import 'school_calendar_service.dart';
import 'university_service.dart';
import 'weekly_schedule_service.dart';

/// Резултат от един prefs-синхрон.
class PrefsSyncResult {
  final bool success;
  final String? error;
  final int pushed;
  final int pulled;
  const PrefsSyncResult({
    required this.success,
    this.error,
    this.pushed = 0,
    this.pulled = 0,
  });
}

/// Един синхронизируем „pref" документ (whole-doc last-write-wins по updatedAt).
class _PrefDocSpec {
  final String docId;

  /// Има ли изобщо локално съдържание (за да НЕ качваме празни документи при
  /// bootstrap; при триене все пак качваме празното състояние — виж merge).
  final bool Function() hasContent;

  /// Изгражда payload-а (БЕЗ `updatedAtMillis`/`serverUpdatedAt` — те се добавят
  /// от [_push]).
  final Map<String, dynamic> Function() build;

  /// Прилага облачния документ върху локалните услуги (изпълнява се под
  /// `_suppress = true`, за да не се задейства нов stamp/merge цикъл).
  final Future<void> Function(Map<String, dynamic> remote) apply;

  const _PrefDocSpec({
    required this.docId,
    required this.hasContent,
    required this.build,
    required this.apply,
  });
}

/// Cross-device синхрон за данни, които живеят в SharedPreferences (не в Hive):
/// седмичното разписание, студентския профил/дати и ученическия профил.
///
/// Следва СЪЩИЯ принцип като [SyncService] за задачите, но понеже тези данни са
/// малки и се редактират от един човек, всеки domain е ЕДИН Firestore документ
/// с единичен `updatedAtMillis` → whole-doc last-write-wins (без per-item
/// tombstones — триенето е отсъствие в по-новия документ). Документи:
///
///   users/{uid}/prefs/weekly_schedule  ← [WeeklyScheduleService]
///   users/{uid}/prefs/student_context  ← [UniversityService]
///   users/{uid}/prefs/pupil_profile    ← [SchoolCalendarService]
///
/// Гейт = логнат НЕ-анонимен акаунт (както задачите/документите; НЕ явна Pro
/// проверка). Покрито е от съществуващото Firestore правило
/// `users/{uid}/{subcollection=**}` → без промяна в firestore.rules.
class PrefsSyncService {
  PrefsSyncService._internal();
  static final PrefsSyncService _instance = PrefsSyncService._internal();
  factory PrefsSyncService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  /// Известява UI-я кога тече синхрон (за дискретния индикатор на разписанието).
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  /// Активира се веднъж от [start] (в `main.dart`). Докато е false — [markDirty]
  /// е no-op (важно за unit тестовете на услугите, където Firebase липсва).
  static bool _active = false;

  /// Докато прилагаме облачни промени локално — заглушаваме [markDirty], за да
  /// няма цикъл (remote запис → „локална промяна" → нов push).
  bool _suppress = false;

  bool _inProgress = false;
  Timer? _debounce;
  int _lastSyncMs = 0;
  static const int _minAutoSyncGapMs = 10000;

  /// Префикс на локалните „updated-at" маркери в SharedPreferences.
  static const String _stampPrefix = 'prefs_sync_ua_';

  // Анонимните сесии НЕ синхронизират лични данни → третираме ги като „не-логнат".
  String? get _userId {
    try {
      final u = _auth.currentUser;
      if (u == null || u.isAnonymous) return null;
      return u.uid;
    } catch (_) {
      return null; // Firebase недостъпен (напр. в тестове)
    }
  }

  CollectionReference<Map<String, dynamic>>? get _prefsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('prefs');
  }

  // ======================= ТРИГЕРИ =======================

  /// Извиква се веднъж при старт (`main.dart`). Пуска начален pull-merge.
  void start() {
    if (_active) return;
    _active = true;
    syncNow();
  }

  /// Локална промяна в даден domain → отбележи с пресен updatedAt + debounce
  /// синхрон. No-op докато услугата не е активирана или докато прилагаме remote.
  static void markDirty(String domain) {
    final i = _instance;
    if (!_active || i._suppress) return;
    unawaited(i._setStamp(domain, DateTime.now().millisecondsSinceEpoch));
    i._scheduleDebounced();
  }

  void _scheduleDebounced() {
    if (_userId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () {
      final since = DateTime.now().millisecondsSinceEpoch - _lastSyncMs;
      if (since < _minAutoSyncGapMs) {
        _debounce = Timer(
          Duration(milliseconds: _minAutoSyncGapMs - since + 500),
          () => mergeNow(),
        );
        return;
      }
      mergeNow();
    });
  }

  /// АВТО-тригер (старт, authStateChanges, resume) — минава през циркуит
  /// брейкъра. Ръчният бутон в Настройки вика [mergeNow] директно.
  Future<void> syncNow() async {
    final since = DateTime.now().millisecondsSinceEpoch - _lastSyncMs;
    if (since < _minAutoSyncGapMs && _lastSyncMs != 0) return;
    await mergeNow();
  }

  // ======================= MERGE =======================

  Future<PrefsSyncResult> mergeNow() async {
    final ref = _prefsRef;
    if (ref == null) {
      return const PrefsSyncResult(success: false, error: 'not-signed-in');
    }
    if (_inProgress) {
      return const PrefsSyncResult(success: false, error: 'in-progress');
    }
    _inProgress = true;
    syncing.value = true;
    int pushed = 0, pulled = 0;
    try {
      await _ensureLoaded();
      for (final spec in _specs()) {
        final localStamp = await _readStamp(spec.docId);
        final snap = await ref.doc(spec.docId).get();
        final remote = snap.data();
        final remoteUpdated =
            remote == null ? -1 : (_readMillis(remote['updatedAtMillis']) ?? 0);

        if (remoteUpdated > localStamp) {
          // Облакът е по-нов → издърпай локално.
          _suppress = true;
          try {
            await spec.apply(remote!);
          } finally {
            _suppress = false;
          }
          await _setStamp(spec.docId, remoteUpdated);
          pulled++;
        } else if (localStamp > remoteUpdated) {
          // Локалното е по-ново. Качваме, ако има съдържание (bootstrap) ИЛИ ако
          // облакът вече има документ (за да разпространим триене/изчистване).
          if (spec.hasContent() || remoteUpdated >= 0) {
            await _push(ref, spec, localStamp);
            pushed++;
          }
        }
        // равни → нищо (вече синхронизирано)
      }
      return PrefsSyncResult(success: true, pushed: pushed, pulled: pulled);
    } catch (e) {
      debugPrint('PrefsSync merge error: $e');
      return PrefsSyncResult(success: false, error: e.toString());
    } finally {
      _inProgress = false;
      _lastSyncMs = DateTime.now().millisecondsSinceEpoch;
      syncing.value = false;
    }
  }

  Future<void> _push(
    CollectionReference<Map<String, dynamic>> ref,
    _PrefDocSpec spec,
    int stamp,
  ) async {
    final payload = spec.build();
    payload['updatedAtMillis'] = stamp;
    payload['serverUpdatedAt'] = FieldValue.serverTimestamp();
    await ref.doc(spec.docId).set(payload);
  }

  Future<void> _ensureLoaded() async {
    try {
      await WeeklyScheduleService().load();
    } catch (_) {}
    try {
      await UniversityService().loadEnabled();
    } catch (_) {}
    try {
      await SchoolCalendarService().loadEnabled();
    } catch (_) {}
  }

  // ======================= DOMAIN SPECS =======================

  List<_PrefDocSpec> _specs() {
    final sched = WeeklyScheduleService();
    final uni = UniversityService();
    final school = SchoolCalendarService();

    return [
      // ── Седмично разписание ──────────────────────────────────────────────
      _PrefDocSpec(
        docId: 'weekly_schedule',
        hasContent: () => sched.all.isNotEmpty,
        build: () => {
          'slots': sched.all.map((s) => s.toJson()).toList(),
          'term': sched.currentTerm,
        },
        apply: (remote) async {
          final rawSlots = remote['slots'];
          final slots = <ScheduleSlot>[];
          if (rawSlots is List) {
            for (final e in rawSlots) {
              if (e is Map) {
                final s = ScheduleSlot.fromJson(Map<String, dynamic>.from(e));
                if (s != null) slots.add(s);
              }
            }
          }
          final term = _readInt(remote['term']) ?? 1;
          await sched.applyFromSync(slots, term);
        },
      ),

      // ── Студентски контекст (профил + дати + вкл/изкл) ──────────────────
      _PrefDocSpec(
        docId: 'student_context',
        hasContent: () =>
            uni.enabled || uni.profile != null || uni.keyDates.isNotEmpty,
        build: () => {
          'enabled': uni.enabled,
          'profile': uni.profile?.toJson(),
          'dates': uni.keyDates.map((d) => d.toJson()).toList(),
        },
        apply: (remote) async {
          UniversityProfile? profile;
          final rawProfile = remote['profile'];
          if (rawProfile is Map) {
            profile =
                UniversityProfile.fromJson(Map<String, dynamic>.from(rawProfile));
          }
          final dates = <StudentKeyDate>[];
          final rawDates = remote['dates'];
          if (rawDates is List) {
            for (final e in rawDates) {
              if (e is Map) {
                final d = StudentKeyDate.fromJson(Map<String, dynamic>.from(e));
                if (d != null) dates.add(d);
              }
            }
          }
          await uni.applyFromSync(
            enabled: remote['enabled'] == true,
            profile: profile,
            dates: dates,
          );
        },
      ),

      // ── Ученически профил (клас + училище + вкл/изкл) ───────────────────
      _PrefDocSpec(
        docId: 'pupil_profile',
        hasContent: () =>
            school.enabled || school.grade != null || school.school != null,
        build: () => {
          'enabled': school.enabled,
          'grade': school.grade,
          'school': school.school,
        },
        apply: (remote) async {
          await school.applyFromSync(
            enabled: remote['enabled'] == true,
            grade: _readInt(remote['grade']),
            school: remote['school'] as String?,
          );
        },
      ),
    ];
  }

  // ======================= HELPERS =======================

  Future<int> _readStamp(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_stampPrefix$docId') ?? 0;
  }

  Future<void> _setStamp(String docId, int millis) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_stampPrefix$docId', millis);
  }

  int? _readMillis(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  int? _readInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  void dispose() {
    _debounce?.cancel();
  }
}
