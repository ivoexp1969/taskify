import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/morning_briefing_service.dart';
import '../utils/localization.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class MorningBriefingDialog {
  static Future<void> show(BuildContext context) async {
    final briefingService = MorningBriefingService();
    final topTasks = await briefingService.getTopTasksForToday();
    
    if (!context.mounted) return;
    
    final lang = AppText.of(context).lang;
    await initializeDateFormatting(lang);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BriefingSheet(tasks: topTasks),
    );
  }
}

class _BriefingSheet extends StatelessWidget {
  final List<Task> tasks;
  
  const _BriefingSheet({required this.tasks});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_rounded,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.greetingForHour(DateTime.now().hour),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, d MMMM', t.lang).format(DateTime.now()),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Tasks list
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.noTasksToday,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.enjoyYourDay,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final task = tasks[index];
                final dueDate = task.dueDate;
                final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
                
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOverdue 
                        ? Colors.red.withValues(alpha: 0.3)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.priority).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: _getPriorityColor(task.priority),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: dueDate != null ? Row(
                      children: [
                        Icon(
                          isOverdue ? Icons.warning : Icons.schedule,
                          size: 14,
                          color: isOverdue ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOverdue 
                            ? t.overdue
                            : DateFormat('d MMM, HH:mm', t.lang).format(dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ) : null,
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onTap: () => Navigator.pop(ctx),
                  ),
                );
              },
            ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 2: return Colors.red;
      case 1: return Colors.orange;
      default: return Colors.blue;
    }
  }
}
