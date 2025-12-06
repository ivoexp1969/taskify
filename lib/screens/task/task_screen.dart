import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../widgets/reminder_selector.dart';
import '../../services/widget_service.dart';

enum TaskFilter { all, active, completed, overdue, upcoming, archived }

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with TickerProviderStateMixin {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;

  final TextEditingController _titleController = TextEditingController();

  String _selectedCategoryId = '';
  int _selectedPriority = 1;
  String _selectedRecurrence = 'none';
  TaskFilter _filter = TaskFilter.active;

  // търсене и филтър по категория
  String _searchQuery = '';
  String? _categoryFilterId; // null = всички категории

  // Позиция на плаващия бутон
  Offset? _fabOffset;

  // Анимация
  late AnimationController _listAnimationController;

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasks');
    categoryBox = Hive.box<Category>('categories');

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _listAnimationController.forward();

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
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _titleController.dispose();
    super.dispose();
  }

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

  List<Task> _filteredTasks() {
    final now = DateTime.now();
    var tasks = taskBox.values.toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // филтър по статус
    List<Task> filtered;
    switch (_filter) {
      case TaskFilter.all:
        filtered = tasks.where((t) => !t.isArchived).toList();
        break;
      case TaskFilter.active:
        filtered = tasks.where((t) => !t.isCompleted && !t.isArchived).toList();
        break;
      case TaskFilter.completed:
        filtered = tasks.where((t) => t.isCompleted && !t.isArchived).toList();
        break;
      case TaskFilter.overdue:
        filtered = tasks
            .where((t) => !t.isCompleted && !t.isArchived && t.dueDate.isBefore(now))
            .toList();
        break;
      case TaskFilter.upcoming:
        filtered = tasks
            .where((t) => !t.isCompleted && !t.isArchived && !t.dueDate.isBefore(now))
            .toList();
        break;
      case TaskFilter.archived:
        filtered = tasks.where((t) => t.isArchived).toList();
        break;
    }

    // филтър по категория
    if (_categoryFilterId != null && _categoryFilterId!.isNotEmpty) {
      filtered = filtered
          .where((t) => t.categoryId == _categoryFilterId)
          .toList();
    }

    // търсене по заглавие
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((t) => t.title.toLowerCase().contains(q))
          .toList();
    }

    return filtered;
  }

  (int total, int completed, int overdue, int upcoming, int archived) _stats() {
    final now = DateTime.now();
    final nonArchived = taskBox.values.where((t) => !t.isArchived);
    final total = nonArchived.length;
    final completed = nonArchived.where((t) => t.isCompleted).length;
    final overdue = nonArchived
        .where((t) => !t.isCompleted && t.dueDate.isBefore(now))
        .length;
    final upcoming = nonArchived
        .where((t) => !t.isCompleted && !t.dueDate.isBefore(now))
        .length;
    final archived = taskBox.values.where((t) => t.isArchived).length;
    return (total, completed, overdue, upcoming, archived);
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
                    _categoryFilterId = null;
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

  Future<DateTime?> _pickDate(
      BuildContext context, DateTime initialDate) async {
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

    DateTime tempDueDate = existing?.dueDate ?? DateTime.now();
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
    List<Map<String, dynamic>> tempSubtasks = existing?.subtasksList ?? [];
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

            // Взимаме цвета на избраната категория
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
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.mic_rounded,
                                  color: categoryColor,
                                ),
                                onPressed: () async {
                                  final available = await _speech.initialize(
                                    onError: (error) => print('Speech error: $error'),
                                  );
                                  if (!available) {
                                    if (innerContext.mounted) {
                                      ScaffoldMessenger.of(innerContext).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isBg 
                                                ? 'Гласовото разпознаване не е налично'
                                                : 'Speech recognition not available',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  
                                  // Показваме диалог за слушане
                                  showDialog(
                                    context: innerContext,
                                    barrierDismissible: false,
                                    builder: (dialogContext) {
                                      String recognizedText = '';
                                      bool isListening = true;
                                      
                                      _speech.listen(
                                        onResult: (result) {
                                          recognizedText = result.recognizedWords;
                                          if (result.finalResult) {
                                            _titleController.text = recognizedText;
                                            Navigator.pop(dialogContext);
                                            setSheetState(() {});
                                          }
                                        },
                                        localeId: isBg ? 'bg-BG' : 'en-US',
                                        listenFor: const Duration(seconds: 10),
                                        pauseFor: const Duration(seconds: 3),
                                      );
                                      
                                      return StatefulBuilder(
                                        builder: (ctx, setDialogState) {
                                          return AlertDialog(
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    color: categoryColor.withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.mic_rounded,
                                                    size: 40,
                                                    color: categoryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  isBg ? 'Слушам...' : 'Listening...',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  isBg ? 'Говори сега' : 'Speak now',
                                                  style: TextStyle(
                                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  _speech.stop();
                                                  Navigator.pop(dialogContext);
                                                },
                                                child: Text(isBg ? 'Отказ' : 'Cancel'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
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
                              // Add category button
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
                                      style: BorderStyle.solid,
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
                                value: 0,
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
                                value: 1,
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
                                value: 2,
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
                          const SizedBox(height: 24),

                          // Секция: Подзадачи
                          _buildSectionLabel(
                            isBg ? 'Подзадачи' : 'Subtasks',
                            Icons.checklist_rounded,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          // Списък с подзадачи
                          ...tempSubtasks.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final subtask = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        tempSubtasks[idx]['done'] = !(tempSubtasks[idx]['done'] as bool);
                                      });
                                    },
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: subtask['done'] == true
                                            ? categoryColor
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: subtask['done'] == true
                                              ? categoryColor
                                              : theme.colorScheme.outline.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: subtask['done'] == true
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      subtask['text'] as String,
                                      style: TextStyle(
                                        fontSize: 15,
                                        decoration: subtask['done'] == true
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: subtask['done'] == true
                                            ? theme.colorScheme.onSurface.withOpacity(0.5)
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                    onPressed: () {
                                      setSheetState(() {
                                        tempSubtasks.removeAt(idx);
                                      });
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            );
                          }),
                          // Бутон за добавяне на подзадача
                          GestureDetector(
                            onTap: () async {
                              final controller = TextEditingController();
                              final result = await showDialog<String>(
                                context: innerContext,
                                builder: (ctx) => AlertDialog(
                                  title: Text(isBg ? 'Нова подзадача' : 'New Subtask'),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: isBg ? 'Въведи подзадача...' : 'Enter subtask...',
                                    ),
                                    onSubmitted: (val) => Navigator.pop(ctx, val),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(t.cancel),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, controller.text),
                                      child: Text(t.add),
                                    ),
                                  ],
                                ),
                              );
                              if (result != null && result.trim().isNotEmpty) {
                                setSheetState(() {
                                  tempSubtasks.add({'done': false, 'text': result.trim()});
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(0.2),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 20,
                                    color: categoryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isBg ? 'Добави подзадача' : 'Add subtask',
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                            existing.setSubtasks(tempSubtasks);
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
                            newTask.setSubtasks(tempSubtasks);
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
    required int value,
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

  Widget _buildStatCard({
    required String label,
    required int value,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected 
                ? color.withOpacity(0.15) 
                : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: selected ? [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? color : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 4),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: selected ? color : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: selected 
                        ? color.withOpacity(0.8)
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
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
    final isBg = languageController.locale.languageCode == 'bg';

    final tasks = _filteredTasks();
    final categoriesMap = {
      for (var c in categoryBox.values) c.id: c,
    };

    final (total, completed, overdue, upcoming, archived) = _stats();

    final List<Object> items = [];
    if (tasks.isNotEmpty) {
      final Map<DateTime, List<Task>> grouped = {};
      for (final task in tasks) {
        final d = DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
        );
        grouped.putIfAbsent(d, () => <Task>[]).add(task);
      }
      final sortedDates = grouped.keys.toList()
        ..sort((a, b) => a.compareTo(b));
      for (final date in sortedDates) {
        items.add(date);
        items.addAll(grouped[date]!);
      }
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t.tasks,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
            // Статистика - нов дизайн
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  _buildStatCard(
                    label: t.total,
                    value: total,
                    selected: _filter == TaskFilter.all,
                    onTap: () => setState(() => _filter = TaskFilter.all),
                    color: theme.colorScheme.primary,
                    icon: Icons.list_alt_rounded,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    label: t.upcoming,
                    value: upcoming,
                    selected: _filter == TaskFilter.upcoming,
                    onTap: () => setState(() => _filter = TaskFilter.upcoming),
                    color: Colors.blue,
                    icon: Icons.upcoming_rounded,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    label: t.overdue,
                    value: overdue,
                    selected: _filter == TaskFilter.overdue,
                    onTap: () => setState(() => _filter = TaskFilter.overdue),
                    color: Colors.redAccent,
                    icon: Icons.warning_amber_rounded,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    label: t.completed,
                    value: completed,
                    selected: _filter == TaskFilter.completed,
                    onTap: () => setState(() => _filter = TaskFilter.completed),
                    color: Colors.green,
                    icon: Icons.check_circle_outline_rounded,
                    theme: theme,
                  ),
                ],
              ),
            ),

            // търсене + филтър по категория
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: isBg
                            ? 'Търсене в задачите'
                            : 'Search tasks',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant
                            .withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant
                            .withOpacity(0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                        ),
                        value: _categoryFilterId ?? 'all',
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              isBg ? 'Всички' : 'All',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...categoryBox.values.map((c) {
                            final name = _localizedCategoryName(c, t);
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            if (value == 'all') {
                              _categoryFilterId = null;
                            } else {
                              _categoryFilterId = value;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  // Бутон за архивирани
                  if (archived > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => setState(() {
                          _filter = _filter == TaskFilter.archived
                              ? TaskFilter.all
                              : TaskFilter.archived;
                        }),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _filter == TaskFilter.archived
                                ? Colors.grey
                                : theme.colorScheme.surfaceVariant.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Badge(
                            label: Text('$archived'),
                            isLabelVisible: _filter != TaskFilter.archived,
                            child: Icon(
                              Icons.archive_outlined,
                              size: 20,
                              color: _filter == TaskFilter.archived
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Списък със задачи (групиран по дата)
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
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 8,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final item = items[index];

                        if (item is DateTime) {
                          final label = _formatDate(item);
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(6, 10, 6, 4),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          );
                        }

                        final task = item as Task;
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
                            !task.isCompleted &&
                                task.dueDate.isBefore(now);
                        final isCompleted = task.isCompleted;
                        final hasReminder = task.hasReminders;

                        // Цветът на лентата: червен ако е просрочено, иначе цвета на категорията
                        final accentColor = isOverdue
                            ? Colors.redAccent
                            : categoryColor;

                        // Staggered анимация
                        final animationDelay = (index * 0.05).clamp(0.0, 0.3);
                        
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
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCompleted 
                                      ? (isBg ? 'Възстанови' : 'Restore')
                                      : (isBg ? 'Готово' : 'Done'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Swipe наляво - изтриване
                          secondaryBackground: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  isBg ? 'Изтрий' : 'Delete',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 28,
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

                              if (!wasCompleted && task.isCompleted && task.recurrence != null) {
                                final nextDate = _nextDueDate(task.dueDate, task.recurrence!);
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

                              if (task.isCompleted) {
                                await NotificationService().cancelForTask(task);
                              } else if (task.hasReminders) {
                                await NotificationService().scheduleForTask(task);
                              }

                              await WidgetService.updateWidget();
                              setState(() {});
                              return false; // Не изтриваме, само toggle-ваме
                            } else {
                              // Swipe наляво - изтриване с потвърждение
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(isBg ? 'Изтриване' : 'Delete'),
                                  content: Text(
                                    isBg
                                        ? 'Сигурен ли си, че искаш да изтриеш "${task.title}"?'
                                        : 'Are you sure you want to delete "${task.title}"?',
                                  ),
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
                                      child: Text(isBg ? 'Изтрий' : 'Delete'),
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
                            await task.delete();
                            await WidgetService.updateWidget();
                            setState(() {});
                          },
                          child: GestureDetector(
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit_outlined),
                                      title: Text(isBg ? 'Редактирай' : 'Edit'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _openTaskDialog(existing: task);
                                      },
                                    ),
                                    if (task.isCompleted && !task.isArchived)
                                      ListTile(
                                        leading: const Icon(Icons.archive_outlined),
                                        title: Text(isBg ? 'Архивирай' : 'Archive'),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          task.isArchived = true;
                                          task.archivedAt = DateTime.now();
                                          await task.save();
                                          await WidgetService.updateWidget();
                                          setState(() {});
                                        },
                                      ),
                                    if (task.isArchived)
                                      ListTile(
                                        leading: const Icon(Icons.unarchive_outlined),
                                        title: Text(isBg ? 'Възстанови' : 'Unarchive'),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          task.isArchived = false;
                                          task.archivedAt = null;
                                          await task.save();
                                          await WidgetService.updateWidget();
                                          setState(() {});
                                        },
                                      ),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                                      title: Text(
                                        isBg ? 'Изтрий' : 'Delete',
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await NotificationService().cancelForTask(task);
                                        await task.delete();
                                        await WidgetService.updateWidget();
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Opacity(
                            opacity: isCompleted ? 0.6 : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withOpacity(0.1),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        // Цветна лента вляво
                                        Container(
                                          width: 5,
                                          decoration: BoxDecoration(
                                            color: accentColor,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              bottomLeft: Radius.circular(16),
                                            ),
                                          ),
                                        ),
                                        // Checkbox
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Transform.scale(
                                            scale: 1.1,
                                            child: Checkbox(
                                              value: task.isCompleted,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              activeColor: accentColor,
                                              onChanged: (bool? value) async {
                                                final wasCompleted =
                                                    task.isCompleted;
                                                setState(() {
                                                  task.isCompleted =
                                                      value ?? !task.isCompleted;
                                                });
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
                                                    reminder: task.reminder,
                                                  );
                                                  await taskBox.add(newTask);
                                                  await NotificationService()
                                                      .scheduleForTask(newTask);
                                                }

                                                if (task.isCompleted) {
                                                  await NotificationService()
                                                      .cancelForTask(task);
                                                } else if (task.reminder != null) {
                                                  await NotificationService()
                                                      .scheduleForTask(task);
                                                }

                                                await WidgetService.updateWidget();
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ),
                                        // Съдържание
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Заглавие
                                                Text(
                                                  task.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    decoration: isCompleted
                                                        ? TextDecoration.lineThrough
                                                        : TextDecoration.none,
                                                    color: isCompleted
                                                        ? Colors.grey.shade500
                                                        : theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Badges
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: [
                                                    // Категория badge
                                                    if (categoryName.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: categoryColor.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              width: 6,
                                                              height: 6,
                                                              decoration: BoxDecoration(
                                                                color: categoryColor,
                                                                shape: BoxShape.circle,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              categoryName,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w500,
                                                                color: categoryColor.withOpacity(0.9),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    // Приоритет badge
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: priorityColor.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        priorityText,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: priorityColor,
                                                        ),
                                                      ),
                                                    ),
                                                    // Повторение
                                                    if (task.recurrence != null)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.outline.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.repeat_rounded,
                                                              size: 12,
                                                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                            ),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              _recurrenceLabel(task.recurrence, t),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    // Напомняне
                                                    if (hasReminder)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.amber.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons.notifications_active_rounded,
                                                              size: 12,
                                                              color: Colors.amber,
                                                            ),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              isBg ? 'напомняне' : 'reminder',
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.amber,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    // Подзадачи
                                                    if (task.totalSubtasksCount > 0)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.primary.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.checklist_rounded,
                                                              size: 12,
                                                              color: theme.colorScheme.primary,
                                                            ),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              '${task.completedSubtasksCount}/${task.totalSubtasksCount}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: theme.colorScheme.primary,
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    // Бележки
                                                    if (task.hasNotes)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.amber.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Icon(
                                                          Icons.note_rounded,
                                                          size: 12,
                                                          color: Colors.amber.shade700,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                // Дата и час
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time_rounded,
                                                      size: 14,
                                                      color: isOverdue
                                                          ? Colors.redAccent
                                                          : theme.colorScheme.onSurface.withOpacity(0.5),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      dateTimeStr,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                                        color: isOverdue
                                                            ? Colors.redAccent
                                                            : theme.colorScheme.onSurface.withOpacity(0.5),
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
                                                size: 20,
                                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                              ),
                                              onPressed: () => _openTaskDialog(existing: task),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 20,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () async {
                                                await NotificationService()
                                                    .cancelForTask(task);
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
                          ),
                        ),
                        ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
          // Draggable FAB
          Positioned(
            left: _fabOffset?.dx,
            top: _fabOffset?.dy,
            right: _fabOffset == null ? 16 : null,
            bottom: _fabOffset == null ? 16 : null,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  final screenSize = MediaQuery.of(context).size;
                  final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                  
                  double newX = (_fabOffset?.dx ?? (screenSize.width - 56 - 16)) + details.delta.dx;
                  double newY = (_fabOffset?.dy ?? (screenSize.height - 56 - 16 - appBarHeight - 80)) + details.delta.dy;
                  
                  // Ограничаваме в рамките на екрана
                  newX = newX.clamp(0, screenSize.width - 56);
                  newY = newY.clamp(0, screenSize.height - 56 - appBarHeight - 80);
                  
                  _fabOffset = Offset(newX, newY);
                });
              },
              child: FloatingActionButton(
                onPressed: () => _openTaskDialog(),
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}