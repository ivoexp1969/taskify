import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../models/group.dart';
import '../../models/category.dart';
import '../../models/task.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/pro_service.dart';
import '../../services/analytics_service.dart';
import '../../services/ai_service.dart';
import '../../services/ai_usage_service.dart';
import '../../utils/localization.dart';
import '../../utils/subtask_format.dart';
import '../../widgets/task_card_styles.dart';
import '../../utils/category_colors.dart';
import '../../widgets/ai_limit.dart';
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

  // Слуша за промени в потребителските категории (цвят/име) → груповите карти
  // се преоцветяват веднага при редакция в „Управление на категории".
  StreamSubscription<BoxEvent>? _catSub;

  @override
  void initState() {
    super.initState();
    if (Hive.isBoxOpen('categories')) {
      _catSub = Hive.box<Category>('categories').watch().listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _catSub?.cancel();
    super.dispose();
  }

  /// Живите потребителски категории (за резолване на реален цвят + локализирано име).
  List<Category> get _cats => Hive.isBoxOpen('categories')
      ? Hive.box<Category>('categories').values.toList()
      : const <Category>[];

  /// Намира потребителската категория, чието ИМЕ съвпада със запазеното (текст).
  Category? _categoryFor(GroupTask gt) {
    final name = gt.categoryName?.trim();
    if (name == null || name.isEmpty) return null;
    final low = name.toLowerCase();
    for (final c in _cats) {
      if (c.name.toLowerCase() == low) return c;
    }
    return null;
  }

  /// Локализирано име на категория (вградените по id; потребителските — по име).
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

  /// Името на категорията за показване: реалната локализирана, ако я има при
  /// потребителя; иначе суровия запазен текст (категория от друг член).
  String _categoryDisplay(GroupTask gt, AppText t) {
    final c = _categoryFor(gt);
    return c != null ? _localizedCategoryName(c, t) : (gt.categoryName ?? '');
  }

  /// Наситен акцент за груповата карта. Ползваме РЕАЛНИЯ цвят на категорията от
  /// потребителските категории (реагира на промяна в „Управление на категории").
  /// За категория от друг член (липсва локално) → стабилен цвят по име от
  /// палитрата; без категория → по приоритет.
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
    // Числов формат като личния екран/календара (dd.MM.yyyy · HH:mm) — езиково
    // неутрален, за да няма английски имена на месеци сред друг език.
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final dateStr = '$day.$month.${d.year}';
    final hasTime = d.hour != 0 || d.minute != 0;
    if (!hasTime) return dateStr;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$dateStr · $h:$m';
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

  /// AI „Разбий на стъпки" за СПОДЕЛЕНА задача — като личните карти, но записва
  /// във Firestore (GroupTask), не в Hive. Показва се само при 0 подзадачи.
  Future<void> _breakdown(GroupTask gt) async {
    final t = AppText.of(context);
    // ФАЗА 2: freemium — free до 3/ден (споделен пул), Pro неограничено.
    if (!ProService().isPro && !await AiUsageService.instance.canUse()) {
      if (mounted) await showAiLimitSheet(context);
      return;
    }
    final lang = LanguageScope.of(context).locale.languageCode;
    final catNames = _cats.map((c) => c.name).toList();

    // Зареждащ индикатор, докато AI генерира.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final r = await AiService.breakdownTask(gt.title, catNames, lang);
    if (mounted) Navigator.of(context).pop(); // махни loader-а
    if (!mounted) return;
    if (r == null || r.subtasks.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.aiError)));
      return;
    }
    await AiUsageService.instance.recordUse();
    if (!mounted) return;

    // Преглед + потвърждение преди запис.
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.aiBreakdownTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in r.subtasks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('•  $s'),
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
            child: Text(t.aiBreakdownApply),
          ),
        ],
      ),
    );
    if (apply != true) return;

    // AI breakdown връща ЧИСТИ заглавия без префикс. Нормализираме ги към
    // каноничния формат "0:1:заглавие" (незавършени), за да ги рендира картата
    // и да работи броячът „X/Y" — точно както при личните задачи.
    final newOnes = r.subtasks
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => SubtaskCodec.format(text: s))
        .toList();
    final merged = <String>[...?gt.subtasks, ...newOnes];
    final updated = GroupTask(
      id: gt.id,
      title: gt.title,
      dueDate: gt.dueDate,
      categoryName: gt.categoryName,
      priority: gt.priority,
      recurrence: gt.recurrence,
      reminders: gt.reminders,
      subtasks: merged,
      notes: gt.notes,
      isCompleted: gt.isCompleted,
    );
    try {
      await _service.updateTask(_group.id, gt.id, updated);
    } on GroupException catch (e) {
      await _showError(e);
    } catch (_) {
      await _showError(GroupException('generic'));
    }
  }

  /// Отбелязва ЕДНА подзадача (по индекс) на групова задача като завършена/не и
  /// записва във Firestore (живо синхронизиране към другите членове). Индексът
  /// съответства на реда в `gt.subtasks` (= реда в картата).
  Future<void> _toggleSubtask(GroupTask gt, int index) async {
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
      await _service.updateTask(_group.id, gt.id, updated);
    } on GroupException catch (e) {
      await _showError(e);
    } catch (_) {
      await _showError(GroupException('generic'));
    }
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
                  // Само авторът може да завършва/редактира/трие задачата.
                  // (Стари задачи без автор → достъпни за всички, за съвместимост.)
                  final isAuthor = gt.createdBy == null || gt.createdBy == uid;
                  void notAuthor() => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.onlyAuthorCanManage)));

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
                        categoryName: _categoryDisplay(gt, t),
                        onToggleExpand: () => setState(() {
                          if (_expanded.contains(gt.id)) {
                            _expanded.remove(gt.id);
                          } else {
                            _expanded.add(gt.id);
                          }
                        }),
                        onToggleComplete: () {
                          if (!isAuthor) {
                            notAuthor();
                            return;
                          }
                          final willComplete = !gt.isCompleted;
                          _service.toggleComplete(_group.id, gt.id, willComplete);
                          if (willComplete) {
                            AnalyticsService().logTaskCompleted();
                          }
                        },
                        onBreakdown: () => _breakdown(gt),
                        onToggleSubtask: (index) => _toggleSubtask(gt, index),
                        onEdit: () =>
                            isAuthor ? _addOrEditTask(existing: gt) : notAuthor(),
                        onDelete: () => isAuthor
                            ? _service.deleteTask(_group.id, gt.id)
                            : notAuthor(),
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
