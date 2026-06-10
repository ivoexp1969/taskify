import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'tombstone_service.dart';

/// Безопасни еднократни миграции на локалните данни.
class MigrationService {
  static const _syncFieldsKey = 'sync_fields_migrated_v1';
  static const _appleEventIdsKey = 'apple_event_ids_migrated_v1';
  static const _iosEventPrefix = 'ios_cal_event_';

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

  /// Чисти стари tombstones (purge след 30 дни). Безопасно за извикване при старт.
  static Future<void> purgeOldTombstones() async {
    try {
      await TombstoneService().purgeOld();
    } catch (_) {
      // Не блокирай старта при проблем с purge.
    }
  }
}
