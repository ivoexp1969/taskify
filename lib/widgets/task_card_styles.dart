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
    final t = AppText.of(context);

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
                border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 20, spreadRadius: -5),
                  if (isOverdue) BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 30, spreadRadius: -5),
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
                        GestureDetector(
                          onTap: onToggleComplete,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isCompleted
                                  ? LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600])
                                  : null,
                              border: Border.all(
                                color: isCompleted ? Colors.transparent : accentColor.withOpacity(0.6),
                                width: 2,
                              ),
                            ),
                            child: isCompleted ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.template == 'meeting' ? '${t.meetingTitle(task.title)}' : task.template == 'travel' ? '${t.travelTitle(task.title)}' : task.template == 'gift' ? '${t.giftTitle(task.title)}' : task.title,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, decoration: isCompleted ? TextDecoration.lineThrough : null, color: theme.colorScheme.onSurface),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 6, children: [
                                _GlowChip(icon: Icons.schedule_rounded, label: dateTimeStr, color: isOverdue ? Colors.redAccent : accentColor, glowing: isOverdue),
                                _GlowChip(icon: task.priority == 2 ? Icons.local_fire_department_rounded : task.priority == 1 ? Icons.flag_rounded : Icons.flag_outlined, label: priorityText, color: priorityColor, glowing: task.priority == 2),
                                if (categoryName.isNotEmpty) _GlowChip(icon: Icons.circle, iconSize: 8, label: categoryName, color: accentColor),
                                if (task.totalSubtasksCount > 0) _SubtasksChip(completed: task.completedSubtasksCount, total: task.totalSubtasksCount),
                              ]),
                            ],
                          ),
                        ),
                        _GlassIconButton(icon: Icons.delete_outline_rounded, color: Colors.redAccent, onTap: onDelete),
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

/// Подобрена Expandable карта с бележки preview, overdue фон, модерни чипове
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
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.colorScheme.surface;

    // Лек червен фон при overdue
    final bgColor = isOverdue && !isCompleted
        ? Color.lerp(surfaceColor, Colors.red, isDark ? 0.06 : 0.03)!
        : surfaceColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isCompleted ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(isExpanded ? 16 : 12),
            border: Border.all(
              color: isExpanded
                  ? accentColor.withOpacity(0.35)
                  : (isOverdue && !isCompleted
                      ? Colors.red.withOpacity(0.2)
                      : theme.colorScheme.outline.withOpacity(0.08)),
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: [
              if (isExpanded)
                BoxShadow(
                  color: accentColor.withOpacity(isDark ? 0.2 : 0.1),
                  blurRadius: 16, offset: const Offset(0, 4), spreadRadius: -2,
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 6, offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(isExpanded ? 16 : 12),
              onTap: onToggleExpand,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    // ═══ HEADER ═══
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, isExpanded ? 12 : 8, 10, isExpanded ? 10 : 8),
                      child: Row(
                        children: [
                          // Акцентна линия
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            width: 3.5,
                            height: isExpanded ? 42 : 34,
                            decoration: BoxDecoration(
                              color: isOverdue && !isCompleted ? Colors.redAccent : accentColor,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: isOverdue && !isCompleted
                                  ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 6, spreadRadius: -1)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Чекбокс
                          _ModernCheckbox(isChecked: isCompleted, color: accentColor, onTap: onToggleComplete),
                          const SizedBox(width: 10),
                          // Заглавие + мета
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.template == 'meeting' ? '${t.meetingTitle(task.title)}' : task.template == 'travel' ? '${t.travelTitle(task.title)}' : task.template == 'gift' ? '${t.giftTitle(task.title)}' : task.title,
                                  style: TextStyle(
                                    fontSize: isExpanded ? 14.5 : 13.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    decorationColor: theme.colorScheme.onSurface.withOpacity(0.4),
                                    color: isCompleted ? theme.colorScheme.onSurface : (task.template != null || task.googleCalendarEventId != null ? accentColor : theme.colorScheme.onSurface),
                                    height: 1.3,
                                  ),
                                  maxLines: isExpanded ? 3 : 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Collapsed мета ред
                                if (!isExpanded) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      _MiniPill(
                                        icon: Icons.schedule_rounded,
                                        text: dateTimeStr,
                                        color: isOverdue ? Colors.redAccent : theme.colorScheme.onSurface.withOpacity(0.45),
                                        bold: isOverdue,
                                      ),
                                      if (task.totalSubtasksCount > 0) ...[
                                        const SizedBox(width: 8),
                                        _MiniPill(
                                          icon: Icons.checklist_rounded,
                                          text: '${task.completedSubtasksCount}/${task.totalSubtasksCount}',
                                          color: task.completedSubtasksCount == task.totalSubtasksCount
                                              ? Colors.green
                                              : theme.colorScheme.primary.withOpacity(0.6),
                                        ),
                                      ],
                                      if (task.hasNotes) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.sticky_note_2_outlined, size: 12, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                                      ],
                                      if (task.hasReminders) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.notifications_active_rounded, size: 12, color: Colors.amber.withOpacity(0.7)),
                                      ],
                                      if (task.googleCalendarEventId != null) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.event_rounded, size: 12, color: Colors.blue.withOpacity(0.5)),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Приоритет точка (collapsed)
                          if (!isExpanded) ...[
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: priorityColor,
                                shape: BoxShape.circle,
                                boxShadow: task.priority == 2
                                    ? [BoxShadow(color: priorityColor.withOpacity(0.5), blurRadius: 4)]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Стрелка
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 280),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ═══ EXPANDED CONTENT ═══
                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
                            const SizedBox(height: 10),

                            // Бележки preview
                            if (task.hasNotes) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.06)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.sticky_note_2_outlined, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.35)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        () {
                                          final notes = task.notes!;
                                          if (notes.startsWith('birthYear:')) {
                                            return '${t.birthYear}: ${notes.replaceFirst('birthYear:', '').split('\n').first}';
                                          }
                                          if (notes.contains('with:') || notes.contains('place:')) {
                                            final parts = <String>[];
                                            for (final line in notes.split('\n')) {
                                              if (line.startsWith('with:')) parts.add('${t.meetingWith}: ${line.replaceFirst('with:', '')}');
                                              if (line.startsWith('place:')) parts.add('${t.meetingPlace}: ${line.replaceFirst('place:', '')}');
                                            }
                                            return parts.join(' · ');
                                          }
                                          if (notes.contains('type:') || notes.contains('duration:')) {
                                            final parts = <String>[];
                                            for (final line in notes.split('\n')) {
                                              if (line.startsWith('type:')) parts.add(line.replaceFirst('type:', ''));
                                              if (line.startsWith('duration:')) parts.add('${t.workoutDuration}: ${line.replaceFirst('duration:', '')}');
                                            }
                                            return parts.join(' · ');
                                          }
                                          if (notes.contains('what:') || notes.contains('amount:')) {
                                            final parts = <String>[];
                                            for (final line in notes.split('\n')) {
                                              if (line.startsWith('what:')) parts.add(line.replaceFirst('what:', ''));
                                              if (line.startsWith('amount:')) parts.add('${t.paymentAmount}: ${line.replaceFirst('amount:', '')}');
                                            }
                                            return parts.join(' · ');
                                          }
                                          if (notes.contains('dest:')) {
                                            for (final line in notes.split('\n')) {
                                              if (line.startsWith('dest:')) return line.replaceFirst('dest:', '');
                                            }
                                          }
                                          if (notes.contains('for:') || notes.contains('occasion:') || notes.contains('budget:')) {
                                            final parts = <String>[];
                                            for (final line in notes.split('\n')) {
                                              if (line.startsWith('occasion:')) parts.add(line.replaceFirst('occasion:', ''));
                                              if (line.startsWith('budget:')) parts.add('${t.giftBudget}: ${line.replaceFirst('budget:', '')}');
                                            }
                                            if (parts.isNotEmpty) return parts.join(' · ');
                                          }
                                          return notes;
                                        }(),
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.55), height: 1.4),
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Чипове
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: [
                                _DetailChip(icon: Icons.schedule_rounded, label: dateTimeStr, color: isOverdue ? Colors.redAccent : null),
                                _DetailChip(
                                  icon: task.priority == 2 ? Icons.local_fire_department_rounded
                                      : task.priority == 1 ? Icons.flag_rounded : Icons.flag_outlined,
                                  label: priorityText, color: priorityColor,
                                ),
                                if (categoryName.isNotEmpty)
                                  _DetailChip(icon: Icons.circle, iconSize: 8, label: categoryName, color: accentColor),
                                if (recurrenceText != null)
                                  _DetailChip(icon: Icons.repeat_rounded, label: recurrenceText!),
                                if (task.hasReminders)
                                  _DetailChip(icon: Icons.notifications_active_rounded, label: t.reminder, color: Colors.amber.shade700),
                                if (task.googleCalendarEventId != null)
                                  _DetailChip(icon: Icons.event_rounded, label: 'Calendar', color: Colors.blue),
                              ],
                            ),

                            // Подзадачи
                            if (task.totalSubtasksCount > 0) ...[
                              const SizedBox(height: 10),
                              _SubtaskProgress(
                                completed: task.completedSubtasksCount,
                                total: task.totalSubtasksCount,
                                color: theme.colorScheme.primary,
                              ),
                            ],

                            // Бутони
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _ActionButton(icon: Icons.edit_outlined, label: t.edit, color: theme.colorScheme.primary, onTap: onEdit),
                                const SizedBox(width: 6),
                                _ActionButton(icon: Icons.delete_outline_rounded, label: t.delete, color: Colors.redAccent, onTap: onDelete),
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

// ════════════════════ HELPER WIDGETS ════════════════════

/// Модерен чекбокс с gradient анимация
class _ModernCheckbox extends StatelessWidget {
  final bool isChecked;
  final Color color;
  final VoidCallback onTap;
  const _ModernCheckbox({required this.isChecked, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 22, height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: isChecked
              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.green.shade400, Colors.green.shade600])
              : null,
          border: Border.all(color: isChecked ? Colors.transparent : color.withOpacity(0.4), width: 2),
          boxShadow: isChecked
              ? [BoxShadow(color: Colors.green.withOpacity(0.35), blurRadius: 8, spreadRadius: -2)]
              : null,
        ),
        child: isChecked ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
      ),
    );
  }
}

/// Мини ред елемент за collapsed мета информация
class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;
  const _MiniPill({required this.icon, required this.text, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 10.5, color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
      ],
    );
  }
}

/// Чип за expanded детайли
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color? color;
  const _DetailChip({required this.icon, this.iconSize = 13, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.onSurface.withOpacity(0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.12), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: chipColor),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Прогрес бар за подзадачи
class _SubtaskProgress extends StatelessWidget {
  final int completed;
  final int total;
  final Color color;
  const _SubtaskProgress({required this.completed, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = completed / total;
    final isDone = completed == total;
    final barColor = isDone ? Colors.green : color;
    return Row(
      children: [
        Icon(isDone ? Icons.check_circle_rounded : Icons.checklist_rounded, size: 14, color: barColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: barColor.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(barColor.withOpacity(0.7)),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$completed/$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: barColor.withOpacity(0.7))),
      ],
    );
  }
}

/// Бутон за действие (edit/delete)
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════ GLASS CARD HELPERS ════════════════════

class _GlowChip extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color color;
  final bool glowing;
  const _GlowChip({required this.icon, this.iconSize = 14, required this.label, required this.color, this.glowing = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: glowing ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: -2)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _SubtasksChip extends StatelessWidget {
  final int completed;
  final int total;
  const _SubtasksChip({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = completed / total;
    final isDone = completed == total;
    final c = isDone ? Colors.green : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(value: progress, strokeWidth: 2, backgroundColor: c.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(c))),
          const SizedBox(width: 6),
          Text('$completed/$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.color, required this.onTap});

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
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
