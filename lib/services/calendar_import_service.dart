import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../utils/localization.dart';
import 'google_calendar_service.dart';
import 'tombstone_service.dart';

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

    // Near-duplicate по заглавие+дата (±1 ден) върху ВСИЧКИ задачи. Връща
    // съществуващата задача (или null), за да можем да я СВЪРЖЕМ със събитието,
    // ако още няма googleCalendarEventId. Това е ключово: възстановени от бекъп
    // календарни задачи (без eventId) се РЕ-СВЪРЗВАТ вместо да се дублират — и
    // спира експортът да създава дубли в Google Calendar.
    // Свързва ВСИЧКИ съществуващи задачи, които съвпадат с това събитие, като им
    // слага същия eventId. Съвпадение = същото заглавие И (дата ±1 ден ИЛИ същи
    // ден+месец, игнорирайки годината — за ГОДИШНИ събития като рождени дни!).
    // След това облачният дедуп по eventId ги свежда до една → лекува и СТАРИ
    // дубли без ново нулиране. Връща true при поне едно съвпадение (→ не създавай
    // нова задача).
    Future<bool> linkOrSkip(String eventId, String title, DateTime date) async {
      final key = title.trim().toLowerCase();
      bool found = false;
      for (final tk in taskBox.values) {
        if (tk.title.trim().toLowerCase() != key) continue;
        final d = tk.dueDate;
        final near = d.difference(date).inDays.abs() <= 1;
        final sameDayMonth = d.month == date.month && d.day == date.day;
        if (!near && !sameDayMonth) continue;
        found = true;
        if (tk.googleCalendarEventId == null) {
          tk.googleCalendarEventId = eventId;
          tk.importedFromCalendar = true;
          await tk.save();
        }
      }
      return found;
    }

    int imported = 0;
    int skipped = 0;

    final now = DateTime.now();
    final thresholdDate = now.subtract(const Duration(days: 30));

    // === 1. CALENDAR EVENTS ===
    final events = await calendarService.getUpcomingEvents(days: 365, interactive: interactive);

    // Google рождените дни (eventType=birthday) дублират НАТИВНИТЕ рождени дни на
    // приложението (различно заглавие „Рожден ден на X" срещу „X") → НЕ ги
    // импортираме (виж скока по-долу). Освен това ЧИСТИМ вече импортирани такива
    // (свързани с birthday събитие) по стабилен base-id (без годишния суфикс),
    // за да изчезнат старите дубли без ново нулиране. Томбстоун → пада и в облака.
    final birthdayBaseIds = <String>{};
    for (final e in events) {
      if ((e['eventType'] as String?) == 'birthday') {
        final id = e['id'] as String?;
        if (id != null) {
          birthdayBaseIds.add(id.contains('_') ? id.split('_').first : id);
        }
      }
    }
    if (birthdayBaseIds.isNotEmpty) {
      final tomb = TombstoneService();
      for (final tk in taskBox.values.toList()) {
        if (tk.importedFromCalendar != true) continue;
        final gid = tk.googleCalendarEventId;
        if (gid == null) continue;
        final base = gid.contains('_') ? gid.split('_').first : gid;
        if (birthdayBaseIds.contains(base)) {
          await tomb.recordId(tk.ensureId());
          await tk.delete();
          skipped++;
        }
      }
    }

    // Нативните рождени дни (template='birthday') се управляват САМО в
    // приложението. Календарни събития, които ги дублират („Рожден ден на X"
    // в същия ден като нативния „X" — различно заглавие, дори времеви, не
    // eventType=birthday), НЕ се импортират; вече импортирани такива дубли се
    // чистят тук (по съдържание на името + ден/месец, без годината).
    final nativeBdays = taskBox.values
        .where((t) =>
            (t.categoryId == 'birthday' || t.template == 'birthday') &&
            t.title.trim().isNotEmpty)
        .map((t) => MapEntry(t.title.trim().toLowerCase(), t.dueDate))
        .toList();
    // Годишно съвпадение с толеранс ±1 ден (игнорирай годината). Покрива и
    // вечерни напомняния (14-ти 21:00 за рожден ден на 15-ти) и часови отмествания.
    bool annualWithin1(DateTime a, DateTime b) {
      final na = DateTime(2000, a.month, a.day);
      final nb = DateTime(2000, b.month, b.day);
      final d = na.difference(nb).inDays.abs();
      return d <= 1 || d >= 365; // ±1 ден, вкл. край-на-година (31.12 ↔ 01.01)
    }
    bool dupOfNativeBirthday(String title, DateTime date) {
      final low = title.trim().toLowerCase();
      for (final nb in nativeBdays) {
        if (annualWithin1(nb.value, date) && low.contains(nb.key)) {
          return true;
        }
      }
      return false;
    }
    if (nativeBdays.isNotEmpty) {
      final tomb = TombstoneService();
      for (final tk in taskBox.values.toList()) {
        if (tk.importedFromCalendar != true) continue;
        if (tk.categoryId == 'birthday' || tk.template == 'birthday') {
          continue; // нативните рождени дни не се пипат
        }
        if (dupOfNativeBirthday(tk.title, tk.dueDate)) {
          await tomb.recordId(tk.ensureId());
          await tk.delete();
          skipped++;
        }
      }
    }

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
      // Google рождените дни се управляват нативно от приложението → пропусни.
      if (eventType == 'birthday') { skipped++; continue; }

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

      // Дублира нативен рожден ден („Рожден ден на X" ↔ нативен „X") → пропусни.
      final eventTitle = event['summary'] as String? ?? '';
      if (dupOfNativeBirthday(eventTitle, dueDate)) { skipped++; continue; }
      // Near-duplicate: ако вече съществува (свържи я при липсващ eventId).
      if (await linkOrSkip(eventId, eventTitle, dueDate)) { skipped++; continue; }

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
      if (await linkOrSkip(prefixedId, gtaskTitle, dueDate)) { skipped++; continue; }

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
