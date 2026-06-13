import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/group.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../utils/localization.dart';
import '../../widgets/task_card_styles.dart';
import '../../utils/category_colors.dart';
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

  String _recurrenceLabel(String? r, AppText t) {
    switch (r) {
      case 'daily':
        return t.daily;
      case 'weekly':
        return t.weekly;
      case 'monthly':
        return t.monthly;
      case 'yearly':
        return t.yearly;
      default:
        return t.noRepeat;
    }
  }

  /// Подзадачите се пазят като "done:text" (0/1). Парсва за редакция.
  List<Map<String, dynamic>> _parseSubtasks(List<String>? raw) {
    if (raw == null) return [];
    return raw.map((s) {
      final parts = s.split(':');
      final done = parts.isNotEmpty && parts.first == '1';
      final text = parts.length >= 3
          ? parts.sublist(2).join(':')
          : (parts.length == 2 ? parts[1] : '');
      return {'done': done, 'text': text};
    }).toList();
  }

  List<String>? _serializeSubtasks(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return null;
    return list
        .where((m) => (m['text'] as String).trim().isNotEmpty)
        .map((m) => '${m['done'] == true ? '1' : '0'}:${(m['text'] as String).trim()}')
        .toList();
  }

  Future<void> _addOrEditTask({GroupTask? existing}) async {
    final t = AppText.of(context);
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final categoryCtrl = TextEditingController(text: existing?.categoryName ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final subtaskCtrl = TextEditingController();
    int priority = existing?.priority ?? 1;
    DateTime due = existing?.dueDate ?? DateTime.now();
    String? recurrence = existing?.recurrence;
    final subtasks = _parseSubtasks(existing?.subtasks);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? t.groupAddTask : t.edit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: t.groupTaskHint),
                ),
                const SizedBox(height: 16),
                // Приоритет
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var p = 0; p <= 2; p++)
                      ChoiceChip(
                        label: Text(_priorityLabel(p, t)),
                        selected: priority == p,
                        selectedColor:
                            _priorityColor(p).withValues(alpha: 0.25),
                        onSelected: (_) => setLocal(() => priority = p),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Срок
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(_dateStr(due)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: due,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && ctx.mounted) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(due),
                      );
                      setLocal(() => due = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time?.hour ?? 0,
                            time?.minute ?? 0,
                          ));
                    }
                  },
                ),
                const SizedBox(height: 8),
                // Повторение
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.repeat,
                      style: Theme.of(ctx).textTheme.labelMedium),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final r in const [
                      null,
                      'daily',
                      'weekly',
                      'monthly',
                      'yearly'
                    ])
                      ChoiceChip(
                        label: Text(_recurrenceLabel(r, t)),
                        selected: recurrence == r,
                        onSelected: (_) => setLocal(() => recurrence = r),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Категория (текст — личните категории не се споделят)
                TextField(
                  controller: categoryCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t.category,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Подзадачи
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.subtasks,
                      style: Theme.of(ctx).textTheme.labelMedium),
                ),
                for (var i = 0; i < subtasks.length; i++)
                  Row(
                    children: [
                      Checkbox(
                        value: subtasks[i]['done'] == true,
                        onChanged: (v) =>
                            setLocal(() => subtasks[i]['done'] = v ?? false),
                      ),
                      Expanded(child: Text(subtasks[i]['text'] as String)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setLocal(() => subtasks.removeAt(i)),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: subtaskCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: t.newSubtask,
                          isDense: true,
                        ),
                        onSubmitted: (_) {
                          final txt = subtaskCtrl.text.trim();
                          if (txt.isEmpty) return;
                          setLocal(() {
                            subtasks.add({'done': false, 'text': txt});
                            subtaskCtrl.clear();
                          });
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: t.addSubtask,
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final txt = subtaskCtrl.text.trim();
                        if (txt.isEmpty) return;
                        setLocal(() {
                          subtasks.add({'done': false, 'text': txt});
                          subtaskCtrl.clear();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Бележки
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t.notes,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.save),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    final gt = GroupTask(
      id: existing?.id ?? '',
      title: title,
      dueDate: due,
      priority: priority,
      categoryName:
          categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
      recurrence: recurrence,
      reminders: existing?.reminders,
      subtasks: _serializeSubtasks(subtasks),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
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
