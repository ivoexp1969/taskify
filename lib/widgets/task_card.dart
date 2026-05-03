import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/task_view_preference.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Category? category;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onCheckChanged;
  final String Function(int) priorityLabel;
  final String Function(String?) recurrenceLabel;

  const TaskCard({
    super.key,
    required this.task,
    this.category,
    this.onTap,
    this.onLongPress,
    this.onCheckChanged,
    required this.priorityLabel,
    required this.recurrenceLabel,
  });

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewPref = TaskViewPreference();
    final catColor = category != null ? Color(category!.colorValue) : Colors.grey;
    final priorityColor = task.priority == 2 ? Colors.red : (task.priority == 1 ? Colors.orange : Colors.green);
    final now = DateTime.now();
    // Задачи само с дата (час=0) не са overdue докато денят не е минал изцяло
    final isOverdue = !task.isCompleted && (() {
      if (task.dueDate.hour != 0 || task.dueDate.minute != 0) {
        return task.dueDate.isBefore(now);
      }
      return now.isAfter(DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day, 23, 59, 59));
    })();
    final accentColor = isOverdue ? Colors.redAccent : catColor;

    if (viewPref.isCompact) {
      return _compact(theme, accentColor, priorityColor);
    }
    return _expanded(theme, accentColor, catColor, priorityColor);
  }

  Widget _compact(ThemeData theme, Color accent, Color priority) {
    return Opacity(
      opacity: task.isCompleted ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          onTap: onTap, onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 4, height: 40, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)))),
                Checkbox(value: task.isCompleted, onChanged: onCheckChanged, activeColor: accent),
                Expanded(child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null))),
                Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: priority, shape: BoxShape.circle)),
                Padding(padding: const EdgeInsets.only(right: 12), child: Text(_formatTime(task.dueDate), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expanded(ThemeData theme, Color accent, Color catColor, Color priority) {
    final catName = category?.name ?? '';
    return Opacity(
      opacity: task.isCompleted ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        child: InkWell(
          onTap: onTap, onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(width: 5, height: 60, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)))),
                Checkbox(value: task.isCompleted, onChanged: onCheckChanged, activeColor: accent),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (catName.isNotEmpty) _chip(catColor, catName),
                        _chip(priority, priorityLabel(task.priority)),
                        if (task.recurrence != null) _chip(Colors.grey, recurrenceLabel(task.recurrence)),
                        if (task.hasReminders) _chip(Colors.amber, '🔔'),
                        if (task.totalSubtasksCount > 0) _chip(Colors.blue, '${task.completedSubtasksCount}/${task.totalSubtasksCount}'),
                      ]),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(_formatTime(task.dueDate), style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(Color c, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w500)),
    );
  }
}
