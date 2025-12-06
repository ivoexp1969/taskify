import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with WidgetsBindingObserver {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasks');
    categoryBox = Hive.box<Category>('categories');
    WidgetsBinding.instance.addObserver(this);
    
    // Слушаме за промени в taskBox
    taskBox.listenable().addListener(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    taskBox.listenable().removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  // Помощни методи за изчисления
  int _completedInPeriod(DateTime start, DateTime end) {
    return taskBox.values.where((t) {
      if (!t.isCompleted) return false;
      // Използваме completedAt ако има, иначе dueDate
      final completedDate = t.completedAt ?? t.dueDate;
      return completedDate.isAfter(start) && completedDate.isBefore(end);
    }).length;
  }

  int _totalInPeriod(DateTime start, DateTime end) {
    return taskBox.values.where((t) {
      final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return !due.isBefore(start) && due.isBefore(end);
    }).length;
  }

  int _calculateStreak() {
    final now = DateTime.now();
    int streak = 0;
    
    for (int i = 0; i < 365; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      
      final completedOnDay = taskBox.values.where((t) {
        if (!t.isCompleted) return false;
        // Използваме completedAt ако има, иначе dueDate
        final completedDate = t.completedAt ?? t.dueDate;
        return completedDate.isAfter(day) && completedDate.isBefore(nextDay);
      }).length;
      
      if (completedOnDay > 0) {
        streak++;
      } else if (i > 0) {
        // Ако днес няма завършени, не прекъсваме веднага
        break;
      }
    }
    
    return streak;
  }

  int _mostProductiveDay() {
    final counts = List.filled(7, 0);
    
    for (final task in taskBox.values) {
      if (task.isCompleted) {
        // Използваме completedAt ако има, иначе dueDate
        final completedDate = task.completedAt ?? task.dueDate;
        counts[completedDate.weekday - 1]++;
      }
    }
    
    int maxIndex = 0;
    for (int i = 1; i < 7; i++) {
      if (counts[i] > counts[maxIndex]) {
        maxIndex = i;
      }
    }
    
    return maxIndex;
  }

  Map<String, int> _tasksByCategory() {
    final result = <String, int>{};
    
    for (final task in taskBox.values.where((t) => t.isCompleted)) {
      result[task.categoryId] = (result[task.categoryId] ?? 0) + 1;
    }
    
    return result;
  }

  String _dayName(int index, bool isBg) {
    final bgDays = ['Понеделник', 'Вторник', 'Сряда', 'Четвъртък', 'Петък', 'Събота', 'Неделя'];
    final enDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return isBg ? bgDays[index] : enDays[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final completedToday = _completedInPeriod(todayStart, todayEnd);
    final completedWeek = _completedInPeriod(weekStart, weekEnd);
    final completedMonth = _completedInPeriod(monthStart, monthEnd);
    
    final totalTasks = taskBox.length;
    final completedTotal = taskBox.values.where((t) => t.isCompleted).length;
    final completionRate = totalTasks > 0 ? (completedTotal / totalTasks * 100).round() : 0;
    
    final streak = _calculateStreak();
    final productiveDay = _mostProductiveDay();
    final byCategory = _tasksByCategory();

    return Scaffold(
      appBar: AppBar(
        title: Text(isBg ? 'Статистики' : 'Statistics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Обобщение
          Text(
            isBg ? 'Обобщение' : 'Summary',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.today_rounded,
                  iconColor: Colors.blue,
                  value: '$completedToday',
                  label: isBg ? 'Днес' : 'Today',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.date_range_rounded,
                  iconColor: Colors.green,
                  value: '$completedWeek',
                  label: isBg ? 'Седмица' : 'Week',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_month_rounded,
                  iconColor: Colors.orange,
                  value: '$completedMonth',
                  label: isBg ? 'Месец' : 'Month',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Прогрес
          Text(
            isBg ? 'Прогрес' : 'Progress',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Кръгова диаграма
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: completionRate / 100,
                          strokeWidth: 10,
                          backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(
                            completionRate >= 75
                                ? Colors.green
                                : completionRate >= 50
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                        Text(
                          '$completionRate%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBg ? 'Изпълнение' : 'Completion rate',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isBg
                              ? '$completedTotal от $totalTasks задачи'
                              : '$completedTotal of $totalTasks tasks',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Streak и продуктивен ден
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 32,
                          color: streak > 0 ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$streak',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isBg ? 'дни streak' : 'day streak',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 32,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dayName(productiveDay, isBg),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          isBg ? 'най-продуктивен' : 'most productive',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // По категории
          if (byCategory.isNotEmpty) ...[
            Text(
              isBg ? 'По категории' : 'By category',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: byCategory.entries.map((entry) {
                            final cat = categoryBox.values.firstWhere(
                              (c) => c.id == entry.key,
                              orElse: () => Category(
                                id: '',
                                name: isBg ? 'Друго' : 'Other',
                                colorValue: Colors.grey.value,
                              ),
                            );
                            return PieChartSectionData(
                              value: entry.value.toDouble(),
                              title: '${entry.value}',
                              color: Color(cat.colorValue),
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: byCategory.entries.map((entry) {
                        final cat = categoryBox.values.firstWhere(
                          (c) => c.id == entry.key,
                          orElse: () => Category(
                            id: '',
                            name: isBg ? 'Друго' : 'Other',
                            colorValue: Colors.grey.value,
                          ),
                        );
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(cat.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Седмична активност
          Text(
            isBg ? 'Последните 7 дни' : 'Last 7 days',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final day = DateTime.now().subtract(
                              Duration(days: 6 - value.toInt()),
                            );
                            final labels = isBg
                                ? ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд']
                                : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                            return Text(
                              labels[day.weekday - 1],
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: List.generate(7, (index) {
                      final day = DateTime.now().subtract(
                        Duration(days: 6 - index),
                      );
                      final dayStart = DateTime(day.year, day.month, day.day);
                      final dayEnd = dayStart.add(const Duration(days: 1));
                      final count = _completedInPeriod(dayStart, dayEnd);
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: count.toDouble(),
                            color: theme.colorScheme.primary,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}