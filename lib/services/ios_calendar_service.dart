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
        await deleteEventFor(task);
        return true;
      }

      final calendarId = await _getSelectedCalendarId();
      if (calendarId == null) return false;

      final start = tz.TZDateTime.from(task.dueDate, tz.local);
      final end = start.add(const Duration(hours: 1));
      final originalId = task.appleEventId;

      // ДЕДУП: намери всички съвпадащи събития (заглавие+начало) за деня; пази
      // едно (предпочитано вече свързаното), изтрий останалите. Поправя дубли
      // от стар bulk-експорт / повторно включване и осиновява нетракнати
      // събития вместо да създава ново → 1:1 връзка задача↔събитие.
      final reconciledId = await _reconcileExisting(calendarId, task, start);
      if (reconciledId != null) task.appleEventId = reconciledId;

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
        task.appleEventId = result.data;
        if (task.appleEventId != originalId && task.isInBox) {
          task.touch();
          await task.save();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('IosCalendarService.syncTask error: $e');
      return false;
    }
  }

  /// Намира съществуващи събития за деня на задачата, съвпадащи по
  /// заглавие + начален час. Запазва ЕДНО (предпочитано вече свързаното по
  /// [appleEventId], иначе първото), изтрива евентуалните дубли. Връща id-то на
  /// запазеното (или null, ако няма съвпадение → ще се създаде ново).
  Future<String?> _reconcileExisting(
      String calendarId, Task task, tz.TZDateTime start) async {
    try {
      final dayStart = tz.TZDateTime(tz.local, start.year, start.month, start.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final res = await _plugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: dayStart, endDate: dayEnd),
      );
      if (res == null || !res.isSuccess || res.data == null) return null;

      final matches = res.data!
          .where((e) =>
              e.eventId != null &&
              e.title == task.title &&
              e.start != null &&
              e.start!.difference(start).inMinutes.abs() < 2)
          .toList();
      if (matches.isEmpty) return null;

      final keepId = matches
          .firstWhere((e) => e.eventId == task.appleEventId,
              orElse: () => matches.first)
          .eventId;
      for (final extra in matches) {
        if (extra.eventId != keepId) {
          await _plugin.deleteEvent(calendarId, extra.eventId!);
        }
      }
      return keepId;
    } catch (e) {
      debugPrint('IosCalendarService._reconcileExisting error: $e');
      return null;
    }
  }

  /// Изтрива събитието(ята) на задачата от Apple Calendar. Маха както
  /// свързаното по [appleEventId], така и евентуални нетракнати дубли (по
  /// заглавие+дата) → изтриването е сигурно дори при стари двойни записи.
  /// Викай ПРЕДИ задачата да се махне от taskBox (TombstoneService.deleteTask).
  Future<bool> deleteEventFor(Task task) async {
    try {
      final calendarId = await _getSelectedCalendarId();
      if (calendarId == null) return false;

      bool deletedAny = false;
      if (task.appleEventId != null) {
        final r = await _plugin.deleteEvent(calendarId, task.appleEventId!);
        if (r.isSuccess) deletedAny = true;
      }

      // Изчисти и нетракнати дубли за същата задача.
      final start = tz.TZDateTime.from(task.dueDate, tz.local);
      final dayStart = tz.TZDateTime(tz.local, start.year, start.month, start.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final res = await _plugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: dayStart, endDate: dayEnd),
      );
      if (res != null && res.isSuccess && res.data != null) {
        for (final e in res.data!) {
          if (e.eventId != null &&
              e.title == task.title &&
              e.start != null &&
              e.start!.difference(start).inMinutes.abs() < 2) {
            await _plugin.deleteEvent(calendarId, e.eventId!);
            deletedAny = true;
          }
        }
      }

      task.appleEventId = null;
      if (task.isInBox) {
        task.touch();
        await task.save();
      }
      return deletedAny;
    } catch (e) {
      debugPrint('IosCalendarService.deleteEventFor error: $e');
      return false;
    }
  }

  /// Еднократен експорт/реконсилиране при включване на Apple sync: първо чисти
  /// заварени дубли ([removeDuplicateEvents]), после за всяка отворена задача
  /// гарантира едно събитие (осиновява/чисти чрез [syncTask]). Връща броя
  /// новосвързани задачи.
  Future<int> exportOpenTasks(List<Task> tasks) async {
    await removeDuplicateEvents(tasks);
    int count = 0;
    for (final task in tasks) {
      if (task.isCompleted || task.isArchived || task.deleted) continue;
      final had = task.appleEventId != null;
      final ok = await syncTask(task);
      if (ok && !had && task.appleEventId != null) count++;
    }
    return count;
  }

  /// Премахва дублиращи се събития от ВСИЧКИ записваеми календари (вкл. стари
  /// Google-събития, синхронизирани към iPhone). Групира по заглавие + ден и за
  /// всяка група с повече от едно събитие изтрива излишните — дори когато са в
  /// различни календари. Запазва събитието, чийто час съвпада с реална задача;
  /// иначе това в избрания календар; иначе най-ранното. Сканира ~2 г. назад /
  /// 3 г. напред. Връща (изтрити, сканирани). Безопасно: пипа само групи с ≥2
  /// еднакви по заглавие+ден събития.
  Future<({int removed, int scanned, int dupeGroups, int blockedReadonly})>
      removeDuplicateEvents(List<Task> tasks) async {
    try {
      final calRes = await _plugin.retrieveCalendars();
      final cals = (calRes.isSuccess && calRes.data != null)
          ? calRes.data!
          : <Calendar>[];
      if (cals.isEmpty) {
        return (removed: 0, scanned: 0, dupeGroups: 0, blockedReadonly: 0);
      }
      // id → дали е записваем (можем да трием от него).
      final writable = <String, bool>{
        for (final c in cals)
          if (c.id != null) c.id!: c.isReadOnly == false,
      };

      final now = tz.TZDateTime.now(tz.local);
      final params = RetrieveEventsParams(
        startDate: now.subtract(const Duration(days: 730)),
        endDate: now.add(const Duration(days: 1095)),
      );

      // Сканирай събитията от ВСИЧКИ календари (вкл. read-only).
      final all = <({Event e, String calId})>[];
      for (final cal in cals) {
        if (cal.id == null) continue;
        final res = await _plugin.retrieveEvents(cal.id, params);
        if (res != null && res.isSuccess && res.data != null) {
          for (final e in res.data!) {
            if (e.eventId != null && e.start != null) {
              all.add((e: e, calId: cal.id!));
            }
          }
        }
      }

      // Предпочитани начала по заглавие от текущите задачи — пазим точното.
      final wanted = <String, List<DateTime>>{};
      for (final tk in tasks) {
        if (tk.isCompleted || tk.isArchived || tk.deleted) continue;
        wanted.putIfAbsent(tk.title, () => []).add(tk.dueDate);
      }

      // Групиране по заглавие + ден (между всички календари).
      final groups = <String, List<({Event e, String calId})>>{};
      for (final item in all) {
        final s = item.e.start!;
        groups
            .putIfAbsent('${item.e.title}@${s.year}-${s.month}-${s.day}', () => [])
            .add(item);
      }

      int removed = 0;
      int dupeGroups = 0;
      int blockedReadonly = 0;
      for (final group in groups.values) {
        if (group.length < 2) continue;
        dupeGroups++;
        group.sort((a, b) => a.e.start!.millisecondsSinceEpoch
            .compareTo(b.e.start!.millisecondsSinceEpoch));

        // Пазим ЗАПИСВАЕМО събитие, съвпадащо с час на задача (за да остане
        // валидна връзката); иначе първото записваемо; иначе първото изобщо.
        final times = wanted[group.first.e.title];
        ({Event e, String calId})? keep;
        if (times != null) {
          for (final it in group) {
            if (writable[it.calId] == true &&
                times.any((dt) => it.e.start!
                        .difference(tz.TZDateTime.from(dt, tz.local))
                        .inMinutes
                        .abs() <
                    2)) {
              keep = it;
              break;
            }
          }
        }
        keep ??= group.firstWhere((it) => writable[it.calId] == true,
            orElse: () => group.first);

        for (final it in group) {
          if (it.e.eventId == keep.e.eventId && it.calId == keep.calId) continue;
          if (writable[it.calId] == true) {
            final r = await _plugin.deleteEvent(it.calId, it.e.eventId!);
            if (r.isSuccess) removed++;
          } else {
            // Дубъл в read-only календар (напр. синхронизиран Google акаунт) —
            // не можем да го изтрием от устройството.
            blockedReadonly++;
          }
        }
      }
      return (
        removed: removed,
        scanned: all.length,
        dupeGroups: dupeGroups,
        blockedReadonly: blockedReadonly,
      );
    } catch (e) {
      debugPrint('IosCalendarService.removeDuplicateEvents error: $e');
      return (removed: 0, scanned: 0, dupeGroups: 0, blockedReadonly: 0);
    }
  }
}
