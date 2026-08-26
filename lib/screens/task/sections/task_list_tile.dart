import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../models/task.dart';
import '../../../models/category.dart';
import '../../../utils/localization.dart';
import '../../../services/google_calendar_service.dart';
import '../../../services/ios_calendar_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/tombstone_service.dart';
import '../../../services/widget_service.dart';
import '../../../services/ad_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/conversion_service.dart';
import '../../../services/review_service.dart';
import '../../../widgets/task_card_styles.dart';
import '../../../widgets/pomodoro_timer_sheet.dart';
import '../shopping_list_screen.dart';
import '../birthday_dialog.dart';
import '../meeting_dialog.dart';
import '../workout_dialog.dart';
import '../payment_dialog.dart';
import '../travel_dialog.dart';
import '../gift_dialog.dart';
import '../document_dialog.dart';
import '../dialogs/ai_breakdown_sheet.dart';

/// Следваща дата на повтаряща се задача. Изнесено от `task_screen.dart`
/// (чиста функция).
DateTime nextDueDate(DateTime current, String recurrence) {
  switch (recurrence) {
    case 'daily':
      return current.add(const Duration(days: 1));
    case 'weekly':
      return current.add(const Duration(days: 7));
    case 'monthly':
      return DateTime(
        current.year,
        current.month + 1,
        current.day,
        current.hour,
        current.minute,
      );
    case 'yearly':
      return DateTime(
        current.year + 1,
        current.month,
        current.day,
        current.hour,
        current.minute,
      );
    default:
      return current;
  }
}

/// Един ред от списъка с лични задачи (swipe-действия + карта + меню).
/// Изнесено verbatim от `task_screen.dart` build() itemBuilder.
///
/// State-обвързаните части се подават като callbacks: [onChanged] (= setState),
/// [onToggleExpand] (разгъване/свиване), [onOpenFullEditor] (пълен редактор на
/// задачата), [onCelebrate] (конфети overlay на екрана).
class TaskListTile extends StatelessWidget {
  const TaskListTile({
    super.key,
    required this.task,
    required this.category,
    required this.index,
    required this.isOverdue,
    required this.isCompleted,
    required this.isExpanded,
    required this.taskBox,
    required this.categoryBox,
    required this.dateTimeStr,
    required this.priorityText,
    required this.priorityColor,
    required this.accentColor,
    required this.categoryName,
    required this.recurrenceText,
    required this.onChanged,
    required this.onToggleExpand,
    required this.onOpenFullEditor,
    required this.onCelebrate,
  });

  final Task task;
  final Category? category;
  final int index;
  final bool isOverdue;
  final bool isCompleted;
  final bool isExpanded;
  final Box<Task> taskBox;
  final Box<Category> categoryBox;
  final String dateTimeStr;
  final String priorityText;
  final Color priorityColor;
  final Color accentColor;
  final String categoryName;
  final String? recurrenceText;
  final VoidCallback onChanged;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpenFullEditor;
  final VoidCallback onCelebrate;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final cat = category;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 30).clamp(0, 150)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Dismissible(
      key: Key(task.key.toString()),
      // Swipe надясно - завършване
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCompleted
                ? [Colors.blueGrey.shade400, Colors.blueGrey.shade600]
                : [Colors.green.shade400, Colors.green.shade600],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.undo_rounded : Icons.check_rounded,
                color: Colors.white, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isCompleted ? t.restore : t.done,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      // Swipe наляво - изтриване
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade700],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              t.delete,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe надясно - toggle complete
          final wasCompleted = task.isCompleted;
          task.isCompleted = !task.isCompleted;
          task.completedAt = task.isCompleted ? DateTime.now() : null;
          await task.save();
          if (task.isCompleted) AdService().onUserAction();
          if (!wasCompleted && task.isCompleted) {
            AnalyticsService().logTaskCompleted();
          }
          if (task.isCompleted && context.mounted) {
            ConversionService.instance.onTaskCompleted(context);
          }

          if (!wasCompleted && task.isCompleted && task.recurrence != null) {
            final nextDate = nextDueDate(task.dueDate, task.recurrence!);
            final newTask = Task(
              title: task.title,
              dueDate: nextDate,
              categoryId: task.categoryId,
              priority: task.priority,
              recurrence: task.recurrence,
              reminders: task.reminders,
              template: task.template,
              notes: task.notes,
              subtasks: task.subtasks?.map((s) {
                final parts = s.split(':');
                return parts.length >= 2 ? '0:${parts.sublist(1).join(':')}' : s;
              }).toList(),
            );
            await taskBox.add(newTask);
            AnalyticsService().logTaskCreated(newTask);
      // Google Calendar sync (само ако Apple не е активен —
      // източниците са взаимно изключващи се).
      if (GoogleCalendarService().isConnected && !IosCalendarService.exportEnabled) {
        final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
        if (eventId != null) {
          newTask.googleCalendarEventId = eventId;
          await newTask.save();
        }
      }
      // Apple Calendar (export-only) — само ако е избран
      // Apple източник (взаимно изключващ се с Google).
      if (!kIsWeb && IosCalendarService.exportEnabled) {
        await IosCalendarService().syncTask(newTask);
      }

            await NotificationService().scheduleForTask(newTask);
          }

          if (task.isCompleted) {
            await NotificationService().cancelForTask(task);
          } else if (task.hasReminders) {
            await NotificationService().scheduleForTask(task);
          }

          await WidgetService.updateWidget();
          onChanged();

          // Проверка за празнуване
          if (!wasCompleted && task.isCompleted) {
            onCelebrate();
            ReviewService().onTaskCompleted(context);
          }
          return false; // Не изтриваме, само toggle-ваме
        } else {
          // Swipe наляво - изтриване с потвърждение
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(t.deletion),
              content: Text(t.deleteTaskMessage(task.title)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: Text(t.delete),
                ),
              ],
            ),
          );
          return confirm ?? false;
        }
      },
      onDismissed: (direction) async {
        // Само за изтриване (swipe наляво)
        await NotificationService().cancelForTask(task);
        await TombstoneService().deleteTask(task);
        await WidgetService.updateWidget();
        onChanged();
      },
      child: GestureDetector(
      onTap: () {
        // Shopping List специален екран
        if (task.categoryId == 'shopping' || task.template == 'shopping') {
          ShoppingListScreen.show(context, task).then((_) => onChanged());
          return;
        }
        // Edit диалог по тип
        if (task.template == 'birthday' || task.categoryId == 'birthday') { BirthdayDialog.show(context, existing: task).then((_) => onChanged()); return; }
        if (task.template == 'meeting') { MeetingDialog.show(context, existing: task).then((_) => onChanged()); return; }
        if (task.template == 'workout') { WorkoutDialog.show(context, existing: task).then((_) => onChanged()); return; }
        if (task.template == 'payment') { PaymentDialog.show(context, existing: task).then((_) => onChanged()); return; }
        if (task.template == 'travel') { TravelDialog.show(context, existing: task).then((_) => onChanged()); return; }
        if (task.template == 'gift') { GiftDialog.show(context, existing: task).then((_) => onChanged()); return; }
        if (task.template == 'document') { DocumentDialog.show(context, existing: task).then((_) => onChanged()); return; }
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(t.edit),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (task.categoryId == 'shopping' || task.template == 'shopping') {
                      ShoppingListScreen.show(context, task).then((_) => onChanged());
                    } else {
                      onOpenFullEditor();
                    }
                  },
                ),
                if (!task.isArchived)
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(t.archive),
                    onTap: () async {
                      Navigator.pop(ctx);
                      task.isArchived = true;
                      task.archivedAt = DateTime.now();
                      await task.save();
                      await WidgetService.updateWidget();
                      onChanged();
                    },
                  ),
                if (task.isArchived)
                  ListTile(
                    leading: const Icon(Icons.unarchive_outlined),
                    title: Text(t.unarchive),
                    onTap: () async {
                      Navigator.pop(ctx);
                      task.isArchived = false;
                      task.archivedAt = null;
                      await task.save();
                      await WidgetService.updateWidget();
                      onChanged();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    t.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await NotificationService().cancelForTask(task);
                    await TombstoneService().deleteTask(task);
                    await WidgetService.updateWidget();
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: TaskCardView(
            task: task,
            category: cat,
            isOverdue: isOverdue,
            isCompleted: isCompleted,
            isExpanded: isExpanded,
            onToggleExpand: onToggleExpand,
            onToggleComplete: () async {
              final wasCompleted = task.isCompleted;
              task.isCompleted = !task.isCompleted;
              onChanged();
              await task.save();
              if (!wasCompleted && task.isCompleted) AdService().onUserAction();
              if (!wasCompleted && task.isCompleted) {
                AnalyticsService().logTaskCompleted();
              }
              if (!wasCompleted && task.isCompleted && context.mounted) {
                ConversionService.instance.onTaskCompleted(context);
              }

              if (!wasCompleted && task.isCompleted && task.recurrence != null) {
                final nextDate = nextDueDate(task.dueDate, task.recurrence!);
                final newTask = Task(
                  title: task.title,
                  dueDate: nextDate,
                  categoryId: task.categoryId,
                  priority: task.priority,
                  recurrence: task.recurrence,
                  reminders: task.reminders,
                  template: task.template,
                  notes: task.notes,
                  subtasks: task.subtasks?.map((s) {
                    final parts = s.split(':');
                    return parts.length >= 2 ? '0:${parts.sublist(1).join(':')}' : s;
                  }).toList(),
                );
                await taskBox.add(newTask);
                AnalyticsService().logTaskCreated(newTask);
      // Google Calendar sync (само ако Apple не е активен —
      // източниците са взаимно изключващи се).
      if (GoogleCalendarService().isConnected && !IosCalendarService.exportEnabled) {
        final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
        if (eventId != null) {
          newTask.googleCalendarEventId = eventId;
          await newTask.save();
        }
      }
      // Apple Calendar (export-only) — само ако е избран
      // Apple източник (взаимно изключващ се с Google).
      if (!kIsWeb && IosCalendarService.exportEnabled) {
        await IosCalendarService().syncTask(newTask);
      }

                await NotificationService().scheduleForTask(newTask);
              }

              if (task.isCompleted) {
                await NotificationService().cancelForTask(task);
              } else if (task.hasReminders) {
                await NotificationService().scheduleForTask(task);
              }

              await WidgetService.updateWidget();
              onChanged();

              if (!wasCompleted && task.isCompleted) {
                onCelebrate();
                ReviewService().onTaskCompleted(context);
              }
            },
            onEdit: () {
              if (task.categoryId == 'shopping' || task.template == 'shopping') {
                ShoppingListScreen.show(context, task).then((_) => onChanged());
              } else if (task.template == 'birthday' || task.categoryId == 'birthday') {
                BirthdayDialog.show(context, existing: task).then((_) => onChanged());
              } else if (task.template == 'meeting') {
                MeetingDialog.show(context, existing: task).then((_) => onChanged());
              } else if (task.template == 'workout') {
                WorkoutDialog.show(context, existing: task).then((_) => onChanged());
              } else if (task.template == 'payment') {
                PaymentDialog.show(context, existing: task).then((_) => onChanged());
              } else if (task.template == 'travel') {
                TravelDialog.show(context, existing: task).then((_) => onChanged());
              } else if (task.template == 'gift') {
                GiftDialog.show(context, existing: task).then((_) => onChanged());
              } else if (task.template == 'document') {
                DocumentDialog.show(context, existing: task).then((_) => onChanged());
              } else {
                onOpenFullEditor();
              }
            },
            onDelete: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(t.deletion),
                  content: Text(t.deleteTaskMessage(task.title)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(t.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      child: Text(t.delete),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await NotificationService().cancelForTask(task);
                await TombstoneService().deleteTask(task);
                await WidgetService.updateWidget();
                onChanged();
              }
            },
            onStartPomodoro: () => PomodoroTimerSheet.show(context, task),
            onBreakdown: () => showAiBreakdownSheet(
                context, task, categoryBox,
                onApplied: onChanged),
            onToggleSubtask: (index) async {
              final list = task.subtasksList;
              if (index < 0 || index >= list.length) return;
              list[index]['done'] =
                  !(list[index]['done'] == true);
              task.setSubtasks(list);
              // Всички подзадачи готови → задачата се
              // завършва автоматично (и обратно).
              task.syncCompletionWithSubtasks();
              task.touch();
              await task.save();
              await WidgetService.updateWidget();
              if (context.mounted) onChanged();
            },
            dateTimeStr: dateTimeStr,
            priorityText: priorityText,
            priorityColor: priorityColor,
            accentColor: accentColor,
            categoryName: categoryName,
            recurrenceText: recurrenceText,
          ),
    ), // Dismissible
    ), // TweenAnimationBuilder
    );
  }
}
