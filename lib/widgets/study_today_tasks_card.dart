import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../utils/localization.dart';

/// Секция „Днешни задачи" (таб Обучение) — до 4 учебни задачи (домашно/есе/
/// курсова) с краен срок днес или в следващите 3 дни. Скрива се, ако няма
/// такива. Тап на бутона „Виж всички" → таб Задачи (през [onOpenTasks]).
class StudyTodayTasksCard extends StatelessWidget {
  /// Превключва към таб Задачи (подаден от началния екран).
  final VoidCallback? onOpenTasks;

  const StudyTodayTasksCard({super.key, this.onOpenTasks});

  static const Set<String> _studyKinds = {'homework', 'essay', 'coursework'};
  static const int _maxRows = 4;

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  static const _title = {
    'en': 'Study tasks', 'bg': 'Днешни задачи', 'de': 'Lernaufgaben',
    'fr': 'Tâches d\'étude', 'it': 'Compiti', 'el': 'Εργασίες',
    'es': 'Tareas', 'pt': 'Tarefas', 'ru': 'Учебные задачи',
    'tr': 'Görevler', 'ja': '学習タスク',
  };
  static const _seeAll = {
    'en': 'See all tasks', 'bg': 'Виж всички задачи',
    'de': 'Alle Aufgaben', 'fr': 'Voir toutes les tâches',
    'it': 'Tutti i compiti', 'el': 'Όλες οι εργασίες', 'es': 'Ver todas',
    'pt': 'Ver todas', 'ru': 'Все задачи', 'tr': 'Tüm görevler',
    'ja': 'すべて見る',
  };
  static const _byWord = {
    'en': 'by', 'bg': 'до', 'de': 'bis', 'fr': 'pour', 'it': 'entro',
    'el': 'έως', 'es': 'para', 'pt': 'até', 'ru': 'до', 'tr': '', 'ja': 'まで',
  };
  static const _todayWord = {
    'en': 'today', 'bg': 'днес', 'de': 'heute', 'fr': "aujourd'hui",
    'it': 'oggi', 'el': 'σήμερα', 'es': 'hoy', 'pt': 'hoje',
    'ru': 'сегодня', 'tr': 'bugün', 'ja': '今日',
  };

  static const _dayNames = {
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'bg': ['понеделник', 'вторник', 'сряда', 'четвъртък', 'петък', 'събота', 'неделя'],
    'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    'fr': ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'],
    'it': ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'],
    'el': ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'],
    'es': ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'],
    'pt': ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'],
    'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    'ja': ['月', '火', '水', '木', '金', '土', '日'],
  };

  String _dueLabel(String lang, DateTime due, DateTime today) {
    final d0 = DateTime(today.year, today.month, today.day);
    final dd = DateTime(due.year, due.month, due.day);
    final by = _t(_byWord, lang);
    if (dd == d0) {
      final hh = due.hour.toString().padLeft(2, '0');
      final mm = due.minute.toString().padLeft(2, '0');
      final t = _t(_todayWord, lang);
      return by.isEmpty ? '$t $hh:$mm' : '$by $t $hh:$mm';
    }
    final names = _dayNames[lang] ?? _dayNames['en']!;
    final name = names[(due.weekday - 1).clamp(0, 6)];
    return by.isEmpty ? name : '$by $name';
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Task>('tasks');
    final lang = LanguageScope.of(context).locale.languageCode;
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<Task> b, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final windowEnd = today.add(const Duration(days: 4)); // днес + 3 дни

        final tasks = b.values
            .where((t) =>
                !t.isCompleted &&
                t.taskKind != null &&
                _studyKinds.contains(t.taskKind) &&
                !DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day)
                    .isBefore(today) &&
                DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day)
                    .isBefore(windowEnd))
            .toList()
          ..sort((a, b2) => a.dueDate.compareTo(b2.dueDate));

        if (tasks.isEmpty) return const SizedBox.shrink();
        final shown = tasks.take(_maxRows).toList();

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📝 ${_t(_title, lang)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 6),
                for (final t in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Icon(Icons.circle,
                              size: 7, color: theme.colorScheme.primary),
                        ),
                        Expanded(
                          child: Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        Text(_dueLabel(lang, t.dueDate, now),
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                if (onOpenTasks != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: onOpenTasks,
                      icon: const Icon(Icons.checklist_rtl, size: 16),
                      label: Text(_t(_seeAll, lang)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
