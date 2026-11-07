import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/task.dart';
import '../models/group.dart';
import '../models/category.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../services/tombstone_service.dart';
import '../services/notification_service.dart';
import '../screens/auth/login_screen.dart';
import '../utils/localization.dart';
import '../utils/uuid.dart';

/// „Премести в група" (v1.0.72, точка 2) — ПРЕМЕСТВАНЕ (не копие) на лична
/// задача в споделена група. Личната се трие (tombstone) САМО след сървърно
/// потвърждение на записа в групата. Офлайн → нищо не се пипа.
class MoveToGroupSheet {
  /// Връща true, ако задачата е преместена (викащият да опресни списъка).
  static Future<bool> show(BuildContext context, Task task) async {
    final moved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MoveToGroupSheet(task: task),
    );
    return moved ?? false;
  }

  /// Единна входна точка за „Сподели" от ВСИЧКИ места (карта, редактор, long-press,
  /// shopping екран). Ако потребителят НЕ е влязъл (или е анонимен) → показва диалог
  /// „Влез, за да споделяш задачи" (опцията НЕ се крие — изискване 1.0.71), с път до
  /// `LoginScreen`. Ако е влязъл → отваря избора на група. Вика [onMoved] при успех.
  static Future<void> start(BuildContext context, Task task,
      {VoidCallback? onMoved}) async {
    final t = AppText.of(context);
    if (!AuthService().isLoggedIn) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.shareLoginTitle),
          content: Text(t.shareLoginBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.login)),
          ],
        ),
      );
      if (go == true && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }
    final moved = await show(context, task);
    if (moved) onMoved?.call();
  }

  /// Готов „Сподели" бутон за header-а на шаблонните диалози (рожден ден, среща,
  /// плащане, …). При тап затваря [sheetContext] (диалога) и стартира споделянето
  /// върху [outerContext] (който преживява затварянето). Показвай го само при
  /// редакция на СЪЩЕСТВУВАЩА задача.
  static Widget headerIconButton({
    required BuildContext sheetContext,
    required BuildContext outerContext,
    required Task task,
    Color? color,
    VoidCallback? onMoved,
  }) {
    final t = AppText.of(sheetContext);
    return IconButton(
      tooltip: t.shareTask,
      icon: Icon(Icons.group_add_rounded, color: color),
      onPressed: () {
        Navigator.of(sheetContext).maybePop();
        start(outerContext, task, onMoved: onMoved);
      },
    );
  }
}

class _MoveToGroupSheet extends StatefulWidget {
  final Task task;
  const _MoveToGroupSheet({required this.task});

  @override
  State<_MoveToGroupSheet> createState() => _MoveToGroupSheetState();
}

class _MoveToGroupSheetState extends State<_MoveToGroupSheet> {
  final GroupService _service = GroupService();
  bool _busy = false;

  String? _categoryName() {
    if (!Hive.isBoxOpen('categories')) return null;
    for (final c in Hive.box<Category>('categories').values) {
      if (c.id == widget.task.categoryId) {
        final n = c.name.trim();
        return n.isEmpty ? null : n;
      }
    }
    return null;
  }

  GroupTask _buildGroupTask() {
    final task = widget.task;
    final uid = AuthService().currentUser?.uid;
    final reminders = task.remindersList;
    final isShopping =
        task.categoryId == 'shopping' || task.template == 'shopping';

    List<ShoppingItem>? items;
    if (isShopping) {
      items = <ShoppingItem>[];
      final subs = task.subtasksList; // [{done, qty, text}]
      for (var i = 0; i < subs.length; i++) {
        final text = (subs[i]['text'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        items.add(ShoppingItem(
          id: Uuid.v4(),
          text: text,
          checked: subs[i]['done'] == true,
          qty: (subs[i]['qty'] as int?) ?? 1,
          order: i,
        ));
      }
    }

    return GroupTask(
      id: '',
      title: task.title,
      dueDate: task.dueDate,
      categoryName: _categoryName(),
      priority: task.priority,
      recurrence: null, // групите не поддържат повторение (предупреждение в диалога)
      reminders: reminders.isEmpty ? null : reminders,
      subtasks: isShopping ? null : task.subtasks,
      notes: task.notes,
      isCompleted: task.isCompleted,
      template: isShopping ? 'shopping' : null,
      items: items,
      reminderSetBy: reminders.isEmpty ? null : uid,
      remindAll: false,
    );
  }

  Future<void> _confirmAndMove(Group g) async {
    final t = AppText.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.moveToGroup),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.moveToGroupConfirm(g.name)),
            if (widget.task.recurrence != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.moveToGroupRecurringWarn)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(t.move)),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _busy = true);

    // 1) Увери се, че наистина сме онлайн (server-source read хвърля при офлайн).
    //    Личната задача НЕ се пипа, докато няма сървърно потвърждение.
    try {
      await _service
          .pingServerForGroup(g.id)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(t.moveNeedsInternet)));
      return;
    }

    // 2) Запиши в групата и ИЗЧАКАЙ сървърно потвърждение (add Future resolve-ва
    //    чак при ack). Чак тогава трием личната задача.
    try {
      await _service
          .addTask(g.id, _buildGroupTask())
          .timeout(const Duration(seconds: 15));
    } on GroupException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e.code == 'task-limit' ? t.groupErrTaskLimit : t.moveFailed;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(t.moveFailed)));
      return;
    }

    // 3) Потвърдено → махни локалните нотификации и трий ЛИЧНАТА задача през
    //    tombstone (иначе merge sync я възкресява).
    try {
      await NotificationService().cancelForTask(widget.task);
      await TombstoneService().deleteTask(widget.task);
    } catch (_) {/* груповото копие вече е записано; не блокирай */}

    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(t.movedToGroup(g.name))));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(t.selectGroup,
                  style: theme.textTheme.titleMedium),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              StreamBuilder<List<Group>>(
                stream: _service.watchMyGroups(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final groups = snap.data ?? const <Group>[];
                  if (groups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Text(
                        t.moveNoGroups,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    );
                  }
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            child: Icon(Icons.groups_rounded,
                                color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(g.name),
                          subtitle: Text(t.membersCount(g.memberCount)),
                          onTap: () => _confirmAndMove(g),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
