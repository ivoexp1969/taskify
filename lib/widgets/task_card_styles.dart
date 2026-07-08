import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../utils/localization.dart';
import '../services/task_view_preference.dart';
import '../services/pro_service.dart';
import 'gift_cta.dart';

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
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.05),
                    theme.colorScheme.surface.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -5),
                  if (isOverdue) BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: -5),
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
                                color: isCompleted ? Colors.transparent : accentColor.withValues(alpha: 0.6),
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
                                task.template == 'meeting' ? '${t.meetingTitle(task.title)}' : task.template == 'travel' ? '${t.travelTitle(task.title)}' : task.template == 'gift' ? '${t.giftTitle(task.title)}' : task.template == 'birthday' ? '${t.birthdayTitle(task.title)}' : task.title,
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
  final VoidCallback? onStartPomodoro;
  final VoidCallback? onBreakdown;
  /// Отбелязване на ЕДНА подзадача (по индекс) при разгъната карта. Ако е null,
  /// разгънатата карта показва само лентата с прогрес (без чекбоксове).
  final void Function(int index)? onToggleSubtask;
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
    this.onStartPomodoro,
    this.onBreakdown,
    this.onToggleSubtask,
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
    final blockColor = isOverdue && !isCompleted ? Colors.redAccent : accentColor;
    final dateColor = isOverdue && !isCompleted
        ? Colors.redAccent
        : (isDark ? Colors.white : theme.colorScheme.onSurface).withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isCompleted ? 0.55 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: isExpanded
                ? Border.all(color: blockColor.withValues(alpha: 0.45), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: blockColor.withValues(alpha: isDark ? 0.18 : 0.10),
                blurRadius: isExpanded ? 18 : 7,
                offset: const Offset(0, 2),
                spreadRadius: isExpanded ? -2 : -1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 4, offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggleExpand,
                child: Stack(
                  children: [
                    // ═══ ТЪНКА ЛЯВА ЛЕНТА ═══
                    Positioned(
                      left: 0, top: 0, bottom: 0,
                      child: Container(width: 4, color: blockColor),
                    ),
                    // ═══ СЪДЪРЖАНИЕ ═══
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── HEADER ───
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: _ModernCheckbox(
                                    isChecked: isCompleted,
                                    color: blockColor,
                                    onTap: onToggleComplete,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.template == 'meeting' ? t.meetingTitle(task.title)
                                            : task.template == 'travel' ? t.travelTitle(task.title)
                                            : task.template == 'gift' ? t.giftTitle(task.title)
                                            : task.template == 'birthday' ? t.birthdayTitle(task.title)
                                            : task.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                                          decorationColor: blockColor.withValues(alpha: 0.5),
                                          color: isCompleted
                                              ? blockColor.withValues(alpha: 0.4)
                                              : blockColor,
                                          height: 1.3,
                                        ),
                                        maxLines: isExpanded ? 3 : 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.schedule_rounded, size: 11, color: dateColor),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(dateTimeStr,
                                              style: TextStyle(fontSize: 11, color: dateColor),
                                              overflow: TextOverflow.ellipsis),
                                          ),
                                          if (task.googleCalendarEventId != null) ...[
                                            const SizedBox(width: 5),
                                            Icon(Icons.event_rounded, size: 11,
                                              color: Colors.blue.withValues(alpha: 0.7)),
                                          ],
                                          if (task.hasReminders) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.notifications_active_rounded, size: 11,
                                              color: Colors.amber.withValues(alpha: 0.8)),
                                          ],
                                          if (recurrenceText != null && recurrenceText!.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.repeat_rounded, size: 11,
                                              color: blockColor.withValues(alpha: 0.6)),
                                          ],
                                          if (task.totalSubtasksCount > 0) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.checklist_rounded, size: 11,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                            const SizedBox(width: 2),
                                            Text('${task.completedSubtasksCount}/${task.totalSubtasksCount}',
                                              style: TextStyle(fontSize: 10,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                                          ],
                                          if (task.hasNotes) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.sticky_note_2_outlined, size: 11,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                          ],
                                        ],
                                      ),
                                      // Възраст за рождени дни (видима и на свитата карта)
                                      if ((task.template == 'birthday' || task.categoryId == 'birthday') &&
                                          _birthdayAge(task, t) != null) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(Icons.cake_rounded, size: 11,
                                              color: blockColor.withValues(alpha: 0.8)),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                _birthdayAge(task, t)!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: blockColor.withValues(alpha: 0.9)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (task.priority > 0) ...[
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(
                                          color: priorityColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                    ],
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.5 : 0,
                                      duration: const Duration(milliseconds: 280),
                                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 18,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // ─── EXPANDED ───
                            if (isExpanded) ...[
                              const SizedBox(height: 10),
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      blockColor.withValues(alpha: isDark ? 0.35 : 0.2),
                                      blockColor.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (task.hasNotes) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.06)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.sticky_note_2_outlined, size: 14,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _notesPreview(task.notes!, t, task.dueDate.year),
                                          style: TextStyle(fontSize: 12,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                            height: 1.4),
                                          maxLines: 2, overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Wrap(
                                spacing: 6, runSpacing: 6,
                                children: [
                                  _DetailChip(
                                    icon: Icons.schedule_rounded, label: dateTimeStr,
                                    color: isOverdue && !isCompleted ? Colors.redAccent : null),
                                  _DetailChip(
                                    icon: task.priority == 2
                                        ? Icons.local_fire_department_rounded
                                        : task.priority == 1 ? Icons.flag_rounded : Icons.flag_outlined,
                                    label: priorityText, color: priorityColor),
                                  if (categoryName.isNotEmpty)
                                    _DetailChip(icon: Icons.circle, iconSize: 8,
                                      label: categoryName, color: blockColor),
                                  if (recurrenceText != null && recurrenceText!.isNotEmpty)
                                    _DetailChip(icon: Icons.repeat_rounded, label: recurrenceText!),
                                  if (task.hasReminders)
                                    _DetailChip(icon: Icons.notifications_active_rounded,
                                      label: t.reminder, color: Colors.amber.shade700),
                                  if (task.googleCalendarEventId != null)
                                    _DetailChip(icon: Icons.event_rounded,
                                      label: 'Calendar', color: Colors.blue),
                                ],
                              ),
                              // „Изпрати цветя/подарък" за рождени дни (монетизация).
                              if ((task.template == 'birthday' || task.categoryId == 'birthday')
                                  && !isCompleted) ...[
                                const SizedBox(height: 10),
                                GiftOfferButton(lang: t.lang, kind: 'gift_birthday'),
                              ],
                              if (task.totalSubtasksCount > 0) ...[
                                const SizedBox(height: 10),
                                _SubtaskProgress(
                                  completed: task.completedSubtasksCount,
                                  total: task.totalSubtasksCount,
                                  color: theme.colorScheme.primary,
                                ),
                                if (onToggleSubtask != null) ...[
                                  const SizedBox(height: 6),
                                  _SubtaskChecklist(
                                    task: task,
                                    color: theme.colorScheme.primary,
                                    onToggle: onToggleSubtask!,
                                  ),
                                ],
                              ],
                              const SizedBox(height: 10),
                              if (onBreakdown != null && !isCompleted && task.totalSubtasksCount == 0) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: _ActionButton(
                                    icon: Icons.auto_awesome,
                                    label: t.aiBreakdownAction,
                                    color: Colors.deepPurple,
                                    onTap: onBreakdown!,
                                    expand: true,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Row(
                                children: [
                                  if (onStartPomodoro != null && !isCompleted) ...[
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.timer_outlined,
                                        label: t.pomodoroFocus,
                                        color: Colors.deepOrange,
                                        onTap: onStartPomodoro!,
                                        expand: true,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: _ActionButton(
                                      icon: Icons.edit_outlined,
                                      label: t.edit,
                                      color: theme.colorScheme.primary,
                                      onTap: onEdit,
                                      expand: true,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _ActionButton(
                                      icon: Icons.delete_outline_rounded,
                                      label: t.delete,
                                      color: Colors.redAccent,
                                      onTap: onDelete,
                                      expand: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
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

  /// За рождени дни: връща „Навършва X" спрямо годината на събитието,
  /// или null ако няма валидна година на раждане в notes.
  static String? _birthdayAge(Task task, AppText t) {
    final notes = task.notes;
    if (notes == null || !notes.startsWith('birthYear:')) return null;
    final yStr = notes.replaceFirst('birthYear:', '').split('\n').first.trim();
    final by = int.tryParse(yStr);
    if (by == null) return null;
    final age = task.dueDate.year - by;
    if (age < 0 || age > 130) return null;
    return t.turnsAge(age);
  }

  static String _notesPreview(String notes, AppText t, int dueYear) {
    if (notes.startsWith('birthYear:')) {
      final yStr = notes.replaceFirst('birthYear:', '').split('\n').first.trim();
      final by = int.tryParse(yStr);
      if (by != null) {
        // Възрастта се смята спрямо ГОДИНАТА НА СЪБИТИЕТО (dueYear),
        // за да се обновява правилно при ежегодното превъртане.
        final age = dueYear - by;
        if (age >= 0 && age <= 130) {
          return '${t.turnsAge(age)} · ${t.birthYear}: $by';
        }
      }
      return '${t.birthYear}: $yStr';
    }
    if (notes.contains('with:') || notes.contains('place:')) {
      final parts = <String>[];
      for (final line in notes.split('\n')) {
        if (line.startsWith('with:')) parts.add('${t.meetingWith}: ${line.replaceFirst('with:', '')}');
        if (line.startsWith('place:')) parts.add('${t.meetingPlace}: ${line.replaceFirst('place:', '')}');
      }
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    if (notes.contains('type:') || notes.contains('duration:')) {
      final parts = <String>[];
      for (final line in notes.split('\n')) {
        if (line.startsWith('type:')) parts.add(line.replaceFirst('type:', ''));
        if (line.startsWith('duration:')) parts.add('${t.workoutDuration}: ${line.replaceFirst('duration:', '')}');
      }
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    if (notes.contains('what:') || notes.contains('amount:')) {
      final parts = <String>[];
      for (final line in notes.split('\n')) {
        if (line.startsWith('what:')) parts.add(line.replaceFirst('what:', ''));
        if (line.startsWith('amount:')) parts.add('${t.paymentAmount}: ${line.replaceFirst('amount:', '')}');
      }
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    if (notes.contains('dest:')) {
      for (final line in notes.split('\n')) {
        if (line.startsWith('dest:')) return line.replaceFirst('dest:', '');
      }
    }
    if (notes.contains('occasion:') || notes.contains('budget:')) {
      final parts = <String>[];
      for (final line in notes.split('\n')) {
        if (line.startsWith('occasion:')) parts.add(line.replaceFirst('occasion:', ''));
        if (line.startsWith('budget:')) parts.add('${t.giftBudget}: ${line.replaceFirst('budget:', '')}');
      }
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    return notes;
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
          border: Border.all(color: isChecked ? Colors.transparent : color.withValues(alpha: 0.4), width: 2),
          boxShadow: isChecked
              ? [BoxShadow(color: Colors.green.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: -2)]
              : null,
        ),
        child: isChecked ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
      ),
    );
  }
}

/// Интерактивен списък с подзадачи в разгъната карта — всеки ред с чекбокс за
/// отбелязване като завършена. Ползва се и от класическата, и от билетната кожа,
/// и от трите екрана (Задачи, Календар, Споделени). Чете `task.subtasksList`
/// (единен формат — виж [SubtaskCodec]); `onToggle(index)` сменя 0:↔1: за реда.
class _SubtaskChecklist extends StatelessWidget {
  final Task task;
  final Color color;
  final void Function(int index) onToggle;
  const _SubtaskChecklist(
      {required this.task, required this.color, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subs = task.subtasksList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < subs.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onToggle(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniCheck(checked: subs[i]['done'] == true, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (subs[i]['text'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: subs[i]['done'] == true
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        decoration: subs[i]['done'] == true
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Компактен чекбокс за подзадача (по-малък от [_ModernCheckbox]).
class _MiniCheck extends StatelessWidget {
  final bool checked;
  final Color color;
  const _MiniCheck({required this.checked, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: checked ? Colors.green.shade500 : null,
        border: Border.all(
          color: checked ? Colors.transparent : color.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
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
    final chipColor = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withValues(alpha: 0.12), width: 0.5),
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
        Icon(isDone ? Icons.check_circle_rounded : Icons.checklist_rounded, size: 14, color: barColor.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: barColor.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(barColor.withValues(alpha: 0.7)),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$completed/$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: barColor.withValues(alpha: 0.7))),
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
  final bool expand;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap, this.expand = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Компактен icon-only бутон за expanded action row
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Icon(icon, size: 18, color: color),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        boxShadow: glowing ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: -2)] : null,
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
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(value: progress, strokeWidth: 2, backgroundColor: c.withValues(alpha: 0.2), valueColor: AlwaysStoppedAnimation(c))),
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ════════════════════ КОЖА-ПРЕВКЛЮЧВАТЕЛ ════════════════════

/// Избира коя „кожа" да рендира за дадена задача според [CardStyle] настройката.
/// Една логика (callbacks от екрана), две визуални кожи. Реактивен: слуша
/// [TaskViewPreference] (смяна на стил) и [ProService] (Pro статус) →
/// смяната важи веднага без рестарт. „Билети" е Pro тема; не-Pro вижда класически.
class TaskCardView extends StatelessWidget {
  final Task task;
  final Category? category;
  final bool isOverdue;
  final bool isCompleted;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onStartPomodoro;
  final VoidCallback? onBreakdown;
  final void Function(int index)? onToggleSubtask;
  final String dateTimeStr;
  final String priorityText;
  final Color priorityColor;
  final Color accentColor;
  final String categoryName;
  final String? recurrenceText;

  const TaskCardView({
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
    this.onStartPomodoro,
    this.onBreakdown,
    this.onToggleSubtask,
    required this.dateTimeStr,
    required this.priorityText,
    required this.priorityColor,
    required this.accentColor,
    required this.categoryName,
    this.recurrenceText,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([TaskViewPreference(), ProService()]),
      builder: (context, _) {
        final useTicket = TaskViewPreference().isTicket && ProService().isPro;
        if (useTicket) {
          return TicketTaskCard(
            task: task, category: category, isOverdue: isOverdue,
            isCompleted: isCompleted, isExpanded: isExpanded,
            onToggleExpand: onToggleExpand, onToggleComplete: onToggleComplete,
            onEdit: onEdit, onDelete: onDelete, onStartPomodoro: onStartPomodoro,
            onBreakdown: onBreakdown, onToggleSubtask: onToggleSubtask,
            dateTimeStr: dateTimeStr,
            priorityText: priorityText, priorityColor: priorityColor,
            accentColor: accentColor, categoryName: categoryName,
            recurrenceText: recurrenceText,
          );
        }
        return ExpandableTaskCard(
          task: task, category: category, isOverdue: isOverdue,
          isCompleted: isCompleted, isExpanded: isExpanded,
          onToggleExpand: onToggleExpand, onToggleComplete: onToggleComplete,
          onEdit: onEdit, onDelete: onDelete, onStartPomodoro: onStartPomodoro,
          onBreakdown: onBreakdown, onToggleSubtask: onToggleSubtask,
          dateTimeStr: dateTimeStr,
          priorityText: priorityText, priorityColor: priorityColor,
          accentColor: accentColor, categoryName: categoryName,
          recurrenceText: recurrenceText,
        );
      },
    );
  }
}

// ════════════════════ БИЛЕТНА КОЖА ════════════════════

/// Алтернативна „билетна" кожа: хоризонтален билет с ляв отрязък (час/дата),
/// перфорация и тяло. Завършване чрез „откъсване" (drag надолу / long-press
/// върху отрязъка) или бутон в expand. Same props като [ExpandableTaskCard].
class TicketTaskCard extends StatefulWidget {
  final Task task;
  final Category? category;
  final bool isOverdue;
  final bool isCompleted;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onStartPomodoro;
  final VoidCallback? onBreakdown;
  final void Function(int index)? onToggleSubtask;
  final String dateTimeStr;
  final String priorityText;
  final Color priorityColor;
  final Color accentColor;
  final String categoryName;
  final String? recurrenceText;

  const TicketTaskCard({
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
    this.onStartPomodoro,
    this.onBreakdown,
    this.onToggleSubtask,
    required this.dateTimeStr,
    required this.priorityText,
    required this.priorityColor,
    required this.accentColor,
    required this.categoryName,
    this.recurrenceText,
  });

  @override
  State<TicketTaskCard> createState() => _TicketTaskCardState();
}

class _TicketTaskCardState extends State<TicketTaskCard>
    with SingleTickerProviderStateMixin {
  static const double _stubWidth = 64;
  static const double _perfWidth = 14;
  double _dragDy = 0;
  bool _dragging = false;
  late final AnimationController _tear;

  @override
  void initState() {
    super.initState();
    _tear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: widget.isCompleted ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant TicketTaskCard old) {
    super.didUpdateWidget(old);
    // Завършване по друг път (swipe, облак, un-complete) → анимирай скъсването/залепването
    if (widget.isCompleted != old.isCompleted) {
      if (widget.isCompleted) {
        if (_tear.value < 1.0) _tear.forward();
      } else {
        if (_tear.value > 0.0) _tear.reverse();
      }
    }
  }

  @override
  void dispose() {
    _tear.dispose();
    super.dispose();
  }

  /// Завършване с видимо „откъсване": изиграва анимацията ПРЕДИ маркирането,
  /// за да се види дори когато после задачата напусне списъка (филтър „активни").
  void _completeViaTear() {
    if (widget.isCompleted) {
      widget.onToggleComplete(); // un-complete; reverse се поема от didUpdateWidget
      return;
    }
    _tear.forward(from: 0.0).whenComplete(() {
      widget.onToggleComplete();
    });
  }

  void _onDragStart(DragStartDetails _) {
    _dragDy = 0;
    if (!widget.isCompleted) setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.isCompleted) return;
    _dragDy += d.delta.dy;
    setState(() {}); // live следване на отрязъка
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final shouldComplete = !widget.isCompleted && (_dragDy > 36 || v > 320);
    _dragDy = 0;
    setState(() => _dragging = false);
    if (shouldComplete) _completeViaTear();
  }

  String _stubBig(AppText t) {
    final d = widget.task.dueDate;
    final hasTime = d.hour != 0 || d.minute != 0;
    if (hasTime) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return _dayLabel(t);
  }

  String? _stubSmall(AppText t) {
    final d = widget.task.dueDate;
    final hasTime = d.hour != 0 || d.minute != 0;
    return hasTime ? _dayLabel(t) : null;
  }

  String _dayLabel(AppText t) {
    if (widget.isOverdue && !widget.isCompleted) return t.overdueLabel;
    final d = widget.task.dueDate;
    final now = DateTime.now();
    final dd = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = dd.difference(today).inDays;
    if (diff == 0) return t.today.toLowerCase();
    if (diff == 1) return t.tomorrow;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Отрязъкът носи ЦВЕТА НА КАТЕГОРИЯТА — резолвнат на живо от Category обекта,
    // не от accentColor (който за task-ове с template е фиксиран template цвят).
    // Така цветът съответства на категорията И се обновява веднага при смяна на
    // цвят от „Управление на категории" (categoriesMap се пресъздава при rebuild).
    // Просрочена задача → червен отрязък (замества overdue tinting).
    final categoryColor = widget.category != null
        ? Color(widget.category!.colorValue)
        : widget.accentColor;
    final stubColor = widget.isOverdue && !widget.isCompleted
        ? Colors.redAccent
        : categoryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: widget.isCompleted ? 0.7 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: stubColor.withValues(alpha: isDark ? 0.16 : 0.09),
                blurRadius: widget.isExpanded ? 16 : 6,
                offset: const Offset(0, 2),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 4, offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // Тялото дефинира височината (с гладкия AnimatedSize expand);
                // отместено вдясно, за да освободи място за отрязъка + перфорацията.
                Padding(
                  padding: const EdgeInsets.only(left: _stubWidth + _perfWidth),
                  child: _buildBody(theme, t, stubColor, isDark),
                ),
                // Отрязък + перфорация — разпъват се по височината на тялото.
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStub(theme, t, stubColor, isDark),
                      SizedBox(
                        width: _perfWidth,
                        child: CustomPaint(
                          painter: _PerforationPainter(
                            dashColor: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.3 : 0.22),
                            notchColor: theme.scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStub(ThemeData theme, AppText t, Color stubColor, bool isDark) {
    final small = _stubSmall(t);
    final liveDrag = _dragging ? _dragDy.clamp(0.0, 44.0) * 0.7 : 0.0;
    final stub = Container(
      width: _stubWidth,
      color: stubColor.withValues(alpha: isDark ? 0.34 : 0.22),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // FittedBox → часът „06:30" (широки цифри) винаги се събира в отрязъка,
              // вместо да се реже на „06:..." при extra-bold шрифта.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _stubBig(t),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: stubColor,
                    decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (small != null) ...[
                const SizedBox(height: 2),
                Text(
                  small,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: stubColor.withValues(alpha: 0.75)),
                ),
              ],
            ],
          ),
          Icon(
            widget.isCompleted ? Icons.check_circle_rounded : Icons.content_cut_rounded,
            size: 15,
            color: stubColor.withValues(alpha: 0.7),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggleExpand,
      onLongPress: _completeViaTear,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _tear,
        builder: (context, child) {
          final torn = Curves.easeInOutCubic.transform(_tear.value);
          final dy = 46 * torn + liveDrag;
          final rot = (-10 * math.pi / 180) * torn;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: rot,
              alignment: Alignment.topCenter,
              child: Opacity(opacity: (1 - 0.25 * torn).clamp(0.0, 1.0), child: child),
            ),
          );
        },
        child: stub,
      ),
    );
  }

  Widget _buildBody(ThemeData theme, AppText t, Color stubColor, bool isDark) {
    final task = widget.task;
    final displayTitle = task.template == 'meeting' ? t.meetingTitle(task.title)
        : task.template == 'travel' ? t.travelTitle(task.title)
        : task.template == 'gift' ? t.giftTitle(task.title)
        : task.template == 'birthday' ? t.birthdayTitle(task.title)
        : task.title;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggleExpand,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Ред 1: заглавие + приоритет + chevron ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayTitle,
                      maxLines: widget.isExpanded ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        // Заглавието е в неутрален текстов цвят — категорийният цвят
                        // живее на отрязъка, не на текста.
                        color: widget.isCompleted
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : theme.colorScheme.onSurface,
                        decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
                        decorationColor: stubColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.priority > 0) ...[
                        _PriorityDots(count: task.priority + 1, color: widget.priorityColor),
                        const SizedBox(height: 5),
                      ],
                      AnimatedRotation(
                        turns: widget.isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 280),
                        child: Icon(Icons.keyboard_arrow_down_rounded, size: 18,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ─── Ред 2: мета ───
              Wrap(
                spacing: 10, runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.categoryName.isNotEmpty)
                    _MiniPill(icon: Icons.circle, text: widget.categoryName, color: stubColor),
                  if (widget.recurrenceText != null && widget.recurrenceText!.isNotEmpty)
                    _MiniPill(icon: Icons.repeat_rounded, text: widget.recurrenceText!, color: muted),
                  if (task.hasReminders)
                    Icon(Icons.notifications_active_rounded, size: 13, color: Colors.amber.withValues(alpha: 0.85)),
                  if (task.googleCalendarEventId != null)
                    Icon(Icons.event_rounded, size: 13, color: Colors.blue.withValues(alpha: 0.7)),
                  if (task.hasNotes)
                    Icon(Icons.sticky_note_2_outlined, size: 13, color: muted),
                ],
              ),
              // Възраст за рождени дни (както класическата карта)
              if ((task.template == 'birthday' || task.categoryId == 'birthday') &&
                  ExpandableTaskCard._birthdayAge(task, t) != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.cake_rounded, size: 12, color: stubColor.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        ExpandableTaskCard._birthdayAge(task, t)!,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: stubColor.withValues(alpha: 0.9)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // ─── Ред 3: подзадачи (свито) ───
              if (task.totalSubtasksCount > 0 && !widget.isExpanded) ...[
                const SizedBox(height: 6),
                _TicketSubtasks(
                  completed: task.completedSubtasksCount,
                  total: task.totalSubtasksCount,
                  color: stubColor,
                ),
              ],
              // ─── EXPAND ───
              if (widget.isExpanded) ..._buildExpanded(theme, t, stubColor, isDark),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpanded(ThemeData theme, AppText t, Color stubColor, bool isDark) {
    final task = widget.task;
    return [
      const SizedBox(height: 10),
      Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            stubColor.withValues(alpha: isDark ? 0.35 : 0.2),
            stubColor.withValues(alpha: 0.0),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (task.hasNotes) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ExpandableTaskCard._notesPreview(task.notes!, t, task.dueDate.year),
                  style: TextStyle(fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55), height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          _DetailChip(
            icon: Icons.schedule_rounded, label: widget.dateTimeStr,
            color: widget.isOverdue && !widget.isCompleted ? Colors.redAccent : null),
          _DetailChip(
            icon: task.priority == 2
                ? Icons.local_fire_department_rounded
                : task.priority == 1 ? Icons.flag_rounded : Icons.flag_outlined,
            label: widget.priorityText, color: widget.priorityColor),
          if (widget.categoryName.isNotEmpty)
            _DetailChip(icon: Icons.circle, iconSize: 8, label: widget.categoryName, color: stubColor),
          if (widget.recurrenceText != null && widget.recurrenceText!.isNotEmpty)
            _DetailChip(icon: Icons.repeat_rounded, label: widget.recurrenceText!),
          if (task.hasReminders)
            _DetailChip(icon: Icons.notifications_active_rounded, label: t.reminder, color: Colors.amber.shade700),
          if (task.googleCalendarEventId != null)
            const _DetailChip(icon: Icons.event_rounded, label: 'Calendar', color: Colors.blue),
        ],
      ),
      // „Изпрати цветя/подарък" за рождени дни (монетизация).
      if ((task.template == 'birthday' || task.categoryId == 'birthday')
          && !widget.isCompleted) ...[
        const SizedBox(height: 10),
        GiftOfferButton(lang: t.lang, kind: 'gift_birthday'),
      ],
      if (task.totalSubtasksCount > 0) ...[
        const SizedBox(height: 10),
        _SubtaskProgress(
          completed: task.completedSubtasksCount,
          total: task.totalSubtasksCount,
          color: theme.colorScheme.primary,
        ),
        if (widget.onToggleSubtask != null) ...[
          const SizedBox(height: 6),
          _SubtaskChecklist(
            task: task,
            color: theme.colorScheme.primary,
            onToggle: widget.onToggleSubtask!,
          ),
        ],
      ],
      const SizedBox(height: 10),
      if (widget.onBreakdown != null && !widget.isCompleted && task.totalSubtasksCount == 0) ...[
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            icon: Icons.auto_awesome, label: t.aiBreakdownAction,
            color: Colors.deepPurple, onTap: widget.onBreakdown!, expand: true),
        ),
        const SizedBox(height: 6),
      ],
      if (widget.onStartPomodoro != null && !widget.isCompleted) ...[
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            icon: Icons.timer_outlined, label: t.pomodoroFocus,
            color: Colors.deepOrange, onTap: widget.onStartPomodoro!, expand: true),
        ),
        const SizedBox(height: 6),
      ],
      // Готово/Възстанови — пълна ширина (основното действие; тялото на билета е
      // по-тясно заради отрязъка, затова не слагаме 3 бутона на един ред — режеше се).
      SizedBox(
        width: double.infinity,
        child: _ActionButton(
          icon: widget.isCompleted ? Icons.undo_rounded : Icons.check_rounded,
          label: widget.isCompleted ? t.restore : t.done,
          color: widget.isCompleted ? Colors.blueGrey : Colors.green,
          onTap: _completeViaTear, expand: true),
      ),
      const SizedBox(height: 6),
      // Редакция + Изтрий — две на ред (текстът се събира на половин ширина)
      Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.edit_outlined, label: t.edit,
              color: theme.colorScheme.primary, onTap: widget.onEdit, expand: true),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionButton(
              icon: Icons.delete_outline_rounded, label: t.delete,
              color: Colors.redAccent, onTap: widget.onDelete, expand: true),
          ),
        ],
      ),
    ];
  }
}

/// 1-3 приоритетни точки в редичка
class _PriorityDots extends StatelessWidget {
  final int count;
  final Color color;
  const _PriorityDots({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(1, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(n, (i) => Padding(
        padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
        child: Container(width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      )),
    );
  }
}

/// Подзадачи свито: до 5 — кръгчета (●●○), иначе тънка лента + n/m
class _TicketSubtasks extends StatelessWidget {
  final int completed;
  final int total;
  final Color color;
  const _TicketSubtasks({required this.completed, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDone = completed >= total;
    final c = isDone ? Colors.green : color;
    if (total <= 5) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(total, (i) => Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              i < completed ? Icons.circle : Icons.circle_outlined,
              size: 9, color: c.withValues(alpha: i < completed ? 0.85 : 0.4),
            ),
          )),
          const SizedBox(width: 5),
          Text('$completed/$total',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.withValues(alpha: 0.8))),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              backgroundColor: c.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(c.withValues(alpha: 0.7)),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$completed/$total',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.withValues(alpha: 0.8))),
      ],
    );
  }
}

/// Перфорация: вертикален пунктир + полукръгли изрези горе/долу
class _PerforationPainter extends CustomPainter {
  final Color dashColor;
  final Color notchColor;
  _PerforationPainter({required this.dashColor, required this.notchColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const notchR = 5.0;

    // Полукръгли изрези (горе и долу), в цвета на фона зад картата
    final notchPaint = Paint()..color = notchColor..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, 0), notchR, notchPaint);
    canvas.drawCircle(Offset(cx, size.height), notchR, notchPaint);

    // Пунктирана линия между изрезите
    final dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 3.0, gap = 4.0;
    double y = notchR + 3;
    final end = size.height - notchR - 3;
    while (y < end) {
      final y2 = (y + dash).clamp(0.0, end);
      canvas.drawLine(Offset(cx, y), Offset(cx, y2), dashPaint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.dashColor != dashColor || old.notchColor != notchColor;
}
