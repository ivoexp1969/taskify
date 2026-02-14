import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../utils/localization.dart';
import '../services/task_view_preference.dart';

/// Glass Morphism карта за днешни задачи
class GlassTaskCard extends StatelessWidget {
  final Task task;
  final Category? category;
  final bool isOverdue;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;
  final String dateTimeStr;
  final String priorityText;
  final Color priorityColor;
  final Color accentColor;
  final String categoryName;

  const GlassTaskCard({
    super.key,
    required this.task,
    this.category,
    required this.isOverdue,
    required this.isCompleted,
    required this.onTap,
    required this.onToggleComplete,
    required this.onDelete,
    required this.dateTimeStr,
    required this.priorityText,
    required this.priorityColor,
    required this.accentColor,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Opacity(
        opacity: isCompleted ? 0.5 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.15),
                    accentColor.withOpacity(0.05),
                    theme.colorScheme.surface.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                  if (isOverdue)
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: -5,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Animated Checkbox
                        GestureDetector(
                          onTap: onToggleComplete,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isCompleted
                                  ? LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.green.shade600,
                                      ],
                                    )
                                  : null,
                              border: Border.all(
                                color: isCompleted 
                                    ? Colors.transparent 
                                    : accentColor.withOpacity(0.6),
                                width: 2,
                              ),
                              boxShadow: isCompleted
                                  ? [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              // Chips row
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  // Time chip with glow
                                  _GlowChip(
                                    icon: Icons.schedule_rounded,
                                    label: dateTimeStr,
                                    color: isOverdue ? Colors.redAccent : accentColor,
                                    glowing: isOverdue,
                                  ),
                                  // Priority chip
                                  _GlowChip(
                                    icon: task.priority == 2 
                                        ? Icons.local_fire_department_rounded
                                        : task.priority == 1
                                            ? Icons.flag_rounded
                                            : Icons.flag_outlined,
                                    label: priorityText,
                                    color: priorityColor,
                                    glowing: task.priority == 2,
                                  ),
                                  // Category chip
                                  if (categoryName.isNotEmpty)
                                    _GlowChip(
                                      icon: Icons.circle,
                                      iconSize: 8,
                                      label: categoryName,
                                      color: accentColor,
                                    ),
                                  // Subtasks progress
                                  if (task.totalSubtasksCount > 0)
                                    _SubtasksChip(
                                      completed: task.completedSubtasksCount,
                                      total: task.totalSubtasksCount,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Delete button
                        _GlassIconButton(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable карта за останали задачи
class ExpandableTaskCard extends StatelessWidget {
  final Task task;
  final Category? category;
  final bool isOverdue;
  final bool isCompleted;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String dateTimeStr;
  final String priorityText;
  final Color priorityColor;
  final Color accentColor;
  final String categoryName;
  final String? recurrenceText;

  const ExpandableTaskCard({
    super.key,
    required this.task,
    this.category,
    required this.isOverdue,
    required this.isCompleted,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
    required this.dateTimeStr,
    required this.priorityText,
    required this.priorityColor,
    required this.accentColor,
    required this.categoryName,
    this.recurrenceText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);
    // ViewPreference се използва само за начално състояние в parent widget

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Opacity(
        opacity: isCompleted ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(isExpanded ? 14 : 10),
            border: Border.all(
              color: isExpanded 
                  ? accentColor.withOpacity(0.4)
                  : theme.colorScheme.outline.withOpacity(0.1),
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(isExpanded ? 14 : 10),
              onTap: onToggleExpand,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Column(
                  children: [
                    // Compact header (always visible)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: isExpanded ? 12 : 8,
                      ),
                      child: Row(
                        children: [
                          // Left accent line
                          Container(
                            width: 3,
                            height: isExpanded ? 40 : 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accentColor,
                                  accentColor.withOpacity(0.4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Checkbox
                          GestureDetector(
                            onTap: onToggleComplete,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: isCompleted
                                    ? Colors.green
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isCompleted
                                      ? Colors.green
                                      : accentColor.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title and mini info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: isExpanded ? 14 : 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: isExpanded ? 3 : 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!isExpanded) ...[
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 10,
                                        color: isOverdue 
                                            ? Colors.redAccent 
                                            : theme.colorScheme.onSurface.withOpacity(0.4),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        dateTimeStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isOverdue 
                                              ? Colors.redAccent 
                                              : theme.colorScheme.onSurface.withOpacity(0.4),
                                        ),
                                      ),
                                      if (task.totalSubtasksCount > 0) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.checklist_rounded,
                                          size: 10,
                                          color: theme.colorScheme.primary.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${task.completedSubtasksCount}/${task.totalSubtasksCount}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.primary.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Expand indicator
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Expanded content
                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            // Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _CompactChip(
                                  icon: Icons.schedule_rounded,
                                  label: dateTimeStr,
                                  color: isOverdue ? Colors.redAccent : null,
                                ),
                                _CompactChip(
                                  icon: task.priority == 2 
                                      ? Icons.local_fire_department_rounded
                                      : task.priority == 1
                                          ? Icons.flag_rounded
                                          : Icons.flag_outlined,
                                  label: priorityText,
                                  color: priorityColor,
                                ),
                                if (categoryName.isNotEmpty)
                                  _CompactChip(
                                    icon: Icons.folder_rounded,
                                    label: categoryName,
                                    color: accentColor,
                                  ),
                                if (recurrenceText != null)
                                  _CompactChip(
                                    icon: Icons.repeat_rounded,
                                    label: recurrenceText!,
                                  ),
                                if (task.hasReminders)
                                  _CompactChip(
                                    icon: Icons.notifications_active_rounded,
                                    label: t.reminder,
                                    color: Colors.amber,
                                  ),
                              ],
                            ),
                            // Subtasks progress
                            if (task.totalSubtasksCount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: task.completedSubtasksCount / 
                                               task.totalSubtasksCount,
                                        backgroundColor: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        valueColor: AlwaysStoppedAnimation(
                                          task.completedSubtasksCount == 
                                                  task.totalSubtasksCount
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${task.completedSubtasksCount}/${task.totalSubtasksCount}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // Actions
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: onEdit,
                                  icon: const Icon(Icons.edit_rounded, size: 16),
                                  label: Text(t.edit, style: const TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton.icon(
                                  onPressed: onDelete,
                                  icon: const Icon(Icons.delete_rounded, size: 16),
                                  label: Text(t.delete, style: const TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper widgets

class _GlowChip extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color color;
  final bool glowing;

  const _GlowChip({
    required this.icon,
    this.iconSize = 14,
    required this.label,
    required this.color,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtasksChip extends StatelessWidget {
  final int completed;
  final int total;

  const _SubtasksChip({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = completed / total;
    final isDone = completed == total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isDone ? Colors.green : theme.colorScheme.primary)
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDone ? Colors.green : theme.colorScheme.primary)
              .withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(
                isDone ? Colors.green : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDone ? Colors.green : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _CompactChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.onSurface.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
