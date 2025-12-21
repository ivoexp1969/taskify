import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../widgets/reminder_selector.dart';
import '../../services/widget_service.dart';

enum CalendarView { day, week, month }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;

  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarView _view = CalendarView.day;

  final TextEditingController _titleController = TextEditingController();
  String _selectedCategoryId = '';
  int _selectedPriority = 1;
  String _selectedRecurrence = 'none';

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasks');
    categoryBox = Hive.box<Category>('categories');

    if (categoryBox.isEmpty) {
      final defaults = [
        Category(
          id: 'work',
          name: 'Work',
          colorValue: Colors.blue.value,
          isDefault: true,
        ),
        Category(
          id: 'personal',
          name: 'Personal',
          colorValue: Colors.green.value,
          isDefault: true,
        ),
        Category(
          id: 'shopping',
          name: 'Shopping',
          colorValue: Colors.orange.value,
          isDefault: true,
        ),
      ];
      for (var c in defaults) {
        categoryBox.put(c.id, c);
      }
    }
    _selectedCategoryId = categoryBox.values.first.id;

    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _nextDueDate(DateTime current, String recurrence) {
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

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day.$month.$year';
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateTime(DateTime d) {
    final dateStr = _formatDate(d);
    if (d.hour == 0 && d.minute == 0) {
      return dateStr;
    }
    final timeStr = _formatTime(TimeOfDay.fromDateTime(d));
    return '$dateStr · $timeStr';
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 0:
        return Colors.green;
      case 2:
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  String _priorityLabel(int p, AppText t) {
    switch (p) {
      case 0:
        return t.low;
      case 2:
        return t.high;
      default:
        return t.medium;
    }
  }

  String _recurrenceLabel(String? r, AppText t) {
    switch (r) {
      case 'daily':
        return t.daily;
      case 'weekly':
        return t.weekly;
      case 'monthly':
        return t.monthly;
      case 'yearly':
        return t.yearly;
      default:
        return t.noRepeat;
    }
  }

  String _localizedCategoryName(Category? c, AppText t) {
    if (c == null) return '';
    if (c.isDefault) {
      return {
            'work': t.work,
            'personal': t.personal,
            'shopping': t.shopping,
          }[c.id] ??
          c.name;
    }
    return c.name;
  }

  Map<DateTime, List<Task>> _buildEventMap() {
    final map = <DateTime, List<Task>>{};
    for (final task in taskBox.values.where((t) => !t.isCompleted)) {
      final key = _normalizeDate(task.dueDate);
      map.putIfAbsent(key, () => <Task>[]).add(task);
    }
    return map;
  }

  /// Задачи според избрания изглед:
  /// - Ден: по избрания ден от календара
  /// - Седмица: ТЕКУЩАТА седмица (понеделник–неделя) според днес
  /// - Месец: ТЕКУЩИЯ месец според днес
  List<Task> _tasksForView() {
    final now = DateTime.now();
    final today = _normalizeDate(now);

    final all = taskBox.values
        .where((t) => !t.isCompleted)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    switch (_view) {
      case CalendarView.day:
        final target = _normalizeDate(_selectedDay);
        return all
            .where((t) => _normalizeDate(t.dueDate) == target)
            .toList();

      case CalendarView.week:
        // ПОНЕДЕЛНИК–НЕДЕЛЯ за седмицата, в която се намира ДНЕС
        final int weekday = today.weekday; // 1 = Mon, ... 7 = Sun
        final DateTime startOfWeek =
            today.subtract(Duration(days: weekday - 1)); // понеделник
        final DateTime endOfWeek =
            startOfWeek.add(const Duration(days: 6)); // неделя

        return all.where((t) {
          final d = _normalizeDate(t.dueDate);
          return !d.isBefore(startOfWeek) && !d.isAfter(endOfWeek);
        }).toList();

      case CalendarView.month:
        final year = today.year;
        final month = today.month;
        return all
            .where((t) =>
                t.dueDate.year == year && t.dueDate.month == month)
            .toList();
    }
  }

  void _showAddCategoryDialog(StateSetter setDialogState) {
    final t = AppText.of(context);
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('${t.add} ${t.category.toLowerCase()}'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: t.category),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final id =
                      DateTime.now().millisecondsSinceEpoch.toString();
                  final color = Colors
                      .primaries[Random().nextInt(Colors.primaries.length)]
                      .value;
                  final newCat = Category(
                    id: id,
                    name: name,
                    colorValue: color,
                    isDefault: false,
                  );
                  categoryBox.put(id, newCat);
                  setState(() {});
                  setDialogState(() {
                    _selectedCategoryId = id;
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text(t.add),
            ),
          ],
        );
      },
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) async {
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;
    final isBg = langCode == 'bg';

    DateTime focusedDay =
        DateTime(initialDate.year, initialDate.month, initialDate.day);
    DateTime selectedDay = focusedDay;

    String monthLabel(DateTime day) {
      const bgMonths = [
        'януари',
        'февруари',
        'март',
        'април',
        'май',
        'юни',
        'юли',
        'август',
        'септември',
        'октомври',
        'ноември',
        'декември',
      ];
      const enMonths = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final name = isBg ? bgMonths[day.month - 1] : enMonths[day.month - 1];
      return '$name ${day.year}';
    }

    String weekdayLabel(int weekday) {
      const bg = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
      const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final idx = weekday - 1;
      return (isBg ? bg : en)[idx];
    }

    final t = AppText.of(context);

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.dueDate),
          content: StatefulBuilder(
            builder: (innerContext, setState) {
              return SizedBox(
                width: 320,
                height: 320,
                child: Column(
                  children: [
                    Text(
                      monthLabel(focusedDay),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TableCalendar(
                        firstDay: DateTime(2020, 1, 1),
                        lastDay: DateTime(2100, 12, 31),
                        focusedDay: focusedDay,
                        headerVisible: false,
                        calendarFormat: CalendarFormat.month,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        selectedDayPredicate: (day) =>
                            isSameDay(selectedDay, day),
                        onDaySelected: (sel, foc) {
                          setState(() {
                            selectedDay =
                                DateTime(sel.year, sel.month, sel.day);
                            focusedDay = foc;
                          });
                        },
                        onPageChanged: (newFocusedDay) {
                          setState(() {
                            focusedDay = newFocusedDay;
                          });
                        },
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(fontSize: 11),
                          weekendStyle: TextStyle(fontSize: 11),
                        ),
                        calendarStyle: CalendarStyle(
                          defaultTextStyle: const TextStyle(fontSize: 12),
                          weekendTextStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                          outsideTextStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Theme.of(innerContext)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            fontSize: 12,
                            color: Theme.of(innerContext)
                                .colorScheme
                                .primary,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Theme.of(innerContext)
                                .colorScheme
                                .primary,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          dowBuilder: (context, day) {
                            final label = weekdayLabel(day.weekday);
                            return Center(
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.cancel),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(selectedDay),
              child: Text(t.add),
            ),
          ],
        );
      },
    );
  }

  void _openTaskDialog({Task? existing}) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final bool isEditing = existing != null;

    DateTime tempDueDate =
        existing?.dueDate ?? _normalizeDate(_selectedDay);
    TimeOfDay? tempTime;
    if (existing != null &&
        (existing.dueDate.hour != 0 || existing.dueDate.minute != 0)) {
      tempTime = TimeOfDay.fromDateTime(existing.dueDate);
    }

    String tempCategoryId = existing?.categoryId ?? _selectedCategoryId;
    int tempPriority = existing?.priority ?? _selectedPriority;
    String tempRecurrence = existing?.recurrence ?? _selectedRecurrence;
    String tempReminder = existing?.reminder ?? 'none';
    List<String> tempReminders = List<String>.from(existing?.remindersList ?? []);
    String tempNotes = existing?.notes ?? '';

    _titleController.text = existing?.title ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final categories = categoryBox.values.toList();
            final languageController = LanguageScope.of(innerContext);
            final isBg = languageController.locale.languageCode == 'bg';
            final bottomPadding = MediaQuery.of(innerContext).viewInsets.bottom;

            final selectedCat = categories.firstWhere(
              (c) => c.id == tempCategoryId,
              orElse: () => categories.first,
            );
            final categoryColor = Color(selectedCat.colorValue);

            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_task_rounded,
                            color: categoryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          isEditing 
                              ? (isBg ? 'Редактиране' : 'Edit Task')
                              : t.newTask,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            _titleController.clear();
                            Navigator.pop(innerContext);
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Заглавие
                          TextField(
                            controller: _titleController,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: isBg ? 'Какво трябва да направиш?' : 'What needs to be done?',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontWeight: FontWeight.normal,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.outline.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(
                                Icons.title_rounded,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Секция: Категория
                          _buildSectionLabel(isBg ? 'Категория' : 'Category', Icons.folder_outlined, theme),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...categories.map((cat) {
                                final isSelected = cat.id == tempCategoryId;
                                final catColor = Color(cat.colorValue);
                                return GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      tempCategoryId = cat.id;
                                      _selectedCategoryId = cat.id;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? catColor.withOpacity(0.2)
                                          : theme.colorScheme.outline.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? catColor : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: catColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _localizedCategoryName(cat, t),
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected
                                                ? catColor
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              GestureDetector(
                                onTap: () => _showAddCategoryDialog(setSheetState),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isBg ? 'Нова' : 'New',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Секция: Приоритет
                          _buildSectionLabel(t.priority, Icons.flag_outlined, theme),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildPriorityButton(
                                label: t.low,
                                selected: tempPriority == 0,
                                color: Colors.green,
                                onTap: () => setSheetState(() {
                                  tempPriority = 0;
                                  _selectedPriority = 0;
                                }),
                              ),
                              const SizedBox(width: 10),
                              _buildPriorityButton(
                                label: t.medium,
                                selected: tempPriority == 1,
                                color: Colors.orange,
                                onTap: () => setSheetState(() {
                                  tempPriority = 1;
                                  _selectedPriority = 1;
                                }),
                              ),
                              const SizedBox(width: 10),
                              _buildPriorityButton(
                                label: t.high,
                                selected: tempPriority == 2,
                                color: Colors.redAccent,
                                onTap: () => setSheetState(() {
                                  tempPriority = 2;
                                  _selectedPriority = 2;
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Секция: Дата и час
                          _buildSectionLabel(isBg ? 'Дата и час' : 'Date & Time', Icons.calendar_today_outlined, theme),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await _pickDate(innerContext, tempDueDate);
                                    if (picked != null) {
                                      setSheetState(() {
                                        tempDueDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          tempTime?.hour ?? 0,
                                          tempTime?.minute ?? 0,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outline.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 20,
                                          color: categoryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _formatDate(tempDueDate),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: innerContext,
                                      initialTime: tempTime ?? TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        tempTime = picked;
                                        tempDueDate = DateTime(
                                          tempDueDate.year,
                                          tempDueDate.month,
                                          tempDueDate.day,
                                          picked.hour,
                                          picked.minute,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outline.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 20,
                                          color: categoryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          tempTime != null 
                                              ? _formatTime(tempTime)
                                              : (isBg ? 'Час' : 'Time'),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: tempTime != null
                                                ? theme.colorScheme.onSurface
                                                : theme.colorScheme.onSurface.withOpacity(0.4),
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

                          // Секция: Повторение
                          _buildSectionLabel(t.repeat, Icons.repeat_rounded, theme),
                          const SizedBox(height: 12),
                          _buildDropdownTile(
                            value: tempRecurrence,
                            items: {
                              'none': t.noRepeat,
                              'daily': t.daily,
                              'weekly': t.weekly,
                              'monthly': t.monthly,
                              'yearly': t.yearly,
                            },
                            theme: theme,
                            onChanged: (val) => setSheetState(() {
                              tempRecurrence = val;
                              _selectedRecurrence = val;
                            }),
                          ),
                          const SizedBox(height: 24),

                          // Секция: Напомняне
                          _buildSectionLabel(
                            isBg ? 'Напомняния' : 'Reminders',
                            Icons.notifications_outlined,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          ReminderSelector(
                            selectedReminders: tempReminders,
                            onChanged: (list) => setSheetState(() {
                              tempReminders = list;
                            }),
                            isBg: isBg,
                            theme: theme,
                          ),
                          const SizedBox(height: 32),

                          // Секция: Бележки
                          Text(
                            isBg ? 'Бележки' : 'Notes',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final controller = TextEditingController(text: tempNotes);
                              final result = await showDialog<String>(
                                context: innerContext,
                                builder: (ctx) => AlertDialog(
                                  title: Text(isBg ? 'Бележки' : 'Notes'),
                                  content: TextField(
                                    controller: controller,
                                    maxLines: 6,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: isBg ? 'Допълнителна информация...' : 'Additional information...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(t.cancel),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, controller.text),
                                      child: Text(isBg ? 'Запази' : 'Save'),
                                    ),
                                  ],
                                ),
                              );
                              if (result != null) {
                                setSheetState(() {
                                  tempNotes = result;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.outline.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: tempNotes.trim().isNotEmpty
                                    ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    tempNotes.trim().isNotEmpty ? Icons.note_rounded : Icons.note_add_outlined,
                                    size: 20,
                                    color: tempNotes.trim().isNotEmpty
                                        ? Colors.amber.shade700
                                        : theme.colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      tempNotes.trim().isNotEmpty
                                          ? tempNotes.trim()
                                          : (isBg ? 'Добави бележка...' : 'Add note...'),
                                      style: TextStyle(
                                        color: tempNotes.trim().isNotEmpty
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface.withOpacity(0.4),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (tempNotes.trim().isNotEmpty)
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  // Bottom action button
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(innerContext).padding.bottom),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () async {
                          final titleText = _titleController.text.trim();
                          if (titleText.isEmpty) return;

                          final dueDateToSave = DateTime(
                            tempDueDate.year,
                            tempDueDate.month,
                            tempDueDate.day,
                            tempTime?.hour ?? 0,
                            tempTime?.minute ?? 0,
                          );

                          final recurrenceToSave =
                              tempRecurrence == 'none' ? null : tempRecurrence;

                          if (isEditing) {
                            existing!
                              ..title = titleText
                              ..dueDate = dueDateToSave
                              ..categoryId = tempCategoryId
                              ..priority = tempPriority
                              ..recurrence = recurrenceToSave
                              ..notes = tempNotes.trim().isEmpty ? null : tempNotes.trim();
                            existing.setReminders(tempReminders);
                            await existing.save();
                            await NotificationService().scheduleForTask(existing);
                          } else {
                            final newTask = Task(
                              title: titleText,
                              dueDate: dueDateToSave,
                              categoryId: tempCategoryId,
                              priority: tempPriority,
                              recurrence: recurrenceToSave,
                              reminders: tempReminders.isEmpty ? null : tempReminders,
                              notes: tempNotes.trim().isEmpty ? null : tempNotes.trim(),
                            );
                            await taskBox.add(newTask);
                            await NotificationService().scheduleForTask(newTask);
                          }

                          await WidgetService.updateWidget();
                          _titleController.clear();
                          setState(() {});
                          Navigator.pop(innerContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: categoryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isEditing
                              ? (isBg ? 'Запази промените' : 'Save Changes')
                              : (isBg ? 'Добави задача' : 'Add Task'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.withOpacity(0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag_rounded,
                size: 18,
                color: selected ? color : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String value,
    required Map<String, String> items,
    required ThemeData theme,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          items: items.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildViewChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary.withOpacity(0.12)
        : Colors.transparent;
    final fg =
        selected ? theme.colorScheme.primary : Colors.grey.shade700;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);

    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;
    final isBg = langCode == 'bg';

    final events = _buildEventMap();
    final tasks = _tasksForView();
    final categoriesMap = {
      for (var c in categoryBox.values) c.id: c,
    };

    String monthYearLabel(DateTime day) {
      const bgMonths = [
        'януари',
        'февруари',
        'март',
        'април',
        'май',
        'юни',
        'юли',
        'август',
        'септември',
        'октомври',
        'ноември',
        'декември',
      ];
      const enMonths = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final name =
          isBg ? bgMonths[day.month - 1] : enMonths[day.month - 1];
      return '$name ${day.year}';
    }

    String weekdayLabel(int weekday) {
      const bg = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
      const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final idx = weekday - 1;
      return (isBg ? bg : en)[idx];
    }

    final dayLabel = isBg ? 'Ден' : 'Day';
    final weekLabel = isBg ? 'Седмица' : 'Week';
    final monthLabelStr = isBg ? 'Месец' : 'Month';

    return Scaffold(
      appBar: AppBar(
        title: Text(t.calendar),
      ),
      body: Column(
        children: [
          // Календар – горна част
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Column(
              children: [
                // Header (месец / година)
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(
                            _focusedDay.year,
                            _focusedDay.month - 1,
                            1,
                          );
                        });
                      },
                    ),
                    Text(
                      monthYearLabel(_focusedDay),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(
                            _focusedDay.year,
                            _focusedDay.month + 1,
                            1,
                          );
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(
                  height: 195,
                  child: TableCalendar<Task>(
                    firstDay: DateTime(2020, 1, 1),
                    lastDay: DateTime(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    rowHeight: 28,
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = _normalizeDate(selectedDay);
                        _focusedDay = focusedDay;
                      });
                    },
                    onDayLongPressed: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = _normalizeDate(selectedDay);
                        _focusedDay = focusedDay;
                      });
                      _openTaskDialog();
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: (day) =>
                        events[_normalizeDate(day)] ?? const <Task>[],
                    headerVisible: false,
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        fontSize: 11,
                      ),
                      weekendStyle: TextStyle(
                        fontSize: 11,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: const TextStyle(fontSize: 12),
                      weekendTextStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                      outsideTextStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                      todayDecoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      markersAlignment: Alignment.bottomCenter,
                      markerDecoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      markerSize: 6,
                      markerMargin:
                          const EdgeInsets.symmetric(horizontal: 0.8),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, taskList) {
                        if (taskList.isEmpty) return null;
                        
                        // Сортираме по приоритет (високият първи)
                        final sortedTasks = List<Task>.from(taskList)
                          ..sort((a, b) => b.priority.compareTo(a.priority));
                        
                        // Вземаме до 3 точки
                        final markers = sortedTasks.take(3).toList();
                        
                        return Positioned(
                          bottom: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: markers.map((task) {
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _priorityColor(task.priority),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                      dowBuilder: (context, day) {
                        final label = weekdayLabel(day.weekday);
                        return Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Превключвател Ден / Седмица / Месец
                Row(
                  children: [
                    _buildViewChip(
                      label: dayLabel,
                      selected: _view == CalendarView.day,
                      onTap: () =>
                          setState(() => _view = CalendarView.day),
                    ),
                    const SizedBox(width: 6),
                    _buildViewChip(
                      label: weekLabel,
                      selected: _view == CalendarView.week,
                      onTap: () =>
                          setState(() => _view = CalendarView.week),
                    ),
                    const SizedBox(width: 6),
                    _buildViewChip(
                      label: monthLabelStr,
                      selected: _view == CalendarView.month,
                      onTap: () =>
                          setState(() => _view = CalendarView.month),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Заглавие „Задачи"
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.tasks,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Списък със задачи според изгледа
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Text(
                      '—',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.black26,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (_, index) {
                      final task = tasks[index];
                      final cat = categoriesMap[task.categoryId];
                      final categoryName =
                          _localizedCategoryName(cat, t);
                      final categoryColor = cat != null
                          ? Color(cat.colorValue)
                          : Colors.grey;
                      final priorityColor =
                          _priorityColor(task.priority);
                      final priorityText =
                          _priorityLabel(task.priority, t);
                      final recurrenceText = task.recurrence == null
                          ? ''
                          : ' · ${_recurrenceLabel(task.recurrence, t)}';
                      final dateTimeStr =
                          _formatDateTime(task.dueDate);

                      final now = DateTime.now();
                      final isOverdue =
                          !task.isCompleted && task.dueDate.isBefore(now);
                      final isCompleted = task.isCompleted;

                      final accentColor = isOverdue
                          ? Colors.redAccent
                          : categoryColor;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Opacity(
                          opacity: isCompleted ? 0.6 : 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withOpacity(0.1),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // Цветна лента
                                      Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(14),
                                            bottomLeft: Radius.circular(14),
                                          ),
                                        ),
                                      ),
                                      // Checkbox
                                      Checkbox(
                                        value: task.isCompleted,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        activeColor: accentColor,
                                        onChanged: (bool? value) async {
                                          final wasCompleted = task.isCompleted;
                                          task.isCompleted =
                                              value ?? !task.isCompleted;
                                          task.completedAt = task.isCompleted ? DateTime.now() : null;
                                          await task.save();

                                          if (!wasCompleted &&
                                              task.isCompleted &&
                                              task.recurrence != null) {
                                            final nextDate = _nextDueDate(
                                              task.dueDate,
                                              task.recurrence!,
                                            );
                                            final newTask = Task(
                                              title: task.title,
                                              dueDate: nextDate,
                                              categoryId: task.categoryId,
                                              priority: task.priority,
                                              recurrence: task.recurrence,
                                              reminders: task.reminders,
                                            );
                                            await taskBox.add(newTask);
                                            await NotificationService().scheduleForTask(newTask);
                                          }

                                          // Отменяме или планираме нотификации
                                          if (task.isCompleted) {
                                            await NotificationService().cancelForTask(task);
                                          } else if (task.hasReminders) {
                                            await NotificationService().scheduleForTask(task);
                                          }
                                          
                                          await WidgetService.updateWidget();
                                          setState(() {});
                                        },
                                      ),
                                      // Съдържание
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  decoration: isCompleted
                                                      ? TextDecoration.lineThrough
                                                      : TextDecoration.none,
                                                  color: isCompleted
                                                      ? Colors.grey.shade500
                                                      : theme.colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  if (categoryName.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: categoryColor.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 5,
                                                            height: 5,
                                                            decoration: BoxDecoration(
                                                              color: categoryColor,
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            categoryName,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w500,
                                                              color: categoryColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: priorityColor.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      priorityText,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: priorityColor,
                                                      ),
                                                    ),
                                                  ),
                                                  if (task.recurrence != null)
                                                    Icon(
                                                      Icons.repeat_rounded,
                                                      size: 14,
                                                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time_rounded,
                                                    size: 12,
                                                    color: isOverdue
                                                        ? Colors.redAccent
                                                        : theme.colorScheme.onSurface.withOpacity(0.4),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    dateTimeStr,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isOverdue
                                                          ? Colors.redAccent
                                                          : theme.colorScheme.onSurface.withOpacity(0.4),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Бутони
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                                            ),
                                            onPressed: () =>
                                                _openTaskDialog(existing: task),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () async {
                                              await task.delete();
                                              await WidgetService.updateWidget();
                                              setState(() {});
                                            },
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}