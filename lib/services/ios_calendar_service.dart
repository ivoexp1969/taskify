import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

/// Apple Calendar експорт (device_calendar) — ЕДНОПОСОЧЕН (само изпращане).
///
/// Приведен към merge архитектурата на Google sync-а: връзката към събитието
/// се пази в [Task.appleEventId] (а не в SharedPreferences с hashCode), затова
/// редакция ОБНОВЯВА същото събитие, а изтриване го маха.
///
/// СЪЗНАТЕЛНО без импорт от Apple Calendar: импортът би отворил цикъл на
/// дублиране през външни GCal↔Apple връзки (чест случай). Затова и Apple и
/// Google НЕ могат да са активни едновременно — изборът е един radio в
/// Настройки ([syncModeKey]).
class IosCalendarService {
  static final IosCalendarService _instance = IosCalendarService._internal();
  factory IosCalendarService() => _instance;
  IosCalendarService._internal();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  static const String _selectedCalendarKey = 'ios_cal_selected_id';

  /// Единен избор на календарен източник: 'none' | 'google' | 'apple'.
  /// Двата източника са взаимно изключващи се (виж класовия коментар).
  static const String syncModeKey = 'calendar_sync_mode';

  /// Кеширано състояние дали Apple експортът е активен (mode == 'apple').
  /// Inline hook-овете при create/update (task_screen, calendar_screen) четат
  /// това синхронно, без всеки път да отварят SharedPreferences. Зарежда се при
  /// старт ([loadMode]) и се обновява от Настройки ([setMode]).
  static bool exportEnabled = false;

  /// Зарежда [exportEnabled] от SharedPreferences. Викай при старт (main.dart).
  static Future<void> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    exportEnabled = prefs.getString(syncModeKey) == 'apple';
  }

  /// Записва избрания режим и обновява кеша.
  static Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(syncModeKey, mode);
    exportEnabled = mode == 'apple';
  }

  static Future<String> currentMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(syncModeKey) ?? 'none';
  }

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
    return result.data!.where((c) => c.isReadOnly == false).toList();
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

  /// Създава ИЛИ обновява събитие за задачата. Ако [Task.appleEventId] вече е
  /// зададено → обновява СЪЩОТО събитие (без дубъл); иначе създава ново и
  /// записва id-то в задачата. Връща true при успех.
  ///
  /// Извиквай при създаване И при редакция на задача (когато mode == 'apple').
  /// Завършени/архивирани задачи се пропускат (и се махат, ако вече са в
  /// календара).
  Future<bool> syncTask(Task task) async {
    try {
      if (task.deleted) {
        await deleteEventFor(task);
        return true;
      }
      if (task.isCompleted || task.isArchived) {
        // Не държим завършени/архивирани в календара.
        if (task.appleEventId != null) await deleteEventFor(task);
        return true;
      }

      final calendarId = await _getSelectedCalendarId();
      if (calendarId == null) return false;

      final start = tz.TZDateTime.from(task.dueDate, tz.local);
      final end = start.add(const Duration(hours: 1));

      // eventId != null → device_calendar обновява съществуващото събитие.
      final event = Event(
        calendarId,
        eventId: task.appleEventId,
        title: task.title,
        start: start,
        end: end,
        description: task.notes ?? '',
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result != null && result.isSuccess && result.data != null) {
        // Записваме връзката само ако е нова/променена (insert или re-link).
        if (task.appleEventId != result.data) {
          task.appleEventId = result.data;
          task.touch();
          if (task.isInBox) await task.save();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('IosCalendarService.syncTask error: $e');
      return false;
    }
  }

  /// Изтрива събитието на задачата от Apple Calendar (ако има [appleEventId]).
  /// Викай ПРЕДИ задачата да се махне от taskBox (от TombstoneService.deleteTask).
  Future<bool> deleteEventFor(Task task) async {
    try {
      final eventId = task.appleEventId;
      if (eventId == null) return false;

      final calendarId = await _getSelectedCalendarId();
      if (calendarId == null) return false;

      final result = await _plugin.deleteEvent(calendarId, eventId);
      if (result.isSuccess) {
        task.appleEventId = null;
        if (task.isInBox) {
          task.touch();
          await task.save();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('IosCalendarService.deleteEventFor error: $e');
      return false;
    }
  }

  /// Еднократен първоначален експорт при включване на Apple sync: качва всички
  /// отворени задачи, които още нямат [appleEventId]. Връща броя нови събития.
  Future<int> exportOpenTasks(List<Task> tasks) async {
    int count = 0;
    for (final task in tasks) {
      if (task.isCompleted || task.isArchived || task.deleted) continue;
      if (task.appleEventId != null) continue; // вече е свързана
      final ok = await syncTask(task);
      if (ok && task.appleEventId != null) count++;
    }
    return count;
  }
}
