import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../models/task.dart';
import '../../../utils/localization.dart';
import '../../settings/statistics_screen.dart';

/// Лента „продуктивност" най-горе в списъка със задачи: серия (streak) + днешен
/// резултат. Изнесено от `task_screen.dart` без промяна на поведение.
class ProductivityBanner extends StatefulWidget {
  final Box<Task> taskBox;
  const ProductivityBanner({super.key, required this.taskBox});
  @override
  State<ProductivityBanner> createState() => _ProductivityBannerState();
}

class _ProductivityBannerState extends State<ProductivityBanner> {
  int? _cachedStreak;
  String? _cacheDate;

  int _calculateStreak() {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';
    if (_cacheDate == dateKey && _cachedStreak != null) return _cachedStreak!;

    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final completedOnDay = widget.taskBox.values.where((t) {
        if (!t.isCompleted) return false;
        final d = t.completedAt ?? t.dueDate;
        return d.isAfter(day) && d.isBefore(nextDay);
      }).length;
      if (completedOnDay > 0) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    _cachedStreak = streak;
    _cacheDate = dateKey;
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = widget.taskBox.values.where((task) {
      if (task.isArchived) return false;
      final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return due == today;
    }).toList();

    final completedToday = todayTasks.where((task) => task.isCompleted).length;
    final totalToday = todayTasks.length;
    final score = totalToday > 0 ? completedToday / totalToday : 0.0;
    final streak = _calculateStreak();

    if (streak == 0 && totalToday == 0) return const SizedBox.shrink();

    final scoreColor = score >= 1.0 ? Colors.green : (score >= 0.5 ? Colors.orange : theme.colorScheme.primary);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StatisticsScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              theme.colorScheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Streak
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        streak > 0 ? '🔥' : '💤',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$streak',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.streakDays,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Separator
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: 1,
              height: 24,
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),

            // Today's score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          t.todayScore,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        totalToday > 0 ? '$completedToday / $totalToday' : '—',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}
