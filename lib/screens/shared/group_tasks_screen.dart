import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../models/group.dart';
import '../../models/category.dart';
import '../../models/task.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../utils/localization.dart';
import '../../widgets/task_card_styles.dart';
import '../../utils/category_colors.dart';
import '../task/task_screen.dart';
import 'group_invite_screen.dart';

/// Екран със задачите на ЕДНА споделена група. Real-time (Firestore snapshots):
/// промените от другите членове идват на живо без ръчен рефреш.
class GroupTasksScreen extends StatefulWidget {
  final Group group;
  const GroupTasksScreen({super.key, required this.group});

  @override
  State<GroupTasksScreen> createState() => _GroupTasksScreenState();
}

class _GroupTasksScreenState extends State<GroupTasksScreen> {
  final GroupService _service = GroupService();
  final Set<String> _expanded = <String>{};

  // Държим последно полученото състояние на групата (членове/owner) на живо.
  late Group _group = widget.group;

  /// Наситен акцент за груповата карта. Категориите са текст (без цвят), затова
  /// извеждаме стабилен цвят от името по споделената палитра; без категория → по приоритет.
  Color _accentFor(GroupTask gt) {
    final name = gt.categoryName?.trim() ?? '';
    if (name.isEmpty) return _priorityColor(gt.priority);
    final idx = name.toLowerCase().hashCode.abs() % kCategoryColors.length;
    return kCategoryColors[idx];
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 2:
        return Colors.redAccent;
      case 0:
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _priorityLabel(int p, AppText t) {
    switch (p) {
      case 2:
        return t.high;
      case 0:
        return t.low;
      default:
        return t.medium;
    }
  }

  String _dateStr(DateTime d) {
    final now = DateTime.now();
    final sameYear = d.year == now.year;
    final fmt = sameYear ? DateFormat.MMMd() : DateFormat.yMMMd();
    final hasTime = d.hour != 0 || d.minute != 0;
    return hasTime
        ? '${fmt.format(d)} · ${DateFormat.Hm().format(d)}'
        : fmt.format(d);
  }

  Future<void> _showError(GroupException e) async {
    if (!mounted) return;
    final t = AppText.of(context);
    final msg = switch (e.code) {
      'owner-limit' => t.groupErrOwnerLimit,
      'member-limit' => t.groupErrMemberLimit,
      'task-limit' => t.groupErrTaskLimit,
      'invalid-code' => t.groupErrInvalidCode,
      _ => t.groupErrGeneric,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addOrEditTask({GroupTask? existing}) async {
    // Отваряме ТОЧНО СЪЩИЯ редактор като таб „Задачи" (TaskEditorBridge), но
    // запазваме във Firestore (GroupTask), не в Hive.
    if (!TaskEditorBridge.isReady) return;

    final cats = Hive.isBoxOpen('categories')
        ? Hive.box<Category>('categories').values.toList()
        : <Category>[];

    // Груповата задача пази категорията като ИМЕ (текст) → мапваме към/от личните.
    String catIdFor(String? name) {
      if (name == null || name.trim().isEmpty) return 'personal';
      final low = name.toLowerCase();
      final m = cats.where((c) => c.name.toLowerCase() == low);
      return m.isNotEmpty ? m.first.id : 'personal';
    }

    String? nameForCatId(String id) {
      final m = cats.where((c) => c.id == id);
      if (m.isEmpty) return null;
      final n = m.first.name.trim();
      return n.isEmpty ? null : n;
    }

    // За EDIT подаваме draft с попълнени полета; за NEW → null (редакторът показва „Нова задача").
    Task? draft;
    if (existing != null) {
      draft = Task(
        title: existing.title,
        dueDate: existing.dueDate,
        categoryId: catIdFor(existing.categoryName),
        priority: existing.priority,
        recurrence: existing.recurrence,
        reminders: existing.reminders,
        subtasks: existing.subtasks,
        notes: existing.notes,
      );
    }

    await TaskEditorBridge.open(
      existing: draft,
      onSave: (task) async {
        final gt = GroupTask(
          id: existing?.id ?? '',
          title: task.title,
          dueDate: task.dueDate,
          priority: task.priority,
          categoryName: nameForCatId(task.categoryId),
          recurrence: task.recurrence,
          reminders: task.reminders,
          subtasks: task.subtasks,
          notes: task.notes,
          isCompleted: existing?.isCompleted ?? false,
        );
        try {
          if (existing == null) {
            await _service.addTask(_group.id, gt);
          } else {
            await _service.updateTask(_group.id, existing.id, gt);
          }
        } on GroupException catch (e) {
          await _showError(e);
        } catch (_) {
          await _showError(GroupException('generic'));
        }
      },
    );
  }

  Future<void> _confirmLeaveOrDelete() async {
    final t = AppText.of(context);
    final uid = AuthService().currentUser?.uid ?? '';
    final isOwner = _group.isOwner(uid);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOwner ? t.deleteGroup : t.leaveGroup),
        content: Text(isOwner ? t.deleteGroupConfirm : t.leaveGroupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isOwner ? Colors.red : null,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isOwner ? t.deleteGroup : t.leaveGroup),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (isOwner) {
        await _service.deleteGroup(_group.id);
      } else {
        await _service.leaveGroup(_group.id);
      }
      if (mounted) Navigator.of(context).pop();
    } on GroupException catch (e) {
      await _showError(e);
    } catch (_) {
      await _showError(GroupException('generic'));
    }
  }

  void _showMembers() {
    final t = AppText.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(t.members,
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
            for (final m in _group.sortedMembers)
              ListTile(
                leading: CircleAvatar(child: Text(m.initials)),
                title: Text(m.displayName),
                subtitle: m.email != null ? Text(m.email!) : null,
                trailing: m.uid == _group.ownerId
                    ? Chip(label: Text(t.ownerLabel))
                    : null,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final uid = AuthService().currentUser?.uid ?? '';

    return StreamBuilder<Group?>(
      stream: _service.watchGroup(_group.id),
      builder: (context, groupSnap) {
        // Групата може да е изтрита (от owner на друго устройство) → излез.
        if (groupSnap.hasData && groupSnap.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        }
        if (groupSnap.data != null) _group = groupSnap.data!;
        final isOwner = _group.isOwner(uid);

        return Scaffold(
          appBar: AppBar(
            title: Text(_group.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'invite':
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupInviteScreen(group: _group),
                        ),
                      );
                    case 'members':
                      _showMembers();
                    case 'leave':
                      _confirmLeaveOrDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'invite',
                    child: Text(t.inviteTitle),
                  ),
                  PopupMenuItem(
                    value: 'members',
                    child: Text('${t.members} · ${_group.memberCount}'),
                  ),
                  PopupMenuItem(
                    value: 'leave',
                    child: Text(
                      isOwner ? t.deleteGroup : t.leaveGroup,
                      style: TextStyle(
                          color: isOwner ? Colors.red : null),
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addOrEditTask(),
            child: const Icon(Icons.add),
          ),
          body: StreamBuilder<List<GroupTask>>(
            stream: _service.watchTasks(_group.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tasks = snap.data ?? const <GroupTask>[];
              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      t.groupTasksEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 96),
                itemCount: tasks.length,
                itemBuilder: (context, i) {
                  final gt = tasks[i];
                  final isOverdue = !gt.isCompleted &&
                      gt.dueDate.isBefore(DateTime.now());
                  final completer = gt.completedBy != null
                      ? _group.memberFor(gt.completedBy!).displayName
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TaskCardView(
                        task: gt.toDisplayTask(),
                        isOverdue: isOverdue,
                        isCompleted: gt.isCompleted,
                        isExpanded: _expanded.contains(gt.id),
                        accentColor: _accentFor(gt),
                        priorityColor: _priorityColor(gt.priority),
                        priorityText: _priorityLabel(gt.priority, t),
                        dateTimeStr: _dateStr(gt.dueDate),
                        categoryName: gt.categoryName ?? '',
                        onToggleExpand: () => setState(() {
                          if (_expanded.contains(gt.id)) {
                            _expanded.remove(gt.id);
                          } else {
                            _expanded.add(gt.id);
                          }
                        }),
                        onToggleComplete: () => _service.toggleComplete(
                            _group.id, gt.id, !gt.isCompleted),
                        onEdit: () => _addOrEditTask(existing: gt),
                        onDelete: () =>
                            _service.deleteTask(_group.id, gt.id),
                      ),
                      if (gt.isCompleted && completer != null)
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 6),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 13,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(
                                t.completedByName(completer),
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
