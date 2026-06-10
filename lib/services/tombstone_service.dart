import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import 'ios_calendar_service.dart';

/// Управлява „надгробните камъни" (tombstones) на изтритите задачи.
///
/// Дизайн: при изтриване задачата се МАХА от taskBox (както досега, така целият
/// UI остава непроменен), но id-то ѝ + времето на изтриване се записват в
/// отделна Hive кутия `tombstones`. Sync слоят чете тези записи, за да:
///   • разпространи изтриването до облака/другите устройства (events.delete);
///   • НЕ „възкръси" задача само защото още я има в облака.
///
/// Кутията е `Box<int>`: ключ = `task.id` (UUID), стойност = deletedAt millis.
class TombstoneService {
  TombstoneService._internal();
  static final TombstoneService _instance = TombstoneService._internal();
  factory TombstoneService() => _instance;

  static const String boxName = 'tombstones';

  /// Tombstone-ите се чистят след толкова дни — достатъчно изтриването да се
  /// разпространи навсякъде, без задачите да „възкръсват".
  static const int purgeAfterDays = 30;

  Box<int> get _box => Hive.box<int>(boxName);

  /// Регистрира изтриване на задача. Викай ПРЕДИ да махнеш задачата от taskBox.
  Future<void> record(Task task) async {
    final id = task.ensureId();
    await _box.put(id, DateTime.now().millisecondsSinceEpoch);
  }

  /// Регистрира изтриване директно по id (когато задачата вече я няма локално,
  /// напр. дошло от облака изтриване).
  Future<void> recordId(String id, {DateTime? at}) async {
    await _box.put(id, (at ?? DateTime.now()).millisecondsSinceEpoch);
  }

  bool isDeleted(String id) => _box.containsKey(id);

  /// Времето на изтриване (или null ако няма tombstone).
  DateTime? deletedAt(String id) {
    final millis = _box.get(id);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Премахва tombstone-а (напр. когато редакция от друго устройство печели
  /// конфликта и задачата трябва да се върне).
  Future<void> clear(String id) async {
    await _box.delete(id);
  }

  /// Всички текущи tombstones: id → deletedAt.
  Map<String, DateTime> all() {
    final result = <String, DateTime>{};
    for (final key in _box.keys) {
      final millis = _box.get(key);
      if (millis != null && key is String) {
        result[key] = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    return result;
  }

  /// Чисти tombstones по-стари от [purgeAfterDays] дни (purge). Викай при старт.
  Future<int> purgeOld() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: purgeAfterDays))
        .millisecondsSinceEpoch;
    final toRemove = <dynamic>[];
    for (final key in _box.keys) {
      final millis = _box.get(key);
      if (millis != null && millis < cutoff) toRemove.add(key);
    }
    for (final key in toRemove) {
      await _box.delete(key);
    }
    return toRemove.length;
  }

  /// Изтрива задача с tombstone — записва надгробния камък, после маха записа от
  /// taskBox. Това е ЕДИНСТВЕНИЯТ начин за изтриване на задача (за да се
  /// разпространи изтриването). UI-ят вика този метод вместо `task.delete()`.
  Future<void> deleteTask(Task task) async {
    // Apple Calendar (export-only): махни събитието ПРЕДИ да изчезне задачата —
    // после appleEventId вече няма да е достъпно. exportEnabled е true само на
    // iOS при избран Apple източник, затова няма ефект на Android/web.
    if (!kIsWeb && IosCalendarService.exportEnabled) {
      await IosCalendarService().deleteEventFor(task);
    }
    await record(task);
    if (task.isInBox) await task.delete();
  }
}
