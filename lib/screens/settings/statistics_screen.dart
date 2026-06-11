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
  int _periodDays = 7;

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

  String _periodTitle(int days, String lang) {
    if (days == 7) {
      const m = {'en': 'Last 7 days', 'bg': 'Последните 7 дни', 'de': 'Letzte 7 Tage', 'fr': '7 derniers jours', 'it': 'Ultimi 7 giorni', 'el': 'Τελευταίες 7 μέρες', 'es': 'Últimos 7 días', 'pt': 'Últimos 7 dias', 'ru': 'Последние 7 дней', 'tr': 'Son 7 gün', 'ja': '過去7日'};
      return m[lang] ?? m['en']!;
    }
    if (days == 30) {
      const m = {'en': 'Last 30 days', 'bg': 'Последните 30 дни', 'de': 'Letzte 30 Tage', 'fr': '30 derniers jours', 'it': 'Ultimi 30 giorni', 'el': 'Τελευταίες 30 μέρες', 'es': 'Últimos 30 días', 'pt': 'Últimos 30 dias', 'ru': 'Последние 30 дней', 'tr': 'Son 30 gün', 'ja': '過去30日'};
      return m[lang] ?? m['en']!;
    }
    const m = {'en': 'Last 3 months', 'bg': 'Последните 3 месеца', 'de': 'Letzte 3 Monate', 'fr': '3 derniers mois', 'it': 'Ultimi 3 mesi', 'el': 'Τελευταίοι 3 μήνες', 'es': 'Últimos 3 meses', 'pt': 'Últimos 3 meses', 'ru': 'Последние 3 месяца', 'tr': 'Son 3 ay', 'ja': '過去3か月'};
    return m[lang] ?? m['en']!;
  }

  Widget _buildBarChart(ThemeData theme, String lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_periodDays == 7) {
      const dayLabels = {
        'en': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        'bg': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
        'de': ['M', 'D', 'M', 'D', 'F', 'S', 'S'],
        'fr': ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
        'it': ['L', 'M', 'M', 'G', 'V', 'S', 'D'],
        'el': ['Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ', 'Κ'],
        'es': ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
        'pt': ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'],
        'ru': ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'],
        'tr': ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'],
      };
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final day = today.subtract(Duration(days: 6 - value.toInt()));
                  final labels = dayLabels[lang] ?? dayLabels['en']!;
                  return Text(
                    labels[day.weekday - 1],
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(7, (index) {
            final dayStart = today.subtract(Duration(days: 6 - index));
            final dayEnd = dayStart.add(const Duration(days: 1));
            final count = _completedInPeriod(dayStart, dayEnd);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: theme.colorScheme.primary,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }),
        ),
      );
    } else if (_periodDays == 30) {
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx % 7 != 0 && idx != 29) return const SizedBox.shrink();
                  final day = today.subtract(Duration(days: 29 - idx));
                  return Text(
                    '${day.day}',
                    style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(30, (index) {
            final dayStart = today.subtract(Duration(days: 29 - index));
            final dayEnd = dayStart.add(const Duration(days: 1));
            final count = _completedInPeriod(dayStart, dayEnd);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: theme.colorScheme.primary,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            );
          }),
        ),
      );
    } else {
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  final daysFromEnd = (12 - i) * 7;
                  final weekEnd = today.subtract(Duration(days: daysFromEnd)).add(const Duration(days: 1));
                  final weekStart = weekEnd.subtract(const Duration(days: 7));
                  return Text(
                    '${weekStart.day}/${weekStart.month}',
                    style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(13, (i) {
            final daysFromEnd = (12 - i) * 7;
            final weekEnd = today.subtract(Duration(days: daysFromEnd)).add(const Duration(days: 1));
            final weekStart = weekEnd.subtract(const Duration(days: 7));
            final count = _completedInPeriod(weekStart, weekEnd);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: theme.colorScheme.primary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      );
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

  String _dayName(int index, String lang) {
    const days = {
      'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'bg': ['Понеделник', 'Вторник', 'Сряда', 'Четвъртък', 'Петък', 'Събота', 'Неделя'],
      'de': ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
      'fr': ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
      'it': ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'],
      'el': ['Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'],
      'es': ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
      'pt': ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'],
      'ru': ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
      'tr': ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'],
    };
    return (days[lang] ?? days['en']!)[index];
  }

  /// Връща локализирано име за категория
  String _localizedCategoryName(Category? c, String lang) {
    if (c == null) {
      return {
        'en': 'Other',
        'bg': 'Друго',
        'de': 'Andere',
        'fr': 'Autre',
        'it': 'Altro',
        'el': 'Άλλο',
        'es': 'Otro',
        'pt': 'Outro',
        'ru': 'Другое',
        'tr': 'Diğer', 'ja': 'その他',
      }[lang] ?? 'Other';
    }
    // Календарната категория не е „default", но id-то е фиксирано → локализира се винаги.
    if (c.id == 'cal_events') {
      return {'en': 'Calendar Events', 'bg': 'Календарни събития', 'de': 'Kalendereinträge', 'fr': 'Événements du calendrier', 'it': 'Eventi del calendario', 'el': 'Εκδηλώσεις ημερολογίου', 'es': 'Eventos del calendario', 'pt': 'Eventos do calendário', 'ru': 'События календаря', 'tr': 'Takvim etkinlikleri', 'ja': 'カレンダーのイベント'}[lang] ?? 'Calendar Events';
    }
    if (c.isDefault) {
      final translations = {
        'work': {'en': 'Work', 'bg': 'Работа', 'de': 'Arbeit', 'fr': 'Travail', 'it': 'Lavoro', 'el': 'Εργασία', 'es': 'Trabajo', 'pt': 'Trabalho', 'ru': 'Работа', 'tr': 'İş', 'ja': '仕事'},
        'personal': {'en': 'Personal', 'bg': 'Лични', 'de': 'Persönlich', 'fr': 'Personnel', 'it': 'Personale', 'el': 'Προσωπικά', 'es': 'Personal', 'pt': 'Pessoal', 'ru': 'Личное', 'tr': 'Kişisel', 'ja': '個人'},
        'shopping': {'en': 'Shopping', 'bg': 'Пазаруване', 'de': 'Einkaufen', 'fr': 'Courses', 'it': 'Spesa', 'el': 'Αγορές', 'es': 'Compras', 'pt': 'Compras', 'ru': 'Покупки', 'tr': 'Alışveriş', 'ja': '買い物'},
        'birthday': {'en': 'Birthday', 'bg': 'Рождени дни', 'de': 'Geburtstag', 'fr': 'Anniversaire', 'it': 'Compleanno', 'el': 'Γενέθλια', 'es': 'Cumpleaños', 'pt': 'Aniversário', 'ru': 'День рождения', 'tr': 'Doğum günü', 'ja': '誕生日'},
        'meeting': {'en': 'Meeting', 'bg': 'Срещи', 'de': 'Besprechung', 'fr': 'Réunion', 'it': 'Riunione', 'el': 'Συνάντηση', 'es': 'Reunión', 'pt': 'Reunião', 'ru': 'Встреча', 'tr': 'Toplantı', 'ja': '会議'},
        'workout': {'en': 'Workout', 'bg': 'Тренировка', 'de': 'Training', 'fr': 'Entraînement', 'it': 'Allenamento', 'el': 'Άσκηση', 'es': 'Entrenamiento', 'pt': 'Treino', 'ru': 'Тренировка', 'tr': 'Egzersiz', 'ja': 'ワークアウト'},
        'payment': {'en': 'Payment', 'bg': 'Плащания', 'de': 'Zahlung', 'fr': 'Paiement', 'it': 'Pagamento', 'el': 'Πληρωμή', 'es': 'Pago', 'pt': 'Pagamento', 'ru': 'Платёж', 'tr': 'Ödeme', 'ja': '支払い'},
        'travel': {'en': 'Travel', 'bg': 'Пътувания', 'de': 'Reise', 'fr': 'Voyage', 'it': 'Viaggio', 'el': 'Ταξίδι', 'es': 'Viaje', 'pt': 'Viagem', 'ru': 'Путешествие', 'tr': 'Seyahat', 'ja': '旅行'},
        'gift': {'en': 'Gift', 'bg': 'Подаръци', 'de': 'Geschenk', 'fr': 'Cadeau', 'it': 'Regalo', 'el': 'Δώρο', 'es': 'Regalo', 'pt': 'Presente', 'ru': 'Подарок', 'tr': 'Hediye', 'ja': 'ギフト'},
      };
      return translations[c.id]?[lang] ?? translations[c.id]?['en'] ?? c.name;
    }
    return c.name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);
    final languageController = LanguageScope.of(context);
    final lang = languageController.locale.languageCode;

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
        title: Text(t.statistics),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Обобщение
          Text(
            t.summary,
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
                  label: t.today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.date_range_rounded,
                  iconColor: Colors.green,
                  value: '$completedWeek',
                  label: t.week,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_month_rounded,
                  iconColor: Colors.orange,
                  value: '$completedMonth',
                  label: t.month,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Прогрес
          Text(
            t.progress,
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
                          backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
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
                          t.completionRate,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.tasksOfTotal(completedTotal, totalTasks),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                          t.dayStreak,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                          _dayName(productiveDay, lang),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          t.mostProductive,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
              t.byCategory,
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
                                name: t.other,
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
                            name: t.other,
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
                              _localizedCategoryName(cat, lang),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

          // Активност по период
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _periodTitle(_periodDays, lang),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [7, 30, 90].map((days) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text(days == 7 ? '7d' : days == 30 ? '30d' : '3m'),
                    selected: _periodDays == days,
                    onSelected: (_) => setState(() => _periodDays = days),
                    labelStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 150,
                child: _buildBarChart(theme, lang),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}