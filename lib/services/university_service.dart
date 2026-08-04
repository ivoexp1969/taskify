import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/university.dart';
import '../utils/uuid.dart';
import 'analytics_service.dart';

/// „Режим Студент" — списък с български ВУЗ (вграден asset) + профил на студента
/// + ръчно въведени ключови дати за обратното броене (Ф2).
///
/// Всичко е чист Dart (SharedPreferences + asset) → еднакво на Android и iOS,
/// без native код / нови permissions. Реактивност чрез [enabledNotifier] +
/// [revision], огледално на [SchoolCalendarService].
///
/// ★НЕ гадаем★: ВУЗ идват само от asset-а; факултетите се въвеждат свободно
/// (регистърът не ги дава на това ниво). При липса на въведени дати →
/// празно състояние, не измисляме.
class UniversityService {
  UniversityService._internal();
  static final UniversityService _instance = UniversityService._internal();
  factory UniversityService() => _instance;

  static const String _assetPath = 'assets/data/universities_bg.json';

  static const String _prefEnabled = 'student_mode_enabled';
  static const String _prefProfile = 'university_profile';
  static const String _prefDates = 'student_key_dates';

  /// Глобален превключвател „Режим Студент вкл/изкл".
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// Бумва се при всяка промяна на профил/дати → UI се пре-оценява без рестарт.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<University> _universities = const [];
  bool _loadedUnis = false;

  UniversityProfile? _profile;
  List<StudentKeyDate> _dates = const [];
  bool _loadedState = false;

  bool get enabled => enabledNotifier.value;
  UniversityProfile? get profile => _profile;
  List<University> get universities => _universities;

  @visibleForTesting
  void setUniversitiesForTest(List<University> list) {
    _universities = list;
    _loadedUnis = true;
  }

  // ── ВУЗ списък ──────────────────────────────────────────────────────────

  /// Зарежда списъка с ВУЗ от вградения asset (еднократно). Безопасно повторно.
  Future<List<University>> loadUniversities() async {
    if (_loadedUnis) return _universities;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = json.decode(raw);
      final list = <University>[];
      if (data is Map && data['universities'] is List) {
        for (final item in data['universities']) {
          if (item is Map) {
            final u = University.fromJson(Map<String, dynamic>.from(item));
            if (u != null) list.add(u);
          }
        }
      }
      _universities = list;
    } catch (e) {
      debugPrint('UniversityService: universities load failed → $e');
      _universities = const [];
    }
    _loadedUnis = true;
    return _universities;
  }

  University? universityById(String? id) {
    if (id == null) return null;
    for (final u in _universities) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Човекочетимо име за профила (ръчно въведено за „Друг", иначе от регистъра).
  String? get displayUniversityName {
    final p = _profile;
    if (p == null) return null;
    final u = universityById(p.uniId);
    if (u == null || u.isOther) {
      return (p.uniName != null && p.uniName!.isNotEmpty) ? p.uniName : u?.name;
    }
    return u.name;
  }

  // ── Състояние: вкл/изкл + профил + дати ─────────────────────────────────

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    enabledNotifier.value = prefs.getBool(_prefEnabled) ?? false;
    _loadState(prefs);
    return enabledNotifier.value;
  }

  void _loadState(SharedPreferences prefs) {
    if (_loadedState) return;
    final rawProfile = prefs.getString(_prefProfile);
    if (rawProfile != null) {
      try {
        final m = json.decode(rawProfile);
        if (m is Map) {
          _profile = UniversityProfile.fromJson(Map<String, dynamic>.from(m));
        }
      } catch (_) {}
    }
    final rawDates = prefs.getString(_prefDates);
    if (rawDates != null) {
      try {
        final l = json.decode(rawDates);
        if (l is List) {
          _dates = l
              .whereType<Map>()
              .map((e) =>
                  StudentKeyDate.fromJson(Map<String, dynamic>.from(e)))
              .whereType<StudentKeyDate>()
              .toList();
        }
      } catch (_) {}
    }
    _loadedState = true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final was = prefs.getBool(_prefEnabled) ?? false;
    await prefs.setBool(_prefEnabled, value);
    enabledNotifier.value = value;
    revision.value++;
    if (value && !was) {
      AnalyticsService().logModeActivated('student');
    } else if (!value && was) {
      AnalyticsService().logModeDeactivated('student');
    }
  }

  Future<void> setProfile(UniversityProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefProfile, json.encode(profile.toJson()));
    revision.value++;
  }

  // ── Ключови дати ────────────────────────────────────────────────────────

  List<StudentKeyDate> get keyDates {
    final list = List<StudentKeyDate>.from(_dates);
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Предстоящите ключови дати (дата >= today), сортирани.
  List<StudentKeyDate> upcomingKeyDates([DateTime? now]) {
    final today = now ?? DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    return keyDates.where((d) => !d.date.isBefore(t)).toList();
  }

  Future<StudentKeyDate> addKeyDate({
    required String title,
    required DateTime date,
    required StudentDateKind kind,
  }) async {
    final entry = StudentKeyDate(
      id: Uuid.v4(),
      title: title.trim(),
      date: DateTime(date.year, date.month, date.day),
      kind: kind,
    );
    _dates = [..._dates, entry];
    await _persistDates();
    return entry;
  }

  Future<void> removeKeyDate(String id) async {
    _dates = _dates.where((d) => d.id != id).toList();
    await _persistDates();
  }

  Future<void> _persistDates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefDates, json.encode(_dates.map((d) => d.toJson()).toList()));
    revision.value++;
  }
}
