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
  // Циркуит брейкър: АВТО-синхрон не се пуска по-често от веднъж на толкова —
  // дори при бъг това спира runaway цикъл. Ръчният syncNow НЕ е ограничен.
  int _lastSyncMs = 0;
  static const int _minAutoSyncGapMs = 15000;

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
      final since = DateTime.now().millisecondsSinceEpoch - _lastSyncMs;
      if (since < _minAutoSyncGapMs) {
        // Твърде скоро след предишен синхрон → изчакай (циркуит брейкър).
        _debounce = Timer(
          Duration(milliseconds: _minAutoSyncGapMs - since + 500),
          () => mergeWithCloud(),
        );
        return;
      }
      mergeWithCloud();
    });
  }

  /// АВТО-тригер (старт, authStateChanges, resume). Минава през циркуит брейкъра
  /// → не по-често от веднъж на _minAutoSyncGapMs. Ръчният бутон в Настройки вика
  /// mergeWithCloud() директно (незабавно).
  Future<void> syncNow() async {
    final since = DateTime.now().millisecondsSinceEpoch - _lastSyncMs;
    if (since < _minAutoSyncGapMs) return;
    await mergeWithCloud();
  }

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
      var localTombstones = _tomb.all(); // id -> deletedAt

      // --- Облачно състояние ---
      final snap = await tasksRef.get();
      final cloudDocs = <String, Map<String, dynamic>>{};
      for (final d in snap.docs) {
        cloudDocs[d.id] = d.data();
      }

      _applyingRemote = true;

      // === PRE-A) LEGACY облачни документи (от старото „огледало") ===
      // Те имат случайно Firestore doc-id и НЯМАТ updatedAtMillis/стабилен id,
      // затова никога не съвпадат по id → старият merge ги сваляше наново при
      // ВСЕКИ синхрон (2x, 3x...). Тук ги консумираме ВЕДНЪЖ: ако съдържанието
      // вече е локално → само трием стария doc; ако е само в облака → сваляме
      // веднъж и пак трием стария doc.
      final legacyIds = <String>[];
      for (final e in cloudDocs.entries) {
        if (e.value['deleted'] == true) continue;
        if (e.value['updatedAtMillis'] == null) legacyIds.add(e.key);
      }
      final localSigs = <String>{
        for (final t in localById.values) _sigTask(t)
      };
      for (final id in legacyIds) {
        final data = cloudDocs[id]!;
        final sig = _sigData(data);
        if (sig != null && !localSigs.contains(sig)) {
          final t = _taskFromCloud(data); // null id → нов стабилен id
          await taskBox.add(t);
          localById[t.id!] = t;
          localSigs.add(sig);
          downloaded++;
        }
        await tasksRef.doc(id).delete();
        cloudDocs.remove(id);
      }

      // === PRE-B) КОНВЕРГЕНТНА дедупликация по съдържание ===
      // Дубли с РАЗЛИЧНИ id (възникнали при миграцията/legacy бъга, дори между
      // устройства) се свеждат до един. Survivor = НАЙ-МАЛКИЯТ id из обединението
      // local+cloud → всички устройства избират ЕДИН и същ → конвергира без
      // загуба на данни. Останалите id-та се tombstone-ват (и в облака).
      final sigGroups = <String, Set<String>>{};
      void addSig(String? sig, String id) {
        if (sig == null) return;
        sigGroups.putIfAbsent(sig, () => <String>{}).add(id);
      }
      for (final t in localById.values) {
        addSig(_sigTask(t), t.id!);
      }
      for (final e in cloudDocs.entries) {
        if (e.value['deleted'] == true) continue;
        if (localById.containsKey(e.key)) continue; // същата задача (по id)
        addSig(_sigData(e.value), e.key);
      }
      for (final group in sigGroups.values) {
        if (group.length < 2) continue;
        final ids = group.toList()..sort();
        final survivor = ids.first;
        for (final dupId in ids.skip(1)) {
          // ХАРД-трий облачния дубъл. Дедупликацията е детерминирана
          // (survivor = min id из обединението) → всички устройства махат
          // СЪЩИТЕ дубли и пазят СЪЩИЯ survivor → няма възкръсване. Без
          // tombstone маркери → облакът остава чист (важно при хиляди дубли).
          if (cloudDocs.containsKey(dupId)) {
            await tasksRef.doc(dupId).delete();
            cloudDocs.remove(dupId);
          }
          final localDup = localById[dupId];
          if (localDup != null) {
            await NotificationService().cancelForTask(localDup);
            if (localDup.isInBox) await localDup.delete();
            localById.remove(dupId);
            deletedLocally++;
          }
        }
        // Ако оцелелият е само в облака → свали го веднъж (запазва cloud id).
        if (!localById.containsKey(survivor) &&
            cloudDocs.containsKey(survivor)) {
          final t = _taskFromCloud(cloudDocs[survivor]!);
          if (t.id == survivor) {
            await taskBox.add(t);
            await _rescheduleNotifs(t);
            localById[survivor] = t;
            downloaded++;
          }
        }
      }
      // Презареди tombstones (pre-B добави нови) за коректна реконсилация долу.
      localTombstones = _tomb.all();
      // Сигнатури на текущите локални задачи — защита да не създаваме нов дубъл.
      final localSigToId = <String, String>{
        for (final t in localById.values) _sigTask(t): t.id!
      };

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
          // Защита: ако вече има локална задача със същото съдържание (различен
          // id), НЕ сваляме нов дубъл — pre-B ще е tombstone-нал този id.
          final sig = _sigData(data);
          if (sig != null && localSigToId.containsKey(sig)) {
            continue;
          }
          // Само в облака → свали локално.
          final t = _taskFromCloud(data);
          await taskBox.add(t);
          await _rescheduleNotifs(t);
          localById[cid] = t;
          if (sig != null) localSigToId[sig] = t.id!;
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
      _lastSyncMs = DateTime.now().millisecondsSinceEpoch;
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

  /// Сигнатура по съдържание — за съпоставяне на дубли с различни id (вкл.
  /// между устройства и от стария „огледален" облак). Нарочно проста и стабилна:
  /// заглавие + точен срок + категория. Изчислява се ЕДНАКВО на всички устройства.
  String _sig(String title, DateTime due, String categoryId) =>
      '${title.trim().toLowerCase()}|${due.millisecondsSinceEpoch}|$categoryId';

  String _sigTask(Task t) => _sig(t.title, t.dueDate, t.categoryId);

  String? _sigData(Map<String, dynamic> d) {
    final title = d['title'] as String?;
    final dueStr = d['dueDate'] as String?;
    final cat = d['categoryId'] as String?;
    if (title == null || dueStr == null || cat == null) return null;
    final due = DateTime.tryParse(dueStr);
    if (due == null) return null;
    return _sig(title, due, cat);
  }

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

  /// АВТОРИТЕТНО НУЛИРАНЕ: трие ВСИЧКИ задачи от облака (на партиди) + локалната
  /// кутия + tombstones. За възстановяване начисто (после Import от iPhone JSON).
  /// Пауза на синхрона по време на операцията.
  Future<int> wipeAllTasks() async {
    _syncInProgress = true;
    _applyingRemote = true;
    int n = 0;
    try {
      final ref = _tasksRef;
      if (ref != null) {
        // Изтрий на партиди (Firestore batch е до 500).
        while (true) {
          final snap = await ref.limit(400).get();
          if (snap.docs.isEmpty) break;
          final batch = _db.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
            n++;
          }
          await batch.commit();
          if (snap.docs.length < 400) break;
        }
      }
      await Hive.box<Task>('tasks').clear();
      await Hive.box<int>(TombstoneService.boxName).clear();
    } finally {
      _applyingRemote = false;
      _syncInProgress = false;
      _lastSyncMs = DateTime.now().millisecondsSinceEpoch;
    }
    return n;
  }

  void dispose() {
    _debounce?.cancel();
    _boxSub?.cancel();
  }
}
