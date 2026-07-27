import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weekly_schedule.dart';
import '../utils/uuid.dart';

/// Съхранява седмичния разпис (Режими Уча) в SharedPreferences като JSON списък.
/// Чист Dart, реактивен чрез [revision] (календарът/екранът се обновяват без
/// рестарт).
class WeeklyScheduleService {
  WeeklyScheduleService._internal();
  static final WeeklyScheduleService _instance =
      WeeklyScheduleService._internal();
  factory WeeklyScheduleService() => _instance;

  static const String _pref = 'weekly_schedule';
  static const String _prefTerm = 'weekly_schedule_term';

  /// Бумва се при всяка промяна на разписа (вкл. смяна на текущия срок).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<ScheduleSlot> _slots = const [];
  bool _loaded = false;

  /// Текущо избран срок/семестър (1 или 2). Разписанието се въвежда и показва
  /// отделно за всеки срок; календарът показва слотовете на текущия срок.
  int _currentTerm = 1;
  int get currentTerm => _currentTerm;

  Future<void> setCurrentTerm(int term) async {
    final t = term == 2 ? 2 : 1;
    if (t == _currentTerm) return;
    _currentTerm = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTerm, t);
    revision.value++;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _parse(prefs.getString(_pref));
    _currentTerm = (prefs.getInt(_prefTerm) == 2) ? 2 : 1;
    _loaded = true;
    // Опресни евентуалните слушатели (напр. лентата на календара), заредени
    // преди края на асинхронния load.
    if (_slots.isNotEmpty) revision.value++;
  }

  void _parse(String? raw) {
    if (raw == null) {
      _slots = const [];
      return;
    }
    try {
      final l = json.decode(raw);
      if (l is List) {
        _slots = l
            .whereType<Map>()
            .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e)))
            .whereType<ScheduleSlot>()
            .toList();
        return;
      }
    } catch (e) {
      debugPrint('WeeklyScheduleService: parse failed → $e');
    }
    _slots = const [];
  }

  /// Всички слотове (несортирани).
  List<ScheduleSlot> get all => List.unmodifiable(_slots);

  /// Слотовете за конкретен ден (1=пон … 7=нед), сортирани по начален час.
  /// По подразбиране връща само текущия срок; подай [term] за конкретен срок.
  List<ScheduleSlot> forDay(int day, {int? term}) {
    final t = term ?? _currentTerm;
    final list = _slots.where((s) => s.day == day && s.term == t).toList();
    list.sort((a, b) => a.fromMinutes.compareTo(b.fromMinutes));
    return list;
  }

  /// Празно ли е разписанието за срок (по подразбиране — текущия).
  bool isEmptyForTerm([int? term]) {
    final t = term ?? _currentTerm;
    return !_slots.any((s) => s.term == t);
  }

  bool get isEmpty => _slots.isEmpty;

  /// Връща първия съществуващ слот, който се припокрива по време с [candidate]
  /// в същия ден (пропуска самия него по id), или `null` ако няма конфликт.
  /// Използва се за да НЕ допускаме два часа/събития в едно и също време.
  ScheduleSlot? firstConflict(ScheduleSlot candidate) {
    for (final s in _slots) {
      if (s.id == candidate.id) continue;
      if (candidate.overlaps(s)) return s;
    }
    return null;
  }

  Future<void> upsert(ScheduleSlot slot) async {
    final idx = _slots.indexWhere((s) => s.id == slot.id);
    final next = List<ScheduleSlot>.from(_slots);
    if (idx >= 0) {
      next[idx] = slot;
    } else {
      next.add(slot);
    }
    _slots = next;
    await _persist();
  }

  /// Създава нов слот (генерира id).
  ScheduleSlot newSlot({
    required int day,
    required int fromMinutes,
    required int toMinutes,
    required String subject,
    required SlotKind kind,
    String? location,
    int? term,
  }) {
    return ScheduleSlot(
      id: Uuid.v4(),
      day: day,
      fromMinutes: fromMinutes,
      toMinutes: toMinutes,
      subject: subject,
      kind: kind,
      location: location,
      term: term ?? _currentTerm,
    );
  }

  Future<void> remove(String id) async {
    _slots = _slots.where((s) => s.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _pref, json.encode(_slots.map((s) => s.toJson()).toList()));
    revision.value++;
  }
}
