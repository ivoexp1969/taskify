import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

class IosCalendarService {
  static final IosCalendarService _instance = IosCalendarService._internal();
  factory IosCalendarService() => _instance;
  IosCalendarService._internal();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  static const String _prefsKeyPrefix = 'ios_cal_event_';
  static const String _selectedCalendarKey = 'ios_cal_selected_id';

  Future<bool> requestPermission() async {
    var result = await _plugin.hasPermissions();
    if (result.isSuccess && result.data == true) return true;

    result = await _plugin.requestPermissions();
    return result.isSuccess && result.data == true;
  }

  Future<bool> hasPermission() async {
    final result = await _plugin.hasPermissions();
    return result.isSuccess && result.data == true;
  }

  Future<List<Calendar>> getWritableCalendars() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return [];
    return result.data!
        .where((c) => c.isReadOnly == false)
        .toList();
  }

  Future<String?> _getSelectedCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_selectedCalendarKey);
    if (saved != null) return saved;

    // Default: first writable calendar
    final calendars = await getWritableCalendars();
    if (calendars.isEmpty) return null;
    final defaultId = calendars.first.id!;
    await prefs.setString(_selectedCalendarKey, defaultId);
    return defaultId;
  }

  Future<void> setSelectedCalendarId(String calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCalendarKey, calendarId);
  }

  Future<String?> addTask(Task task) async {
    try {
      final calendarId = await _getSelectedCalendarId();
      if (calendarId == null) return null;

      final start = tz.TZDateTime.from(task.dueDate, tz.local);
      final end = start.add(const Duration(hours: 1));

      final event = Event(
        calendarId,
        title: task.title,
        start: start,
        end: end,
        description: task.notes ?? '',
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result != null && result.isSuccess && result.data != null) {
        await _saveEventId(task, result.data!);
        return result.data;
      }
      return null;
    } catch (e) {
      debugPrint('IosCalendarService.addTask error: $e');
      return null;
    }
  }

  Future<bool> deleteTask(Task task) async {
    try {
      final eventId = await _getEventId(task);
      if (eventId == null) return false;

      final calendarId = await _getSelectedCalendarId();
      if (calendarId == null) return false;

      final result = await _plugin.deleteEvent(calendarId, eventId);
      if (result != null && result.isSuccess) {
        await _removeEventId(task);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('IosCalendarService.deleteTask error: $e');
      return false;
    }
  }

  Future<int> exportAllTasks(List<Task> tasks) async {
    int count = 0;
    for (final task in tasks) {
      if (task.isCompleted) continue;
      final existing = await _getEventId(task);
      if (existing != null) continue; // Already exported
      final id = await addTask(task);
      if (id != null) count++;
    }
    return count;
  }

  /// Изтрива от Apple Calendar всички събития, които сме експортирали
  /// (тези, за които пазим event ID). Връща броя изтрити. Задачите остават.
  Future<int> deleteAllExportedTasks(List<Task> tasks) async {
    int count = 0;
    for (final task in tasks) {
      final existing = await _getEventId(task);
      if (existing == null) continue;
      final ok = await deleteTask(task);
      if (ok) count++;
    }
    return count;
  }

  Future<bool> isTaskSynced(Task task) async {
    final eventId = await _getEventId(task);
    return eventId != null;
  }

  String _taskPrefsKey(Task task) {
    return '$_prefsKeyPrefix${task.key ?? task.title.hashCode}';
  }

  Future<void> _saveEventId(Task task, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taskPrefsKey(task), eventId);
  }

  Future<String?> _getEventId(Task task) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_taskPrefsKey(task));
  }

  Future<void> _removeEventId(Task task) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskPrefsKey(task));
  }
}
