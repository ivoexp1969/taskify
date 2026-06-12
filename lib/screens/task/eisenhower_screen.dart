import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/task.dart';
import '../../utils/localization.dart';

class EisenhowerScreen extends StatelessWidget {
  const EisenhowerScreen({super.key});

  static bool _isUrgent(Task task) {
    final threshold = DateTime.now().add(const Duration(hours: 48));
    return task.dueDate.isBefore(threshold);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(t.matrix, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Task>('tasks').listenable(),
        builder: (context, Box<Task> taskBox, _) {
          final active = taskBox.values
              // Документите имат собствен таб → не ги показваме в матрицата.
              .where((task) =>
                  !task.isCompleted && !task.isArchived && task.template != 'document')
              .toList();

          final q1 = <Task>[], q2 = <Task>[], q3 = <Task>[], q4 = <Task>[];
          for (final task in active) {
            final imp = task.priority == 2;
            final urg = _isUrgent(task);
            if (imp && urg) q1.add(task);
            else if (imp) q2.add(task);
            else if (urg) q3.add(task);
            else q4.add(task);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                // Column headers
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            '⚡ ${t.matrixUrgent}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade500),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            t.matrixNotUrgent,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Row labels
                      Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  t.matrixImportant,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade600),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  t.matrixNotImportant,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      // 2×2 grid
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _Quadrant(
                                    tasks: q1,
                                    title: t.matrixDoFirst,
                                    subtitle: t.matrixUrgentImportant,
                                    color: Colors.red.shade400,
                                    taskBox: taskBox,
                                    emptyLabel: t.matrixEmpty,
                                  ),
                                  const SizedBox(width: 6),
                                  _Quadrant(
                                    tasks: q2,
                                    title: t.matrixSchedule,
                                    subtitle: t.matrixImportantOnly,
                                    color: Colors.blue.shade500,
                                    taskBox: taskBox,
                                    emptyLabel: t.matrixEmpty,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  _Quadrant(
                                    tasks: q3,
                                    title: t.matrixDelegate,
                                    subtitle: t.matrixUrgentOnly,
                                    color: Colors.orange.shade600,
                                    taskBox: taskBox,
                                    emptyLabel: t.matrixEmpty,
                                  ),
                                  const SizedBox(width: 6),
                                  _Quadrant(
                                    tasks: q4,
                                    title: t.matrixEliminate,
                                    subtitle: t.matrixNeither,
                                    color: Colors.grey.shade500,
                                    taskBox: taskBox,
                                    emptyLabel: t.matrixEmpty,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Quadrant extends StatelessWidget {
  final List<Task> tasks;
  final String title;
  final String subtitle;
  final Color color;
  final Box<Task> taskBox;
  final String emptyLabel;

  const _Quadrant({
    required this.tasks,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.taskBox,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              ),
            ),
            // Task list
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        emptyLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(6),
                      itemCount: tasks.length,
                      itemBuilder: (ctx, i) => _TaskTile(
                        task: tasks[i],
                        color: color,
                        taskBox: taskBox,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final Color color;
  final Box<Task> taskBox;

  const _TaskTile({required this.task, required this.color, required this.taskBox});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showActions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          task.title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  task.isCompleted = true;
                  task.completedAt = DateTime.now();
                  task.save();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(t.markAsDone),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
