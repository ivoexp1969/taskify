import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../models/expiring_document.dart';
import 'documents_service.dart';
import 'notification_service.dart';
import 'tombstone_service.dart';

/// Безопасни еднократни миграции на локалните данни.
class MigrationService {
  static const _syncFieldsKey = 'sync_fields_migrated_v1';
  static const _appleEventIdsKey = 'apple_event_ids_migrated_v1';
  static const _documentsToTasksKey = 'documents_to_tasks_migrated_v1';
  static const _dedupeCategoriesKey = 'dedupe_categories_v1';
  static const _iosEventPrefix = 'ios_cal_event_';

  /// Обединява категории с ЕДНАКВО име (напр. два пъти „Събития") в една:
  /// задачите се прехвърлят към първата, дубликатите се трият. Еднократно.
  /// Системните категории имат уникални имена → не се засягат погрешно.
  static Future<void> dedupeCategories() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dedupeCategoriesKey) ?? false) return;

    final categoryBox = Hive.box<Category>('categories');
    final taskBox = Hive.box<Task>('tasks');
    final keptByName = <String, String>{}; // нормализирано име → запазено id
    final toDelete = <String>[];

    for (final c in categoryBox.values) {
      final key = c.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      final keptId = keptByName[key];
      if (keptId == null) {
        keptByName[key] = c.id;
      } else if (keptId != c.id) {
        // Дубликат → прехвърли задачите към запазената и маркирай за триене.
        for (final t in taskBox.values.where((t) => t.categoryId == c.id)) {
          t.categoryId = keptId;
          await t.save();
        }
        toDelete.add(c.id);
      }
    }
    for (final id in toDelete) {
      await categoryBox.delete(id);
    }
    await prefs.setBool(_dedupeCategoriesKey, true);
  }

  /// Гарантира, че всяка съществуваща задача има стабилен `id` и `updatedAt`,
  /// записани ТРАЙНО в Hive. Конструкторът на Task вече присвоява id/updatedAt
  /// в паметта при четене на стара задача, но без save() те се преген��рират при
  /// всяко четене. Тук ги записваме веднъж, за да станат постоянни и
  /// синхронизацията да съпоставя задачите коректно по id.
  ///
  /// КРИТИЧНО: НЕ изтрива и НЕ преподрежда нищо — само допълва липсващи полета.
  static Future<void> migrateTaskSyncFields() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_syncFieldsKey) ?? false) return;

    final box = Hive.box<Task>('tasks');
    final seenIds = <String>{};
    for (final task in box.values) {
      bool dirty = false;

      // id: присвои нов само ако липсва. Ако (теоретично) две задачи имат
      // еднакъв id, разреши колизията с нов id за втората.
      if (task.id == null || task.id!.isEmpty || !seenIds.add(task.id!)) {
        task.id = null; // нулирай, ensureId() ще генерира нов
        task.ensureId();
        seenIds.add(task.id!);
        dirty = true;
      }

      if (task.updatedAt == null) {
        // Стартова стойност = сега. Не знаем реалното време на последна промяна,
        // но това е безопасно — нищо в облака още няма по-нов updatedAt.
        task.updatedAt = DateTime.now();
        dirty = true;
      }

      if (dirty) await task.save();
    }

    await prefs.setBool(_syncFieldsKey, true);
  }

  /// Мигрира стария Apple Calendar mapping (SharedPreferences ключове
  /// `ios_cal_event_<key|title.hashCode>` → eventId) в новото поле
  /// [Task.appleEventId]. Така редакция/изтриване вече обновяват/махат същото
  /// събитие (merge архитектура), вместо да плодят дубли.
  ///
  /// КРИТИЧНО: само допълва липсващи полета и чисти старите ключове. Викай след
  /// [migrateTaskSyncFields] (за да са стабилни id-тата на задачите).
  static Future<void> migrateAppleEventIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_appleEventIdsKey) ?? false) return;

    final box = Hive.box<Task>('tasks');
    for (final task in box.values) {
      if (task.appleEventId != null) continue;
      // Старият ключ беше `ios_cal_event_${task.key ?? task.title.hashCode}`.
      final byKey = prefs.getString('$_iosEventPrefix${task.key}');
      final eventId =
          byKey ?? prefs.getString('$_iosEventPrefix${task.title.hashCode}');
      if (eventId != null && eventId.isNotEmpty) {
        task.appleEventId = eventId;
        await task.save();
      }
    }

    // Чистим всички стари ios_cal_event_* ключове — вече ненужни.
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_iosEventPrefix)) await prefs.remove(key);
    }

    await prefs.setBool(_appleEventIdsKey, true);
  }

  /// Мигрира старите документи с изтичащ срок (Hive box `bg_documents`, използван
  /// от стария раздел „България") в обикновени задачи (template `document`, категория
  /// `documents`). Така документите получават наготово Календар/„Днес"/облачен синхрон,
  /// а отделната система отпада.
  ///
  /// КРИТИЧНО за cross-device: task id-то е ДЕТЕРМИНИСТИЧНО (`doc_<docId>`), за да се
  /// слее (а не дублира) ако две устройства мигрират едни и същи документи. Идемпотентно.
  static Future<void> migrateDocumentsToTasks() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_documentsToTasksKey) ?? false) return;

    Box docBox;
    try {
      docBox = Hive.isBoxOpen('bg_documents')
          ? Hive.box('bg_documents')
          : await Hive.openBox('bg_documents');
    } catch (_) {
      await prefs.setBool(_documentsToTasksKey, true);
      return;
    }

    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');
    final lang = prefs.getString('app_language') ?? 'en';

    // Гарантирай категория „Документи" (локализира се по id навсякъде).
    if (categoryBox.get('documents') == null) {
      await categoryBox.put('documents', Category(
        id: 'documents', name: 'Documents', colorValue: 0xFF455A64, isDefault: false));
    }

    final existingIds = taskBox.values.map((t) => t.id).whereType<String>().toSet();

    for (final v in docBox.values) {
      if (v is! String || v.isEmpty) continue;
      ExpiringDocument doc;
      try {
        doc = ExpiringDocument.fromJson(json.decode(v) as Map<String, dynamic>);
      } catch (_) {
        continue;
      }

      final taskId = 'doc_${doc.id}';
      if (existingIds.contains(taskId)) continue;

      // Отмени старите док-нотификации (новата задача планира свои).
      for (final nid in doc.notificationIds) {
        try {
          await NotificationService().cancelNotification(nid);
        } catch (_) {}
      }

      final label = doc.label?.trim() ?? '';
      final title = documentTypeName(doc.type, lang, label: label.isEmpty ? null : label);
      final notes = [
        'doctype:${doc.type}',
        if (label.isNotEmpty) 'label:$label',
      ].join('\n');
      // Срокът в 09:00, за да падат напомнянията в разумен час.
      final dueDate = DateTime(doc.expiryDate.year, doc.expiryDate.month, doc.expiryDate.day, 9);
      final reminders = doc.reminderDays.map(_dayToReminderToken).toList();

      final task = Task(
        title: title,
        dueDate: dueDate,
        categoryId: 'documents',
        priority: 1,
        template: 'document',
        notes: notes,
        reminders: reminders.isEmpty ? null : reminders,
        id: taskId,
      );
      await taskBox.add(task);
      existingIds.add(taskId);
      try {
        await NotificationService().scheduleForTask(task);
      } catch (_) {}
    }

    // Старите данни вече са задачи — изчисти box-а, за да не висят/възкръсват.
    await docBox.clear();
    await prefs.setBool(_documentsToTasksKey, true);
  }

  /// Дни-преди → токен за напомняне (най-близкият наличен).
  static String _dayToReminderToken(int days) {
    if (days >= 45) return 'minus_2mo';
    if (days >= 21) return 'minus_1mo';
    if (days >= 10) return 'minus_2w';
    if (days >= 5) return 'minus_1w';
    if (days >= 2) return 'minus_3d';
    return 'minus_1d';
  }

  /// Чисти стари tombstones (purge след 30 дни). Безопасно за извикване при старт.
  static Future<void> purgeOldTombstones() async {
    try {
      await TombstoneService().purgeOld();
    } catch (_) {
      // Не блокирай старта при проблем с purge.
    }
  }
}
