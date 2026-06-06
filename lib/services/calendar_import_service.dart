import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../utils/localization.dart';
import 'google_calendar_service.dart';

class CalendarImportService {
  static const _lastSyncKey = 'calendar_last_auto_sync';
  static const _syncIntervalHours = 24;

  /// Връща true ако са минали повече от 24ч от последния автоматичен импорт.
  static Future<bool> shouldAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('google_calendar_connected') ?? false;
    if (!connected) return false;
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastSync;
    return elapsed > _syncIntervalHours * 3600 * 1000;
  }

  /// Записва времето на последния синк.
  static Future<void> markSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Основна логика на импорта. Връща (imported, skipped).
  ///
  /// [interactive] = true само при изричен бутон от потребителя (Settings →
  /// Import). Авто-синкът при старт ползва false → никога не показва auth UI.
  static Future<(int, int)> runImport(
    Box<Task> taskBox,
    Box<Category> categoryBox,
    AppText t, {
    bool interactive = false,
  }) async {
    final calendarService = GoogleCalendarService();

    // --- Категория ID константи ---
    const catIdCalendar = 'cal_events';
    const catIdBirthdays = 'cal_birthdays';
    const catIdOoo = 'cal_ooo';
    const catIdFocus = 'cal_focus';
    const catIdLocation = 'cal_location';
    const catIdGoogleTasks = 'google_tasks';

    // Helper: вземи или създай категория
    Future<String> getOrCreateCat(String id, String name, int color) async {
      var cat = categoryBox.get(id);
      if (cat == null) {
        cat = Category(id: id, name: name, colorValue: color);
        await categoryBox.put(id, cat);
      }
      return cat.id;
    }

    // Миграция: стара категория "calendar" → "cal_events"
    final legacyCalIds = ['calendar', 'Calendar', 'calendar events'];
    for (final legacyId in legacyCalIds) {
      final legacyCat = categoryBox.get(legacyId);
      if (legacyCat != null) {
        if (categoryBox.get(catIdCalendar) == null) {
          await categoryBox.put(catIdCalendar, Category(
            id: catIdCalendar,
            name: t.catCalendarEvents,
            colorValue: 0xFF2196F3,
          ));
        }
        for (final task in taskBox.values.where((task) => task.categoryId == legacyId)) {
          task.categoryId = catIdCalendar;
          await task.save();
        }
        await categoryBox.delete(legacyId);
      }
    }

    // Миграция: старите per-type импорт категории (вкл. нелокализирани като
    // „Birthdays") → една обща „Календарни". Потребителската категория
    // „Рождени дни" (id 'birthday') остава непокътната.
    const oldImportCatIds = [catIdBirthdays, catIdOoo, catIdFocus, catIdLocation, catIdGoogleTasks];
    for (final oldId in oldImportCatIds) {
      if (categoryBox.get(oldId) == null) continue;
      if (categoryBox.get(catIdCalendar) == null) {
        await categoryBox.put(catIdCalendar, Category(
          id: catIdCalendar,
          name: t.catCalendarEvents,
          colorValue: 0xFF2196F3,
        ));
      }
      for (final task in taskBox.values.where((task) => task.categoryId == oldId)) {
        task.categoryId = catIdCalendar;
        await task.save();
      }
      await categoryBox.delete(oldId);
    }

    // Съществуващи ID-та (за exact duplicate check)
    final existingIds = taskBox.values
        .where((t) => t.googleCalendarEventId != null)
        .map((t) => t.googleCalendarEventId!)
        .toSet();

    // Title+Date pairs (за near-duplicate check ±1 ден)
    final importedPairs = taskBox.values
        .where((t) => t.googleCalendarEventId != null)
        .map((t) => MapEntry(t.title.trim().toLowerCase(), t.dueDate))
        .toList();

    bool isNearDuplicate(String title, DateTime date) {
      final key = title.trim().toLowerCase();
      return importedPairs.any((e) {
        if (e.key != key) return false;
        return e.value.difference(date).inDays.abs() <= 1;
      });
    }

    int imported = 0;
    int skipped = 0;

    final now = DateTime.now();
    final thresholdDate = now.subtract(const Duration(days: 30));

    // === 1. CALENDAR EVENTS ===
    final events = await calendarService.getUpcomingEvents(days: 60, interactive: interactive);

    for (final event in events) {
      final eventId = event['id'] as String?;
      if (eventId == null) continue;

      // ID strip за recurring events
      String baseId = eventId;
      if (eventId.contains('_')) baseId = eventId.split('_').first;

      final idExists = existingIds.any((id) =>
          id == eventId || id == baseId || id.split('_').first == baseId);
      if (idExists) { skipped++; continue; }

      final eventType = event['eventType'] as String? ?? 'default';

      // Parse date
      DateTime dueDate;
      try {
        final startDateTime = event['startDateTime'] as String?;
        if (startDateTime == null) { skipped++; continue; }
        if (startDateTime.contains('T')) {
          dueDate = DateTime.parse(startDateTime).toLocal();
        } else {
          final p = startDateTime.split('-');
          dueDate = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        }
        if (dueDate.isBefore(thresholdDate)) { skipped++; continue; }
      } catch (_) { skipped++; continue; }

      // Near-duplicate check
      final eventTitle = event['summary'] as String? ?? '';
      if (isNearDuplicate(eventTitle, dueDate)) { skipped++; continue; }

      // Всичко импортирано отива в ЕДНА локализирана категория „Календарни"
      // (без паразитни/нелокализирани категории като „Birthdays")
      final categoryId = await getOrCreateCat(catIdCalendar, t.catCalendarEvents, 0xFF2196F3);

      final newTask = Task(
        title: eventTitle.isEmpty ? t.untitledEvent : eventTitle,
        dueDate: dueDate,
        categoryId: categoryId,
        priority: eventType == 'birthday' ? 2 : 1,
        notes: event['description'],
        googleCalendarEventId: eventId,
        importedFromCalendar: true,
      );
      await taskBox.add(newTask);
      importedPairs.add(MapEntry(newTask.title.trim().toLowerCase(), newTask.dueDate));
      imported++;
    }

    // === 2. GOOGLE TASKS ===
    final googleTasks = await calendarService.getAllGoogleTasks(interactive: interactive);

    for (final gTask in googleTasks) {
      final taskId = gTask['id'] as String?;
      if (taskId == null) continue;

      final prefixedId = 'gtask_$taskId';
      if (existingIds.contains(prefixedId)) { skipped++; continue; }

      final status = gTask['status'] as String?;
      if (status == 'completed') { skipped++; continue; }

      final dueStr = gTask['due'] as String?;
      if (dueStr == null) { skipped++; continue; }

      DateTime dueDate;
      try {
        final dateOnly = dueStr.length >= 10 ? dueStr.substring(0, 10) : dueStr;
        final p = dateOnly.split('-');
        dueDate = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        if (dueDate.isBefore(thresholdDate)) { skipped++; continue; }
      } catch (_) { skipped++; continue; }

      final gtaskTitle = gTask['title'] as String? ?? '';
      if (isNearDuplicate(gtaskTitle, dueDate)) { skipped++; continue; }
      importedPairs.add(MapEntry(gtaskTitle.trim().toLowerCase(), dueDate));

      // Google Tasks също влизат в общата „Календарни" категория
      final categoryId = await getOrCreateCat(catIdCalendar, t.catCalendarEvents, 0xFF2196F3);

      final newTask = Task(
        title: gtaskTitle.isEmpty ? t.untitledTask : gtaskTitle,
        dueDate: dueDate,
        categoryId: categoryId,
        priority: 1,
        notes: gTask['notes'],
        googleCalendarEventId: prefixedId,
        importedFromCalendar: true,
      );
      await taskBox.add(newTask);
      imported++;
    }

    return (imported, skipped);
  }
}
