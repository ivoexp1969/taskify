import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/group.dart';
import 'auth_service.dart';
import 'group_service.dart';
import 'notification_service.dart';

/// Планира ЛОКАЛНИ напомняния за груповите задачи (v1.0.72, точка 3).
///
/// Защо локално: груповите задачи живеят само във Firestore и в проекта НЯМА
/// FCM/сървърен push (бъдеща задача — виж DEVLOG). Затова всяко устройство
/// слуша своите групи на живо и планира напомнянията, които го засягат:
///   • по подразбиране — само ако `reminderSetBy == моя uid`;
///   • ако `remindAll == true` — на всички членове (вкл. мен).
///
/// Ограничение: устройство, което не е отваряло приложението, няма планирани
/// напомняния (локалните нотификации изискват app-ът да е стартирал).
///
/// Singleton като другите услуги. `start()` е идемпотентен; преслушва при
/// вход/изход (auth), защото `GroupService.watchMyGroups` фиксира uid при
/// абониране.
class GroupReminderScheduler {
  GroupReminderScheduler._internal();
  static final GroupReminderScheduler _instance =
      GroupReminderScheduler._internal();
  factory GroupReminderScheduler() => _instance;

  final GroupService _service = GroupService();
  final AuthService _auth = AuthService();

  StreamSubscription<List<Group>>? _groupsSub;
  final Map<String, StreamSubscription<List<GroupTask>>> _taskSubs = {};

  /// Планирани notif id-та по ключ '<groupId>|<taskId>' — за чистене на остарели.
  final Map<String, List<int>> _scheduled = {};

  bool _started = false;

  void start() {
    if (kIsWeb || _started) return;
    _started = true;
    // Преслушваме при вход/изход (watchMyGroups фиксира uid при абониране).
    // Singleton за целия живот на app-а → не пазим subscription за отмяна.
    _auth.authStateChanges.listen((_) => _resubscribe());
    _resubscribe();
  }

  void _resubscribe() {
    _groupsSub?.cancel();
    for (final s in _taskSubs.values) {
      s.cancel();
    }
    _taskSubs.clear();
    // Отмени всички планирани групови напомняния (вход на друг акаунт/изход).
    for (final ids in _scheduled.values) {
      NotificationService().cancelIds(ids);
    }
    _scheduled.clear();

    if (_auth.currentUser == null) return;
    _groupsSub = _service.watchMyGroups().listen(_onGroups);
  }

  void _onGroups(List<Group> groups) {
    final ids = groups.map((g) => g.id).toSet();

    // Групи, в които вече не сме → спри listener-а + отмени техните напомняния.
    final goneGroups =
        _taskSubs.keys.where((gid) => !ids.contains(gid)).toList();
    for (final gid in goneGroups) {
      _taskSubs.remove(gid)?.cancel();
      final goneKeys =
          _scheduled.keys.where((k) => k.startsWith('$gid|')).toList();
      for (final k in goneKeys) {
        NotificationService().cancelIds(_scheduled.remove(k) ?? const []);
      }
    }

    for (final g in groups) {
      if (!_taskSubs.containsKey(g.id)) {
        _taskSubs[g.id] =
            _service.watchTasks(g.id).listen((tasks) => _onTasks(g, tasks));
      }
    }
  }

  Future<void> _onTasks(Group g, List<GroupTask> tasks) async {
    final uid = _auth.currentUser?.uid;
    final liveKeys = <String>{};

    for (final gt in tasks) {
      final hasReminders = gt.reminders != null && gt.reminders!.isNotEmpty;
      final affectsMe = gt.remindAll || gt.reminderSetBy == uid;
      if (gt.isCompleted || !hasReminders || !affectsMe) continue;

      final key = '${g.id}|${gt.id}';
      liveKeys.add(key);

      // Препланираме (отмени старите id-та → планирай наново) — покрива промяна
      // на дата/напомняния. Id-тата са детерминирани, така че дубъл няма.
      final prev = _scheduled[key];
      if (prev != null) await NotificationService().cancelIds(prev);

      final idBase = key.hashCode & 0x7FFFFFFF;
      final newIds = await NotificationService().scheduleGroupReminders(
        idBase: idBase,
        title: gt.title,
        body: g.name,
        dueDate: gt.dueDate,
        reminders: gt.reminders!,
      );
      _scheduled[key] = newIds;
    }

    // Задачи от ТАЗИ група, които вече не са активни (завършени/изтрити/вече не
    // ме засягат) → отмени напомнянията им.
    final staleKeys = _scheduled.keys
        .where((k) => k.startsWith('${g.id}|') && !liveKeys.contains(k))
        .toList();
    for (final k in staleKeys) {
      await NotificationService().cancelIds(_scheduled.remove(k) ?? const []);
    }
  }
}
