import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/group.dart';
import '../models/category.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../utils/localization.dart';
import '../utils/subtask_format.dart';
import '../utils/category_colors.dart';
import '../widgets/task_card_styles.dart';
import '../screens/shared/group_tasks_screen.dart';

/// Обособена секция „Споделени" в основния списък със задачи (таб Задачи).
///
/// Показва днешните + просрочените НЕЗАВЪРШЕНИ (и завършените ДНЕС) групови
/// задачи от ВСИЧКИ групи наведнъж, всяка с етикет коя е групата. Данните са
/// от Firestore (`GroupService`) — real-time: появяват се на живо, когато друг
/// член добави/завърши задача.
///
/// ★Моделите остават разделени★: това НЕ пипа личните `Task` (Hive) — има свой
/// източник (`GroupTask`), рендира ги само визуално със същите карти. Секцията
/// се скрива изцяло, ако потребителят няма групи или няма задачи за деня.
class SharedTasksSection extends StatefulWidget {
  const SharedTasksSection({super.key});

  @override
  State<SharedTasksSection> createState() => _SharedTasksSectionState();
}

class _SharedTasksSectionState extends State<SharedTasksSection> {
  final GroupService _service = GroupService();

  StreamSubscription<List<Group>>? _groupsSub;
  // По един listener на група — управляваме ги ръчно (combineLatest), за да
  // няма изтичане/дубликати при rebuild.
  final Map<String, StreamSubscription<List<GroupTask>>> _taskSubs = {};
  final Map<String, Group> _groups = {};
  final Map<String, List<GroupTask>> _tasksByGroup = {};

  final Set<String> _expanded = <String>{};
  StreamSubscription<BoxEvent>? _catSub;

  @override
  void initState() {
    super.initState();
    _groupsSub = _service.watchMyGroups().listen(_syncGroups);
    // Прецветяване при промяна на потребителските категории.
    if (Hive.isBoxOpen('categories')) {
      _catSub = Hive.box<Category>('categories').watch().listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    for (final s in _taskSubs.values) {
      s.cancel();
    }
    _taskSubs.clear();
    _catSub?.cancel();
    super.dispose();
  }

  /// Синхронизира per-group listener-ите с текущия списък групи: добавя нови,
  /// маха напусналите (отменя subscription-а им), обновява метаданните.
  void _syncGroups(List<Group> groups) {
    final ids = groups.map((g) => g.id).toSet();

    // Махни listener-и за групи, в които вече не сме.
    final removed = _taskSubs.keys.where((id) => !ids.contains(id)).toList();
    for (final id in removed) {
      _taskSubs.remove(id)?.cancel();
      _groups.remove(id);
      _tasksByGroup.remove(id);
    }

    for (final g in groups) {
      _groups[g.id] = g;
      if (!_taskSubs.containsKey(g.id)) {
        _taskSubs[g.id] = _service.watchTasks(g.id).listen((tasks) {
          _tasksByGroup[g.id] = tasks;
          if (mounted) setState(() {});
        });
      }
    }
    if (mounted) setState(() {});
  }

  // ── Обхват: днешни + просрочени незавършени (+ завършени ДНЕС) ──────────────
  bool _inWindow(GroupTask gt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!gt.isCompleted) {
      final due = DateTime(gt.dueDate.year, gt.dueDate.month, gt.dueDate.day);
      return !due.isAfter(today); // днес или просрочена
    }
    // Завършена → показвай само ако е завършена днес (за „завършена от X").
    final ca = gt.completedAt;
    if (ca == null) return false;
    return DateTime(ca.year, ca.month, ca.day) == today;
  }

  // ── Категория/цвят (компактни версии от group_tasks_screen) ────────────────
  List<Category> get _cats => Hive.isBoxOpen('categories')
      ? Hive.box<Category>('categories').values.toList()
      : const <Category>[];

  Category? _categoryFor(GroupTask gt) {
    final name = gt.categoryName?.trim();
    if (name == null || name.isEmpty) return null;
    final low = name.toLowerCase();
    for (final c in _cats) {
      if (c.name.toLowerCase() == low) return c;
    }
    return null;
  }

  String _localizedCategoryName(Category? c, AppText t) {
    if (c == null) return '';
    if (c.id == 'cal_events') return t.catCalendarEvents;
    if (c.id == 'documents') return t.catDocuments;
    if (c.isDefault) {
      return {
            'work': t.catWork,
            'personal': t.catPersonal,
            'shopping': t.catShopping,
            'birthday': t.catBirthdays,
            'meeting': t.catMeeting,
            'workout': t.catWorkout,
            'payment': t.catPayment,
            'travel': t.catTravel,
            'gift': t.catGift,
          }[c.id] ??
          c.name;
    }
    return c.name;
  }

  String _categoryDisplay(GroupTask gt, AppText t) {
    final c = _categoryFor(gt);
    return c != null ? _localizedCategoryName(c, t) : (gt.categoryName ?? '');
  }

  Color _accentFor(GroupTask gt) {
    final c = _categoryFor(gt);
    if (c != null) return Color(c.colorValue);
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
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final dateStr = '$day.$month.${d.year}';
    final hasTime = d.hour != 0 || d.minute != 0;
    if (!hasTime) return dateStr;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$dateStr · $h:$m';
  }

  // ── Действия (записват във Firestore през GroupService) ────────────────────
  void _notAuthor(AppText t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t.onlyAuthorCanManage)));

  Future<void> _toggleSubtask(Group g, GroupTask gt, int index) async {
    final subs = List<String>.from(gt.subtasks ?? const <String>[]);
    if (index < 0 || index >= subs.length) return;
    final p = SubtaskCodec.parse(subs[index]);
    subs[index] = SubtaskCodec.format(
      done: !(p['done'] as bool),
      qty: p['qty'] as int,
      text: p['text'] as String,
    );
    final updated = GroupTask(
      id: gt.id,
      title: gt.title,
      dueDate: gt.dueDate,
      categoryName: gt.categoryName,
      priority: gt.priority,
      recurrence: gt.recurrence,
      reminders: gt.reminders,
      subtasks: subs,
      notes: gt.notes,
      isCompleted: gt.isCompleted,
    );
    try {
      await _service.updateTask(g.id, gt.id, updated);
    } catch (_) {/* snapshot-ите ще коригират UI */}
  }

  void _openGroup(Group g) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupTasksScreen(group: g)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final uid = AuthService().currentUser?.uid ?? '';

    // Събери всички подходящи задачи от всички групи (с групата им за етикета).
    final entries = <({Group group, GroupTask task})>[];
    for (final g in _groups.values) {
      for (final gt in (_tasksByGroup[g.id] ?? const <GroupTask>[])) {
        if (_inWindow(gt)) entries.add((group: g, task: gt));
      }
    }
    // Няма групи / няма задачи за деня → нула визуален шум.
    if (entries.isEmpty) return const SizedBox.shrink();

    // Незавършени първи, после по срок; после по група.
    entries.sort((a, b) {
      if (a.task.isCompleted != b.task.isCompleted) {
        return a.task.isCompleted ? 1 : -1;
      }
      final d = a.task.dueDate.compareTo(b.task.dueDate);
      if (d != 0) return d;
      return a.group.name.toLowerCase().compareTo(b.group.name.toLowerCase());
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Row(
              children: [
                Icon(Icons.groups_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(t.sharedTab,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: theme.colorScheme.primary)),
                const SizedBox(width: 6),
                Text('· ${entries.length}',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          for (final e in entries) _tile(t, theme, uid, e.group, e.task),
        ],
      ),
    );
  }

  Widget _tile(
      AppText t, ThemeData theme, String uid, Group g, GroupTask gt) {
    final isOverdue = !gt.isCompleted && gt.dueDate.isBefore(DateTime.now());
    final isAuthor = gt.createdBy == null || gt.createdBy == uid;
    final completer =
        gt.completedBy != null ? g.memberFor(gt.completedBy!).displayName : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Етикет коя е групата.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  g.name,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        TaskCardView(
          task: gt.toDisplayTask(),
          isOverdue: isOverdue,
          isCompleted: gt.isCompleted,
          isExpanded: _expanded.contains(gt.id),
          accentColor: _accentFor(gt),
          priorityColor: _priorityColor(gt.priority),
          priorityText: _priorityLabel(gt.priority, t),
          dateTimeStr: _dateStr(gt.dueDate),
          categoryName: _categoryDisplay(gt, t),
          onToggleExpand: () => setState(() {
            if (_expanded.contains(gt.id)) {
              _expanded.remove(gt.id);
            } else {
              _expanded.add(gt.id);
            }
          }),
          onToggleComplete: () => isAuthor
              ? _service.toggleComplete(g.id, gt.id, !gt.isCompleted)
              : _notAuthor(t),
          // Отваряне/редакция → пълния контекст на груповата задача (НЕ личния
          // редактор), както изисква спецификацията.
          onEdit: () => _openGroup(g),
          onBreakdown: () => _openGroup(g),
          onToggleSubtask: (index) =>
              isAuthor ? _toggleSubtask(g, gt, index) : _notAuthor(t),
          onDelete: () => isAuthor
              ? _service.deleteTask(g.id, gt.id)
              : _notAuthor(t),
        ),
        if (gt.isCompleted && completer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    size: 13,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  t.completedByName(completer),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
