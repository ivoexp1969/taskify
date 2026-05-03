import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../services/google_calendar_service.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../widgets/reminder_selector.dart';
import '../../services/widget_service.dart';
import '../../services/ad_service.dart';
import '../../widgets/celebration_overlay.dart';
import '../../services/review_service.dart';
import 'shopping_list_screen.dart';
import 'task_type_selector.dart';
import 'birthday_dialog.dart';
import 'meeting_dialog.dart';
import 'workout_dialog.dart';
import 'payment_dialog.dart';
import 'travel_dialog.dart';
import 'gift_dialog.dart';
import '../../widgets/task_card_styles.dart';

enum TaskFilter { all, active, completed, overdue, upcoming, archived }
enum TaskSort { date, priority, name, category }

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
  TaskSort _sortBy = TaskSort.date;
  
  // Expanded cards за Expandable Tiles дизайн
  final Set<int> _expandedCards = {};
  bool _needsDefaults = false;

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

    // Слушаме за промени в задачите
    taskBox.listenable().addListener(_onTasksChanged);

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _listAnimationController.forward();

    if (categoryBox.isEmpty) {
      _needsDefaults = true;
    }

    _selectedCategoryId = categoryBox.isEmpty ? '' : categoryBox.values.first.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Добавяме липсващи нови категории при съществуващи потребители
    if (!categoryBox.containsKey('birthday') || !categoryBox.containsKey('meeting')) {
      final t = AppText.of(context);
      final newCats = [
        Category(id: 'birthday', name: t.catBirthdays, colorValue: const Color(0xFFD4537E).value, isDefault: true),
        Category(id: 'meeting', name: t.catMeeting, colorValue: const Color(0xFF378ADD).value, isDefault: true),
        Category(id: 'workout', name: t.catWorkout, colorValue: const Color(0xFFBA7517).value, isDefault: true),
        Category(id: 'payment', name: t.catPayment, colorValue: const Color(0xFF639922).value, isDefault: true),
        Category(id: 'travel', name: t.catTravel, colorValue: const Color(0xFF7F77DD).value, isDefault: true),
        Category(id: 'gift', name: t.catGift, colorValue: const Color(0xFFD85A30).value, isDefault: true),
      ];
      for (var c in newCats) {
        if (!categoryBox.containsKey(c.id)) categoryBox.put(c.id, c);
      }
    }
    if (_needsDefaults && categoryBox.isEmpty) {
      final t = AppText.of(context);
      final defaults = [
        Category(id: 'work', name: t.catWork, colorValue: Colors.blue.value, isDefault: true),
        Category(id: 'personal', name: t.catPersonal, colorValue: Colors.green.value, isDefault: true),
        Category(id: 'shopping', name: t.catShopping, colorValue: Colors.orange.value, isDefault: true),
        Category(id: 'birthday', name: t.catBirthdays, colorValue: const Color(0xFFD4537E).value, isDefault: true),
        Category(id: 'meeting', name: t.catMeeting, colorValue: const Color(0xFF378ADD).value, isDefault: true),
        Category(id: 'workout', name: t.catWorkout, colorValue: const Color(0xFFBA7517).value, isDefault: true),
        Category(id: 'payment', name: t.catPayment, colorValue: const Color(0xFF639922).value, isDefault: true),
        Category(id: 'travel', name: t.catTravel, colorValue: const Color(0xFF7F77DD).value, isDefault: true),
        Category(id: 'gift', name: t.catGift, colorValue: const Color(0xFFD85A30).value, isDefault: true),
      ];
      for (var c in defaults) {
        categoryBox.put(c.id, c);
      }
      _needsDefaults = false;
      _selectedCategoryId = categoryBox.values.first.id;
    }
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _titleController.dispose();
    taskBox.listenable().removeListener(_onTasksChanged);
    super.dispose();
  }

  void _onTasksChanged() {
    if (mounted) setState(() {});
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

  /// Проверява дали датата е днес
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  /// Проверява дали всички задачи за днес са завършени и показва празнуване
  void _checkAndCelebrate({VoidCallback? onComplete, DateTime? taskDate}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Ако задачата не е за днес, не празднуваме
    if (taskDate != null) {
      final td = DateTime(taskDate.year, taskDate.month, taskDate.day);
      if (td != todayStart) return;
    }

    final todayTasks = taskBox.values.where((t) {
      if (t.isArchived) return false;
      final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return due == todayStart;
    }).toList();

    if (todayTasks.isEmpty) return;

    final pendingTasks = todayTasks.where((t) => !t.isCompleted).length;
    if (pendingTasks > 0) return;

    showCelebration(context, onComplete: onComplete);
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
            'birthday': t.catBirthdays,
            'meeting': t.catMeeting,
            'workout': t.catWorkout,
            'payment': t.catPayment,
            'travel': t.catTravel,
            'gift': t.catGift,
          }[c.id] ??
          c.name;
    }
    return c.name;
  }

  /// Проверява дали задачата е просрочена.
  /// За задачи БЕЗ конкретен час (hour=0, minute=0), се счита за просрочена
  /// едва след края на деня (23:59:59).
  bool _isTaskOverdue(Task task) {
    if (task.isCompleted) return false;
    
    final now = DateTime.now();
    final dueDate = task.dueDate;
    
    // Ако задачата има конкретен час (не е 00:00), използваме стандартната проверка
    if (dueDate.hour != 0 || dueDate.minute != 0) {
      return dueDate.isBefore(now);
    }
    
    // За задачи само с дата (без час), те са просрочени едва след края на деня
    final endOfDueDay = DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59);
    return now.isAfter(endOfDueDay);
  }

  List<Task> _filteredTasks() {
    final now = DateTime.now();
    var tasks = taskBox.values.toList();
    
    // Сортиране според избрания метод
    switch (_sortBy) {
      case TaskSort.date:
        tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case TaskSort.priority:
        tasks.sort((a, b) => b.priority.compareTo(a.priority)); // Висок първи
        break;
      case TaskSort.name:
        tasks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case TaskSort.category:
        tasks.sort((a, b) => a.categoryId.compareTo(b.categoryId));
        break;
    }

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
            .where((t) => !t.isArchived && _isTaskOverdue(t))
            .toList();
        break;
      case TaskFilter.upcoming:
        filtered = tasks
            .where((t) => !t.isCompleted && !t.isArchived && !_isTaskOverdue(t))
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
    final nonArchived = taskBox.values.where((t) => !t.isArchived);
    final total = nonArchived.length;
    final completed = nonArchived.where((t) => t.isCompleted).length;
    final overdue = nonArchived
        .where((t) => _isTaskOverdue(t))
        .length;
    final upcoming = nonArchived
        .where((t) => !t.isCompleted && !_isTaskOverdue(t))
        .length;
    final archived = taskBox.values.where((t) => t.isArchived).length;
    return (total, completed, overdue, upcoming, archived);
  }

  static const List<Color> _categoryColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  void _showAddCategoryDialog(StateSetter setDialogState) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final TextEditingController controller = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setColorState) {
            return AlertDialog(
              title: Text(t.newCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.color,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setColorState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      final newCat = Category(
                        id: id,
                        name: name,
                        colorValue: selectedColor.value,
                        isDefault: false,
                      );
                      categoryBox.put(id, newCat);
                      setState(() {});
                      setDialogState(() {
                        _selectedCategoryId = id;
                        _categoryFilterId = null;
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(t.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _pickDate(
      BuildContext context, DateTime initialDate) async {
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;

    DateTime focusedDay =
        DateTime(initialDate.year, initialDate.month, initialDate.day);
    DateTime selectedDay = focusedDay;

    String monthLabel(DateTime day) {
      const months = {
        'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
        'bg': ['януари', 'февруари', 'март', 'април', 'май', 'юни', 'юли', 'август', 'септември', 'октомври', 'ноември', 'декември'],
        'de': ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
        'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
        'it': ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'],
        'el': ['Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος'],
        'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
        'pt': ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'],
        'ru': ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'],
        'tr': ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'],
      };
      final monthList = months[langCode] ?? months['en']!;
      final name = monthList[day.month - 1];
      return '$name ${day.year}';
    }

    String weekdayLabel(int weekday) {
      const weekdays = {
        'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        'bg': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
        'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
        'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
        'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
        'el': ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ', 'Κυρ'],
        'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
        'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
        'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
        'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
      };
      final dayList = weekdays[langCode] ?? weekdays['en']!;
      final idx = weekday - 1;
      return dayList[idx];
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
                                .withValues(alpha: 0.1),
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

  static Color? _templateAccentColor(String? template) {
    switch (template) {
      case 'shopping': return const Color(0xFF00E5A0);
      case 'birthday': return const Color(0xFFFF6FA8);
      case 'meeting':  return const Color(0xFF4DB8FF);
      case 'workout':  return const Color(0xFFFFB347);
      case 'payment':  return const Color(0xFF8AE000);
      case 'travel':   return const Color(0xFFA78BFF);
      case 'gift':     return const Color(0xFFFF7043);
      default: return null;
    }
  }

  void _openTaskDialog({Task? existing}) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final bool isEditing = existing != null;
    final refreshParent = () => setState(() {});  // Запазваме референция към главния setState

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
            final langCode = languageController.locale.languageCode;
            final bottomPadding = MediaQuery.of(innerContext).viewInsets.bottom;
            
            // Локали за гласово въвеждане
            const voiceLocales = {
              'en': 'en-US', 'bg': 'bg-BG', 'de': 'de-DE', 'fr': 'fr-FR', 
              'it': 'it-IT', 'el': 'el-GR', 'es': 'es-ES', 'pt': 'pt-PT',
              'ru': 'ru-RU', 'tr': 'tr-TR',
            };
            final voiceLocale = voiceLocales[langCode] ?? 'en-US';

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
                    color: Colors.black.withValues(alpha: 0.15),
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
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                            color: categoryColor.withValues(alpha: 0.15),
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
                              ? (t.editTask)
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
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                              hintText: t.whatNeedsToBeDone,
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                fontWeight: FontWeight.normal,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.outline.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(
                                Icons.title_rounded,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                                          content: Text(t.speechNotAvailable),
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
                                        localeId: voiceLocale,
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
                                                    color: categoryColor.withValues(alpha: 0.1),
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
                                                  t.listening,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  t.speakNow,
                                                  style: TextStyle(
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                                                child: Text(t.cancel),
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
                          _buildSectionLabel(t.category, Icons.folder_outlined, theme),
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
                                          ? catColor.withValues(alpha: 0.2)
                                          : theme.colorScheme.outline.withValues(alpha: 0.08),
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
                                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                                        t.newCat,
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
                          _buildSectionLabel(t.dateAndTime, Icons.calendar_today_outlined, theme),
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
                                      color: theme.colorScheme.outline.withValues(alpha: 0.08),
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
                                        Flexible(
                                          child: Text(
                                            _formatDate(tempDueDate),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                                      color: theme.colorScheme.outline.withValues(alpha: 0.08),
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
                                        Flexible(
                                          child: Text(
                                            tempTime != null 
                                                ? _formatTime(tempTime)
                                                : (t.time),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: tempTime != null
                                                  ? theme.colorScheme.onSurface
                                                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                            t.reminders,
                            Icons.notifications_outlined,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          ReminderSelector(
                            selectedReminders: tempReminders,
                            onChanged: (list) => setSheetState(() {
                              tempReminders = list;
                            }),
                            langCode: langCode,
                            theme: theme,
                          ),
                          const SizedBox(height: 24),

                          // Секция: Подзадачи
                          _buildSectionLabel(
                            t.subtasks,
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
                                              : theme.colorScheme.outline.withValues(alpha: 0.3),
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
                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                                  title: Text(t.newSubtask),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: t.enterSubtask,
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
                                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
                                    t.addSubtask,
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
                            t.notes,
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
                                  title: Text(t.notes),
                                  content: TextField(
                                    controller: controller,
                                    maxLines: 6,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: t.additionalInfo,
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
                                      child: Text(t.save),
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
                                color: theme.colorScheme.outline.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: tempNotes.trim().isNotEmpty
                                    ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    tempNotes.trim().isNotEmpty ? Icons.note_rounded : Icons.note_add_outlined,
                                    size: 20,
                                    color: tempNotes.trim().isNotEmpty
                                        ? Colors.amber.shade700
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      tempNotes.trim().isNotEmpty
                                          ? tempNotes.trim()
                                          : (t.addNote),
                                      style: TextStyle(
                                        color: tempNotes.trim().isNotEmpty
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (tempNotes.trim().isNotEmpty)
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                          color: Colors.black.withValues(alpha: 0.05),
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

                          Task? _openShoppingAfterCreate;
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
                            if (existing.template == null || existing.template == 'shopping') { existing.template = tempCategoryId == 'shopping' ? 'shopping' : null; }
                            await existing.save();
                            await NotificationService().scheduleForTask(existing);
                          } else {
                            // Auto-detect template от category
                            final String? autoTemplate = tempCategoryId == 'shopping' ? 'shopping' : null;
                            
                            final newTask = Task(
                              title: titleText,
                              dueDate: dueDateToSave,
                              categoryId: tempCategoryId,
                              priority: tempPriority,
                              recurrence: recurrenceToSave,
                              reminders: tempReminders.isEmpty ? null : tempReminders,
                              notes: tempNotes.trim().isEmpty ? null : tempNotes.trim(),
                              template: autoTemplate,
                            );
                            newTask.setSubtasks(tempSubtasks);
                            await taskBox.add(newTask);
                            AdService().onUserAction();
                            // Google Calendar sync
                            if (GoogleCalendarService().isConnected) {
                              final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
                              if (eventId != null) {
                                newTask.googleCalendarEventId = eventId;
                                await newTask.save();
                              }
                            }

                            await NotificationService().scheduleForTask(newTask);
                            _openShoppingAfterCreate = autoTemplate == 'shopping' ? newTask : null;
                          }

                          await WidgetService.updateWidget();
                          _titleController.clear();
                          refreshParent();  // Обновяваме главния екран
                          if (innerContext.mounted) Navigator.pop(innerContext);
                          if (_openShoppingAfterCreate != null && context.mounted) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ShoppingListScreen(task: _openShoppingAfterCreate!),
                            )).then((_) => refreshParent());
                          }
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
                              ? (t.saveChanges)
                              : (t.addTask),
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
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildSectionLabel(String label, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.withValues(alpha: 0.3),
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
        color: theme.colorScheme.outline.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                ? color.withValues(alpha: 0.15) 
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: selected ? [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
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
                color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                        ? color.withValues(alpha: 0.8)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    final langCode = languageController.locale.languageCode;

    final tasks = _filteredTasks();
    final categoriesMap = {
      for (var c in categoryBox.values) c.id: c,
    };

    final (total, completed, overdue, upcoming, archived) = _stats();

    final List<Object> items = [];
    if (tasks.isNotEmpty) {
      // Групираме по дата САМО ако сортираме по дата
      if (_sortBy == TaskSort.date) {
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
      } else {
        // За другите сортирания - без групиране
        items.addAll(tasks);
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
        actions: [
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: t.sortBy,
            onSelected: (sort) => setState(() => _sortBy = sort),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: TaskSort.date,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: _sortBy == TaskSort.date ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.date,
                      style: TextStyle(
                        fontWeight: _sortBy == TaskSort.date ? FontWeight.bold : null,
                        color: _sortBy == TaskSort.date ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TaskSort.priority,
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 20,
                      color: _sortBy == TaskSort.priority ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.priority,
                      style: TextStyle(
                        fontWeight: _sortBy == TaskSort.priority ? FontWeight.bold : null,
                        color: _sortBy == TaskSort.priority ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TaskSort.name,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha_rounded,
                      size: 20,
                      color: _sortBy == TaskSort.name ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.name,
                      style: TextStyle(
                        fontWeight: _sortBy == TaskSort.name ? FontWeight.bold : null,
                        color: _sortBy == TaskSort.name ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TaskSort.category,
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_rounded,
                      size: 20,
                      color: _sortBy == TaskSort.category ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.category,
                      style: TextStyle(
                        fontWeight: _sortBy == TaskSort.category ? FontWeight.bold : null,
                        color: _sortBy == TaskSort.category ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                        hintText: t.searchTasks,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
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
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
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
                              t.all,
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
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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

                        final isOverdue = _isTaskOverdue(task);
                        final isCompleted = task.isCompleted;
                        final hasReminder = task.hasReminders;

                        // Цветът на лентата: червен ако е просрочено, иначе цвета на категорията
                        final accentColor = isOverdue
                            ? Colors.redAccent
                            : (_templateAccentColor(task.template) 
                                ?? categoryColor);

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
                                      ? (t.restore)
                                      : (t.done),
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
                                  t.delete,
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
                              if (task.isCompleted) AdService().onUserAction();

                              if (!wasCompleted && task.isCompleted && task.recurrence != null) {
                                final nextDate = _nextDueDate(task.dueDate, task.recurrence!);
                                final newTask = Task(
                                  title: task.title,
                                  dueDate: nextDate,
                                  categoryId: task.categoryId,
                                  priority: task.priority,
                                  recurrence: task.recurrence,
                                  reminders: task.reminders,
                                  template: task.template,
                                  notes: task.notes,
                                );
                                await taskBox.add(newTask);
                            // Google Calendar sync
                            if (GoogleCalendarService().isConnected) {
                              final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
                              if (eventId != null) {
                                newTask.googleCalendarEventId = eventId;
                                await newTask.save();
                              }
                            }

                                await NotificationService().scheduleForTask(newTask);
                              }

                              if (task.isCompleted) {
                                await NotificationService().cancelForTask(task);
                              } else if (task.hasReminders) {
                                await NotificationService().scheduleForTask(task);
                              }

                              await WidgetService.updateWidget();
                              setState(() {});
                              
                              // Проверка за празнуване
                              if (!wasCompleted && task.isCompleted) {
                                _checkAndCelebrate(taskDate: task.dueDate, onComplete: () {
                                  if (context.mounted) ReviewService().onTaskCompleted(context);
                                });
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
                            await task.delete();
                            await WidgetService.updateWidget();
                            setState(() {});
                          },
                          child: GestureDetector(
                          onTap: () {
                            // Shopping List специален екран
                            if (task.categoryId == 'shopping' || task.template == 'shopping') {
                              ShoppingListScreen.show(context, task).then((_) => setState(() {}));
                              return;
                            }
                            // Edit диалог по тип
                            if (task.template == 'birthday') { BirthdayDialog.show(context, existing: task).then((_) => setState(() {})); return; }
                            if (task.template == 'meeting') { MeetingDialog.show(context, existing: task).then((_) => setState(() {})); return; }
                            if (task.template == 'workout') { WorkoutDialog.show(context, existing: task).then((_) => setState(() {})); return; }
                            if (task.template == 'payment') { PaymentDialog.show(context, existing: task).then((_) => setState(() {})); return; }
                            if (task.template == 'travel') { TravelDialog.show(context, existing: task).then((_) => setState(() {})); return; }
                            if (task.template == 'gift') { GiftDialog.show(context, existing: task).then((_) => setState(() {})); return; }
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
                                          ShoppingListScreen.show(context, task).then((_) => setState(() {}));
                                        } else {
                                          _openTaskDialog(existing: task);
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
                                          setState(() {});
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
                                          setState(() {});
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
                          child: ExpandableTaskCard(
                                task: task,
                                category: cat,
                                isOverdue: isOverdue,
                                isCompleted: isCompleted,
                                isExpanded: _expandedCards.contains(task.key),
                                onToggleExpand: () {
                                  if (task.categoryId == 'shopping' || task.template == 'shopping') {
                                    ShoppingListScreen.show(context, task).then((_) => setState(() {}));
                                    return;
                                  }
                                  setState(() {
                                    if (_expandedCards.contains(task.key)) {
                                      _expandedCards.remove(task.key);
                                    } else {
                                      _expandedCards.add(task.key);
                                    }
                                  });
                                },
                                onToggleComplete: () async {
                                  final wasCompleted = task.isCompleted;
                                  setState(() {
                                    task.isCompleted = !task.isCompleted;
                                  });
                                  await task.save();
                                  if (!wasCompleted && task.isCompleted) AdService().onUserAction();
                                  
                                  if (!wasCompleted && task.isCompleted && task.recurrence != null) {
                                    final nextDate = _nextDueDate(task.dueDate, task.recurrence!);
                                    final newTask = Task(
                                      title: task.title,
                                      dueDate: nextDate,
                                      categoryId: task.categoryId,
                                      priority: task.priority,
                                      recurrence: task.recurrence,
                                      reminders: task.reminders,
                                      template: task.template,
                                      notes: task.notes,
                                    );
                                    await taskBox.add(newTask);
                            // Google Calendar sync
                            if (GoogleCalendarService().isConnected) {
                              final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
                              if (eventId != null) {
                                newTask.googleCalendarEventId = eventId;
                                await newTask.save();
                              }
                            }

                                    await NotificationService().scheduleForTask(newTask);
                                  }
                                  
                                  if (task.isCompleted) {
                                    await NotificationService().cancelForTask(task);
                                  } else if (task.hasReminders) {
                                    await NotificationService().scheduleForTask(task);
                                  }
                                  
                                  await WidgetService.updateWidget();
                                  setState(() {});
                                  
                                  if (!wasCompleted && task.isCompleted) {
                                    _checkAndCelebrate(taskDate: task.dueDate, onComplete: () {
                                      if (context.mounted) ReviewService().onTaskCompleted(context);
                                    });
                                  }
                                },
                                onEdit: () {
                                  if (task.categoryId == 'shopping' || task.template == 'shopping') {
                                    ShoppingListScreen.show(context, task).then((_) => setState(() {}));
                                  } else if (task.template == 'birthday') {
                                    BirthdayDialog.show(context, existing: task).then((_) => setState(() {}));
                                  } else if (task.template == 'meeting') {
                                    MeetingDialog.show(context, existing: task).then((_) => setState(() {}));
                                  } else if (task.template == 'workout') {
                                    WorkoutDialog.show(context, existing: task).then((_) => setState(() {}));
                                  } else if (task.template == 'payment') {
                                    PaymentDialog.show(context, existing: task).then((_) => setState(() {}));
                                  } else if (task.template == 'travel') {
                                    TravelDialog.show(context, existing: task).then((_) => setState(() {}));
                                  } else if (task.template == 'gift') {
                                    GiftDialog.show(context, existing: task).then((_) => setState(() {}));
                                  } else {
                                    _openTaskDialog(existing: task);
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
                                    await task.delete();
                                    await WidgetService.updateWidget();
                                    setState(() {});
                                  }
                                },
                                dateTimeStr: dateTimeStr,
                                priorityText: priorityText,
                                priorityColor: priorityColor,
                                accentColor: accentColor,
                                categoryName: categoryName,
                                recurrenceText: task.recurrence != null ? _recurrenceLabel(task.recurrence, t) : null,
                              ),
                        ), // Dismissible
                        ), // TweenAnimationBuilder
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
                  final screenSize = MediaQuery.sizeOf(context);
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
                onPressed: () async {
                final type = await TaskTypeSelector.show(context);
                if (type == null || !mounted) return;
                if (type == 'shopping') { ShoppingListScreen.create(context).then((_) => setState(() {})); return; }
                if (type == 'birthday') { BirthdayDialog.show(context).then((_) => setState(() {})); return; }
                if (type == 'meeting') { MeetingDialog.show(context).then((_) => setState(() {})); return; }
                if (type == 'workout') { WorkoutDialog.show(context).then((_) => setState(() {})); return; }
                if (type == 'payment') { PaymentDialog.show(context).then((_) => setState(() {})); return; }
                if (type == 'travel') { TravelDialog.show(context).then((_) => setState(() {})); return; }
                if (type == 'gift') { GiftDialog.show(context).then((_) => setState(() {})); return; }
                _openTaskDialog();
              },
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}















