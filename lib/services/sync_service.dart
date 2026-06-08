import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:hive/hive.dart';

import '../models/task.dart';
import '../models/category.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'tombstone_service.dart';

/// Резултат от един merge синхрон.
class SyncResult {
  final bool success;
  final String? error;
  final int downloaded;
  final int uploaded;
  final int deletedLocally;
  const SyncResult({
    required this.success,
    this.error,
    this.downloaded = 0,
    this.uploaded = 0,
    this.deletedLocally = 0,
  });
}

/// Merge синхронизация с облака (Firestore) — ЗАМЕСТВА старото „огледало".
///
/// Принципи (виж ФАЗА 2 от заданието):
///  • Облакът е ОБЕДИНЕНА истина, не копие на едно устройство.
///  • Съпоставяне по стабилен `Task.id`. Липса на задача от едната страна
///    НИКОГА не означава изтриване — изтриване само през tombstone.
///  • Конфликт се решава с last-write-wins по `updatedAt` (millis).
///  • Изтриване бие редакция, ако deletedAt е по-ново от updatedAt.
class SyncService {
  SyncService._internal();
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  final TombstoneService _tomb = TombstoneService();

  /// Известява UI-я кога тече синхрон (за индикатор).
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  bool _syncInProgress = false;
  // Докато прилагаме облачни промени локално, заглушаваме box.watch авто-стампа
  // и авто-sync тригера, за да няма цикъл (remote запис → „локална промяна").
  bool _applyingRemote = false;
  final Set<dynamic> _justStamped = <dynamic>{};

  Timer? _debounce;
  StreamSubscription? _boxSub;
  bool _autoStarted = false;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _tasksRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('tasks');
  }

  CollectionReference<Map<String, dynamic>>? get _categoriesRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('categories');
  }

  // ======================= АВТОМАТИЧНИ ТРИГЕРИ =======================

  /// Стартира авто-синхрона: (1) стампва updatedAt при всяка локална промяна,
  /// (2) пуска debounce-нат синхрон след промяна. Викай веднъж при старт.
  void startAutoSync() {
    if (_autoStarted) return;
    _autoStarted = true;
    final box = Hive.box<Task>('tasks');
    _boxSub = box.watch().listen((BoxEvent event) async {
      if (_applyingRemote) return; // промяната идва от самия sync — игнорирай
      if (event.deleted) {
        _scheduleDebouncedSync();
        return;
      }
      final key = event.key;
      // Ехо от собствения ни стамп-запис → не стампвай пак, само синхронизирай.
      if (_justStamped.remove(key)) {
        _scheduleDebouncedSync();
        return;
      }
      // Истинска локална промяна → отбележи я с пресен updatedAt (last-write-wins).
      final task = box.get(key);
      if (task != null) {
        _justStamped.add(key);
        task.updatedAt = DateTime.now();
        await task.save();
      }
      _scheduleDebouncedSync();
    });
  }

  void _scheduleDebouncedSync() {
    if (_userId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () {
      mergeWithCloud();
    });
  }

  /// Викай при старт на приложението и при връщане на фокус (resume).
  Future<void> syncNow() => mergeWithCloud();

  // ======================= MERGE АЛГОРИТЪМ =======================

  Future<SyncResult> mergeWithCloud() async {
    final tasksRef = _tasksRef;
    if (tasksRef == null) {
      return const SyncResult(success: false, error: 'not-signed-in');
    }
    if (_syncInProgress) {
      return const SyncResult(success: false, error: 'in-progress');
    }
    _syncInProgress = true;
    syncing.value = true;
    int downloaded = 0, uploaded = 0, deletedLocally = 0;

    try {
      final taskBox = Hive.box<Task>('tasks');

      // --- Категории: union merge (без изтриване) ---
      await _mergeCategories();

      // --- Локално състояние по id ---
      final localById = <String, Task>{};
      for (final t in taskBox.values) {
        localById[t.ensureId()] = t;
      }
      final localTombstones = _tomb.all(); // id -> deletedAt

      // --- Облачно състояние ---
      final snap = await tasksRef.get();
      final cloudDocs = <String, Map<String, dynamic>>{};
      for (final d in snap.docs) {
        cloudDocs[d.id] = d.data();
      }

      _applyingRemote = true;

      // === 1) Реконсилиране на всеки облачен документ ===
      for (final entry in cloudDocs.entries) {
        final cid = entry.key;
        final data = entry.value;
        final cloudUpdated = _readMillis(data['updatedAtMillis']) ?? 0;
        final cloudDeleted = data['deleted'] == true;
        final cloudDeletedAt =
            _readMillis(data['deletedAtMillis']) ?? cloudUpdated;

        final localTask = localById[cid];
        final localTombAt = localTombstones[cid];

        if (cloudDeleted) {
          // Облакът казва „изтрита".
          if (localTask != null) {
            final localUpdated =
                localTask.updatedAt?.millisecondsSinceEpoch ?? 0;
            if (localUpdated > cloudDeletedAt) {
              // Локалната редакция е по-нова от изтриването → редакцията печели:
              // „възкресяваме" в облака.
              await _writeCloudTask(tasksRef, localTask);
              uploaded++;
            } else {
              // Изтриването печели → махни локално + tombstone.
              await _applyLocalDelete(localTask, cid, cloudDeletedAt);
              localById.remove(cid);
              deletedLocally++;
            }
          } else {
            // Няма локално → подсигури локален tombstone (да не се пресъздава).
            if (localTombAt == null) {
              await _tomb.recordId(cid,
                  at: DateTime.fromMillisecondsSinceEpoch(cloudDeletedAt));
            }
          }
          continue;
        }

        // Облакът НЕ е изтрит.
        if (localTombAt != null) {
          // Изтрили сме я локално.
          if (localTombAt.millisecondsSinceEpoch >= cloudUpdated) {
            // Нашето изтриване е по-ново → разпространи го към облака.
            await _writeCloudTombstone(tasksRef, cid, localTombAt);
          } else {
            // Облачна редакция по-нова от изтриването → редакцията печели →
            // върни задачата локално и махни tombstone-а.
            final t = _taskFromCloud(data);
            await taskBox.add(t);
            await _rescheduleNotifs(t);
            await _tomb.clear(cid);
            localById[cid] = t;
            downloaded++;
          }
          continue;
        }

        if (localTask == null) {
          // Само в облака → свали локално.
          final t = _taskFromCloud(data);
          await taskBox.add(t);
          await _rescheduleNotifs(t);
          localById[cid] = t;
          downloaded++;
        } else {
          // И на двете места → печели по-новата версия.
          final localUpdated = localTask.updatedAt?.millisecondsSinceEpoch ?? 0;
          if (cloudUpdated > localUpdated) {
            _applyCloudToTask(localTask, data);
            await localTask.save(); // _applyingRemote пази watch-а да не стампва
            await _rescheduleNotifs(localTask);
            downloaded++;
          } else if (localUpdated > cloudUpdated) {
            await _writeCloudTask(tasksRef, localTask);
            uploaded++;
          }
          // равни → нищо
        }
      }

      // === 2) Локални задачи, които ги няма в облака → качи ги ===
      for (final entry in localById.entries) {
        if (!cloudDocs.containsKey(entry.key)) {
          await _writeCloudTask(tasksRef, entry.value);
          uploaded++;
        }
      }

      // === 3) Локални tombstones, които ги няма в облака → запиши tombstone ===
      for (final entry in localTombstones.entries) {
        if (!cloudDocs.containsKey(entry.key)) {
          await _writeCloudTombstone(tasksRef, entry.key, entry.value);
        }
      }

      return SyncResult(
        success: true,
        downloaded: downloaded,
        uploaded: uploaded,
        deletedLocally: deletedLocally,
      );
    } catch (e) {
      debugPrint('SYNC merge error: $e');
      return SyncResult(success: false, error: e.toString());
    } finally {
      _applyingRemote = false;
      _syncInProgress = false;
      syncing.value = false;
    }
  }

  Future<void> _applyLocalDelete(Task task, String id, int deletedAtMillis) async {
    await NotificationService().cancelForTask(task);
    await _tomb.recordId(id,
        at: DateTime.fromMillisecondsSinceEpoch(deletedAtMillis));
    if (task.isInBox) await task.delete();
  }

  Future<void> _rescheduleNotifs(Task task) async {
    if (kIsWeb) return;
    try {
      await NotificationService().cancelForTask(task);
      if (!task.isCompleted && task.hasReminders) {
        await NotificationService().scheduleForTask(task);
      }
    } catch (_) {}
  }

  // ======================= КАТЕГОРИИ =======================

  Future<void> _mergeCategories() async {
    final ref = _categoriesRef;
    if (ref == null) return;
    final box = Hive.box<Category>('categories');

    final snap = await ref.get();
    final cloudIds = <String>{};
    for (final d in snap.docs) {
      final data = d.data();
      cloudIds.add(d.id);
      if (box.get(d.id) == null) {
        await box.put(
          d.id,
          Category(
            id: data['id'] as String? ?? d.id,
            name: data['name'] as String? ?? '',
            colorValue: data['colorValue'] as int? ?? 0xFF2196F3,
            isDefault: data['isDefault'] as bool? ?? false,
          ),
        );
      }
    }
    // Качи локалните категории, които ги няма в облака.
    for (final cat in box.values) {
      if (!cloudIds.contains(cat.id)) {
        await ref.doc(cat.id).set({
          'id': cat.id,
          'name': cat.name,
          'colorValue': cat.colorValue,
          'isDefault': cat.isDefault,
        });
      }
    }
  }

  // ======================= FIRESTORE МАПИНГ =======================

  int? _readMillis(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Map<String, dynamic> _taskToCloud(Task task) {
    final updated = task.updatedAt ?? DateTime.now();
    return {
      'id': task.id,
      'title': task.title,
      'dueDate': task.dueDate.toIso8601String(),
      'categoryId': task.categoryId,
      'priority': task.priority,
      'isCompleted': task.isCompleted,
      'recurrence': task.recurrence,
      'reminder': task.reminder,
      'reminders': task.reminders,
      'subtasks': task.subtasks,
      'notes': task.notes,
      'completedAt': task.completedAt?.toIso8601String(),
      'isArchived': task.isArchived,
      'archivedAt': task.archivedAt?.toIso8601String(),
      'durationMinutes': task.durationMinutes,
      'template': task.template,
      'googleCalendarEventId': task.googleCalendarEventId,
      'importedFromCalendar': task.importedFromCalendar,
      'deleted': false,
      'deletedAtMillis': null,
      'updatedAtMillis': updated.millisecondsSinceEpoch,
      // ФАЗА 2Г: сървърен timestamp за одит/таймбрейк при разминати часовници.
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _writeCloudTask(
      CollectionReference<Map<String, dynamic>> ref, Task task) async {
    await ref.doc(task.ensureId()).set(_taskToCloud(task));
  }

  Future<void> _writeCloudTombstone(
      CollectionReference<Map<String, dynamic>> ref,
      String id,
      DateTime deletedAt) async {
    await ref.doc(id).set({
      'id': id,
      'deleted': true,
      'deletedAtMillis': deletedAt.millisecondsSinceEpoch,
      'updatedAtMillis': deletedAt.millisecondsSinceEpoch,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Task _taskFromCloud(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) =>
        v is String ? DateTime.tryParse(v) : null;
    final updatedMillis = _readMillis(data['updatedAtMillis']);
    final task = Task(
      title: data['title'] as String? ?? '',
      dueDate: parseDate(data['dueDate']) ?? DateTime.now(),
      categoryId: data['categoryId'] as String? ?? 'personal',
      priority: data['priority'] as int? ?? 1,
      recurrence: data['recurrence'] as String?,
      reminder: data['reminder'] as String?,
      reminders: (data['reminders'] as List<dynamic>?)?.cast<String>(),
      subtasks: (data['subtasks'] as List<dynamic>?)?.cast<String>(),
      notes: data['notes'] as String?,
      completedAt: parseDate(data['completedAt']),
      isArchived: data['isArchived'] as bool? ?? false,
      archivedAt: parseDate(data['archivedAt']),
      durationMinutes: data['durationMinutes'] as int?,
      template: data['template'] as String?,
      googleCalendarEventId: data['googleCalendarEventId'] as String?,
      importedFromCalendar: data['importedFromCalendar'] as bool?,
      id: data['id'] as String?,
      updatedAt: updatedMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(updatedMillis)
          : DateTime.now(),
    );
    task.isCompleted = data['isCompleted'] as bool? ?? false;
    return task;
  }

  /// Прилага облачните стойности върху съществуваща локална задача (запазва
  /// Hive ключа и идентичността на обекта).
  void _applyCloudToTask(Task task, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) =>
        v is String ? DateTime.tryParse(v) : null;
    task.title = data['title'] as String? ?? task.title;
    task.dueDate = parseDate(data['dueDate']) ?? task.dueDate;
    task.categoryId = data['categoryId'] as String? ?? task.categoryId;
    task.priority = data['priority'] as int? ?? task.priority;
    task.isCompleted = data['isCompleted'] as bool? ?? false;
    task.recurrence = data['recurrence'] as String?;
    task.reminder = data['reminder'] as String?;
    task.reminders = (data['reminders'] as List<dynamic>?)?.cast<String>();
    task.subtasks = (data['subtasks'] as List<dynamic>?)?.cast<String>();
    task.notes = data['notes'] as String?;
    task.completedAt = parseDate(data['completedAt']);
    task.isArchived = data['isArchived'] as bool? ?? false;
    task.archivedAt = parseDate(data['archivedAt']);
    task.durationMinutes = data['durationMinutes'] as int?;
    task.template = data['template'] as String?;
    task.googleCalendarEventId = data['googleCalendarEventId'] as String?;
    task.importedFromCalendar = data['importedFromCalendar'] as bool?;
    final updatedMillis = _readMillis(data['updatedAtMillis']);
    if (updatedMillis != null) {
      task.updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedMillis);
    }
  }

  void dispose() {
    _debounce?.cancel();
    _boxSub?.cancel();
  }
}
