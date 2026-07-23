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

  /// Бумва се при всяка промяна на разписа.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<ScheduleSlot> _slots = const [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _parse(prefs.getString(_pref));
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
  List<ScheduleSlot> forDay(int day) {
    final list = _slots.where((s) => s.day == day).toList();
    list.sort((a, b) => a.fromMinutes.compareTo(b.fromMinutes));
    return list;
  }

  bool get isEmpty => _slots.isEmpty;

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
  }) {
    return ScheduleSlot(
      id: Uuid.v4(),
      day: day,
      fromMinutes: fromMinutes,
      toMinutes: toMinutes,
      subject: subject,
      kind: kind,
      location: location,
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
