import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../services/google_calendar_service.dart';
import '../../services/ios_calendar_service.dart';
import '../../services/name_days_service.dart';
// name_day_card.dart вече не се ползва — картичките се правят в уеб генератора.
import '../../services/contact_name_index.dart';
import '../../services/holidays_service.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/task.dart';
import '../../services/analytics_service.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../utils/category_colors.dart';
import '../../services/notification_service.dart';
import '../../services/tombstone_service.dart';
import '../../widgets/reminder_selector.dart';
import '../../services/widget_service.dart';
import '../../services/task_view_preference.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/task_card_styles.dart';
import '../../widgets/pomodoro_timer_sheet.dart';
import '../../widgets/gift_cta.dart';
import '../../models/weekly_schedule.dart';
import '../../services/weekly_schedule_service.dart';

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
  final Set<int> _expandedCards = {};
  bool _needsDefaults = false;

  /// Цвят на слоя „Именни дни" в календара (различен от задачите/празниците).
  static const Color _nameDayColor = Color(0xFF8E24AA);
  bool get _nameDaysEnabled => NameDaysService.enabledNotifier.value;

  /// Цвят на слоя „Официални празници" (различен от именните дни).
  static const Color _holidayColor = Color(HolidaysService.colorValue);
  bool get _holidaysEnabled => HolidaysService.enabledNotifier.value;

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasks');
    categoryBox = Hive.box<Category>('categories');

    // Слушаме за промени в задачите
    taskBox.listenable().addListener(_onTasksChanged);
    // Промени в категориите (цвят/име) → дневните карти се преоцветяват веднага
    categoryBox.listenable().addListener(_onTasksChanged);

    _loadNameDays();
    _loadHolidays();
    // Реагираме веднага щом toggle-ите се сменят в Настройки.
    NameDaysService.enabledNotifier.addListener(_onNameDaysToggle);
    HolidaysService.enabledNotifier.addListener(_onNameDaysToggle);
    HolidaysService.revision.addListener(_onNameDaysToggle);
    // Контакти с имен ден (опционално, on-device) — банерът ги показва.
    ContactNameIndex().enabledNotifier.addListener(_onNameDaysToggle);
    // Обнови банера, щом фоновото изграждане на индекса завърши.
    ContactNameIndex().revision.addListener(_onNameDaysToggle);

    if (categoryBox.isEmpty) {
      _needsDefaults = true;
    }
    _selectedCategoryId = categoryBox.isEmpty ? '' : categoryBox.values.first.id;

    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_needsDefaults) return;
    _needsDefaults = false;
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
    // Добавяме само липсващите категории (не презаписваме потребителски промени)
    for (final c in defaults) {
      if (!categoryBox.containsKey(c.id)) {
        categoryBox.put(c.id, c);
      }
    }
    if (categoryBox.isNotEmpty && _selectedCategoryId.isEmpty) {
      _selectedCategoryId = categoryBox.values.first.id;
    }
  }

  @override
  void dispose() {
    taskBox.listenable().removeListener(_onTasksChanged);
    categoryBox.listenable().removeListener(_onTasksChanged);
    NameDaysService.enabledNotifier.removeListener(_onNameDaysToggle);
    HolidaysService.enabledNotifier.removeListener(_onNameDaysToggle);
    HolidaysService.revision.removeListener(_onNameDaysToggle);
    ContactNameIndex().enabledNotifier.removeListener(_onNameDaysToggle);
    ContactNameIndex().revision.removeListener(_onNameDaysToggle);
    super.dispose();
  }

  void _onNameDaysToggle() {
    if (mounted) setState(() {});
  }

  /// Зарежда официалните празници (offline-first) и стойността на toggle-а.
  Future<void> _loadHolidays() async {
    await HolidaysService().loadEnabled();
    if (HolidaysService.enabledNotifier.value) {
      await HolidaysService().loadForCurrentYears();
    }
    if (mounted) setState(() {});
  }

  void _onTasksChanged() {
    if (mounted) setState(() {});
  }

  /// Зарежда българските именни дни и стойността на toggle-а.
  Future<void> _loadNameDays() async {
    await NameDaysService().load();
    await NameDaysService().loadEnabled();
    // Зарежда кешираните контакти (без сканиране), за да са готови за банера.
    if (await ContactNameIndex().loadEnabled()) {
      await ContactNameIndex().ensureLoaded();
    }
    if (mounted) setState(() {});
  }

  void _checkAndShowCelebration() {
    final dayTasks = taskBox.values.where((task) {
      final taskDate = _normalizeDate(task.dueDate);
      return taskDate == _selectedDay && !task.isArchived;
    }).toList();
    
    if (dayTasks.isNotEmpty && dayTasks.every((t) => t.isCompleted)) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) showCelebration(context);
      });
    }
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

  // Етикет за синтетичния „Училище" чип (11 езика).
  static const Map<String, String> _schoolLabel = {
    'en': 'School', 'bg': 'Училище', 'de': 'Schule', 'fr': 'École',
    'it': 'Scuola', 'el': 'Σχολείο', 'es': 'Escuela', 'pt': 'Escola',
    'ru': 'Школа', 'tr': 'Okul', 'ja': '学校',
  };

  /// Шийт за избор на учебен предмет (зад чипа „🎒 Училище"). Връща избрания.
  Future<Category?> _pickSchoolSubject(List<Category> subjects, AppText t) {
    return showModalBottomSheet<Category>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('🎒 ${_schoolLabel[t.lang] ?? _schoolLabel['en']!}',
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
            for (final s in subjects)
              ListTile(
                leading: CircleAvatar(
                    radius: 9, backgroundColor: Color(s.colorValue)),
                title: Text(s.name),
                onTap: () => Navigator.pop(ctx, s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _localizedCategoryName(Category? c, AppText t) {
    if (c == null) return '';
    // Календарната категория не е „default", но id-то е фиксирано → локализира се винаги.
    if (c.id == 'cal_events') return t.catCalendarEvents;
    if (c.id == 'documents') return t.catDocuments;
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

  static const List<Color> _categoryColors = kCategoryColors;

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
                        textCapitalization: TextCapitalization.sentences,
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

  Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) async {
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
                height: 370,
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

  void _openTaskDialog({Task? existing}) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final bool isEditing = existing != null;
    final refreshParent = () => setState(() {});  // Запазваме референция към главния setState

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
            final langCode = languageController.locale.languageCode;
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
                            textCapitalization: TextCapitalization.sentences,
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
                              // Училищните предмети (subj_*) са зад чипа „🎒 Училище".
                              ...categories
                                  .where((c) => !c.id.startsWith('subj_'))
                                  .map((cat) {
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
                              // Синтетичен чип „🎒 Училище" (ако има добавени предмети).
                              if (categories.any((c) => c.id.startsWith('subj_')))
                                Builder(builder: (_) {
                                  final subjects = categories
                                      .where((c) => c.id.startsWith('subj_'))
                                      .toList();
                                  final sel = subjects
                                      .where((c) => c.id == tempCategoryId);
                                  final selSubj = sel.isEmpty ? null : sel.first;
                                  final schoolColor = selSubj != null
                                      ? Color(selSubj.colorValue)
                                      : const Color(0xFF6A3DE8);
                                  final isSel = selSubj != null;
                                  final label = selSubj != null
                                      ? '🎒 ${selSubj.name}'
                                      : '🎒 ${_schoolLabel[t.lang] ?? _schoolLabel['en']!}';
                                  return GestureDetector(
                                    onTap: () async {
                                      final picked = await _pickSchoolSubject(
                                          subjects, t);
                                      if (picked != null) {
                                        setSheetState(() {
                                          tempCategoryId = picked.id;
                                          _selectedCategoryId = picked.id;
                                        });
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? schoolColor.withValues(alpha: 0.2)
                                            : theme.colorScheme.outline
                                                .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: isSel
                                                ? schoolColor
                                                : Colors.transparent,
                                            width: 2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(label,
                                              style: TextStyle(
                                                  fontWeight: isSel
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: isSel
                                                      ? schoolColor
                                                      : theme.colorScheme
                                                          .onSurface)),
                                          const SizedBox(width: 4),
                                          Icon(Icons.expand_more,
                                              size: 18,
                                              color: isSel
                                                  ? schoolColor
                                                  : theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.5)),
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
                                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                                        Text(
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
                                    textCapitalization: TextCapitalization.sentences,
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
                            AnalyticsService().logTaskCreated(newTask);
                            // Google Calendar sync (само ако Apple не е активен).
                            if (GoogleCalendarService().isConnected && !IosCalendarService.exportEnabled) {
                              final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
                              if (eventId != null) {
                                newTask.googleCalendarEventId = eventId;
                                await newTask.save();
                              }
                            }
                            // Apple Calendar (export-only)
                            if (!kIsWeb && IosCalendarService.exportEnabled) {
                              await IosCalendarService().syncTask(newTask);
                            }

                            await NotificationService().scheduleForTask(newTask);
                          }

                          await WidgetService.updateWidget();
                          _titleController.clear();
                          refreshParent();  // Обновяваме главния екран
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

  Widget _buildViewChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
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

    final events = _buildEventMap();
    final tasks = _tasksForView();
    final categoriesMap = {
      for (var c in categoryBox.values) c.id: c,
    };

    String monthYearLabel(DateTime day) {
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

    final dayLabel = t.day;
    final weekLabel = t.week;
    final monthLabelStr = t.month;

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
                  height: 225,
                  child: TableCalendar<Task>(
                    firstDay: DateTime(2020, 1, 1),
                    lastDay: DateTime(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    rowHeight: 34,
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
                            theme.colorScheme.primary.withValues(alpha: 0.1),
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
                      // Кръг около датата за празник (червен) / имен ден (виолетов).
                      defaultBuilder: (context, day, focusedDay) =>
                          _ringedDay(context, day),
                      outsideBuilder: (context, day, focusedDay) =>
                          _ringedDay(context, day, outside: true),
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
                            children: [
                              ...markers.map((task) {
                                return Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _priorityColor(task.priority),
                                  ),
                                );
                              }),
                            ],
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

          // Целият долен блок (банери + заглавие + задачи) е в ЕДИН скрол — при
          // много имена на имен ден списъкът вече не изтласква бутона „От твоите
          // контакти" / задачите извън екрана; потребителят просто скролва.
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: tasks.length + 1,
              itemBuilder: (_, listIndex) {
                // Хедър (index 0): празничен банер + имен-ден банер + заглавие.
                if (listIndex == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_holidaysEnabled) _buildHolidayBanner(context),
                      if (_nameDaysEnabled) _buildNameDayBanner(context),
                      _buildScheduleStrip(context),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
                      if (tasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('—',
                                style: TextStyle(
                                    fontSize: 28, color: Colors.black26)),
                          ),
                        ),
                    ],
                  );
                }
                final task = tasks[listIndex - 1];
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
                      final hasTime = task.dueDate.hour != 0 || task.dueDate.minute != 0;
                      final overdueDate = hasTime ? task.dueDate : DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day, 23, 59, 59);
                      final isOverdue = !task.isCompleted && overdueDate.isBefore(now);
                      final isCompleted = task.isCompleted;

                      final accentColor = isOverdue
                          ? Colors.redAccent
                          : (_templateAccentColor(task.template)
                              ?? categoryColor);

                      return TaskCardView(
                        task: task,
                        category: cat,
                        isOverdue: isOverdue,
                        isCompleted: isCompleted,
                        isExpanded: _expandedCards.contains(task.key),
                        onToggleExpand: () {
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
                          task.isCompleted = !task.isCompleted;
                          task.completedAt = task.isCompleted ? DateTime.now() : null;
                          await task.save();
                          if (!wasCompleted && task.isCompleted) {
                            AnalyticsService().logTaskCompleted();
                          }
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
                            AnalyticsService().logTaskCreated(newTask);
                            // Google Calendar sync (само ако Apple не е активен).
                            if (GoogleCalendarService().isConnected && !IosCalendarService.exportEnabled) {
                              final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
                              if (eventId != null) {
                                newTask.googleCalendarEventId = eventId;
                                await newTask.save();
                              }
                            }
                            // Apple Calendar (export-only)
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
                          setState(() {});
                          if (task.isCompleted) _checkAndShowCelebration();
                        },
                        onEdit: () => _openTaskDialog(existing: task),
                        onDelete: () async {
                          await NotificationService().cancelForTask(task);
                          await TombstoneService().deleteTask(task);
                          await WidgetService.updateWidget();
                          setState(() {});
                        },
                        onStartPomodoro: () => PomodoroTimerSheet.show(context, task),
                        onToggleSubtask: (index) async {
                          final list = task.subtasksList;
                          if (index < 0 || index >= list.length) return;
                          list[index]['done'] = !(list[index]['done'] == true);
                          task.setSubtasks(list);
                          // Всички подзадачи готови → авто-завършване (и обратно).
                          task.syncCompletionWithSubtasks();
                          task.touch();
                          await task.save();
                          await WidgetService.updateWidget();
                          if (mounted) setState(() {});
                        },
                        dateTimeStr: dateTimeStr,
                        priorityText: priorityText,
                        priorityColor: priorityColor,
                        accentColor: accentColor,
                        categoryName: categoryName,
                        recurrenceText: task.recurrence != null ? _recurrenceLabel(task.recurrence, t) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Огражда датата с кръг, ако е официален празник (червен) и/или имен ден
  /// (виолетов). При двете — концентрични пръстени. Връща null за обикновен
  /// ден (тогава TableCalendar рендира по подразбиране).
  Widget? _ringedDay(BuildContext context, DateTime day, {bool outside = false}) {
    final hasHoliday =
        _holidaysEnabled && HolidaysService().forDate(day) != null;
    final hasNameDay =
        _nameDaysEnabled && NameDaysService().forDate(day) != null;
    if (!hasHoliday && !hasNameDay) return null;

    final theme = Theme.of(context);
    final op = outside ? 0.4 : 1.0;
    final textColor = outside
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : theme.colorScheme.onSurface;
    final numberText =
        Text('${day.day}', style: TextStyle(fontSize: 14, color: textColor));

    Widget core;
    if (hasHoliday && hasNameDay) {
      // Концентрични пръстени: външен червен, вътрешен виолетов.
      core = Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: _holidayColor.withValues(alpha: op), width: 1.6),
        ),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: _nameDayColor.withValues(alpha: op), width: 1.6),
          ),
          child: numberText,
        ),
      );
    } else {
      core = Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: (hasHoliday ? _holidayColor : _nameDayColor)
                .withValues(alpha: op),
            width: 1.6,
          ),
        ),
        child: numberText,
      );
    }
    return Center(child: core);
  }

  /// Read-only банер за официалния празник на избрания ден.
  /// localName идва от Nager.Date (вече на местния език). Връща празно,
  /// ако денят не е официален празник.
  /// Лента с уроците/лекциите за избрания ден (Режими Уча — седмичен разпис).
  /// Показва се само ако има слотове за деня; иначе нищо.
  Widget _buildScheduleStrip(BuildContext context) {
    return AnimatedBuilder(
      animation: WeeklyScheduleService.revision,
      builder: (context, _) {
        final slots = WeeklyScheduleService().forDay(_selectedDay.weekday);
        if (slots.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          // Един час → статичен чип; повече → редуват се циклично, за да не
          // затрупват реда.
          child: slots.length == 1
              ? scheduleSlotChip(context, slots.first)
              : _ScheduleRotator(
                  key: ValueKey('sched_${_selectedDay.weekday}'),
                  slots: slots,
                ),
        );
      },
    );
  }

  Widget _buildHolidayBanner(BuildContext context) {
    final name = HolidaysService().forDate(_selectedDay);
    if (name == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _holidayColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _holidayColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Text('🎌', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _holidayColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Read-only банер за именния ден на избрания ден.
  /// Празникът и имената идват от dataset-а (на български); локализира се
  /// само етикетът „Имен ден". Връща празно, ако денят няма имен ден.
  Widget _buildNameDayBanner(BuildContext context) {
    final nameDay = NameDaysService().forDate(_selectedDay);
    if (nameDay == null) return const SizedBox.shrink();

    final lang = LanguageScope.of(context).locale.languageCode;
    const label = {
      'en': 'Name day',
      'bg': 'Имен ден',
      'de': 'Namenstag',
      'fr': 'Fête du prénom',
      'it': 'Onomastico',
      'el': 'Ονομαστική εορτή',
      'es': 'Onomástica',
      'pt': 'Dia do nome',
      'ru': 'Именины',
      'tr': 'İsim günü', 'ja': '聖名祝日',
    };
    final theme = Theme.of(context);

    // Контакти с имен ден днес (само ако функцията е вкл.; on-device).
    final contacts = ContactNameIndex().isEnabled
        ? ContactNameIndex().contactsForNames(nameDay.names)
        : const <ContactMatch>[];
    const fromContacts = {
      'en': 'From your contacts:', 'bg': 'От твоите контакти:',
      'de': 'Aus deinen Kontakten:', 'fr': 'Parmi tes contacts :',
      'it': 'Dai tuoi contatti:', 'el': 'Από τις επαφές σου:',
      'es': 'De tus contactos:', 'pt': 'Dos teus contactos:',
      'ru': 'Из твоих контактов:', 'tr': 'Kişilerinden:',
      'ja': '連絡先から：',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _nameDayColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _nameDayColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${label[lang] ?? label['en']!} · ${nameDay.feast}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _nameDayColor,
                  ),
                ),
                if (nameDay.names.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    nameDay.names.join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                if (contacts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // Списъкът е в изскачащ прозорец — побира произволен брой
                  // контакти, без да се чупи банерът при повече от два.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: _nameDayColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showNameDayContacts(
                            contacts, nameDay.feast, lang),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.celebration_rounded,
                                  size: 16, color: Color(0xFF8E24AA)),
                              const SizedBox(width: 6),
                              Text(
                                '${fromContacts[lang] ?? fromContacts['en']!} ${contacts.length}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Готовата честитка за имен ден (локализирана).
  String _wishText(String name, String lang) {
    const wishTpl = {
      'en': 'Happy name day, {name}! 🎉', 'bg': 'Честит имен ден, {name}! 🎉',
      'de': 'Alles Gute zum Namenstag, {name}! 🎉',
      'fr': 'Bonne fête, {name} ! 🎉', 'it': 'Buon onomastico, {name}! 🎉',
      'el': 'Χρόνια πολλά, {name}! 🎉', 'es': '¡Feliz santo, {name}! 🎉',
      'pt': 'Feliz dia do nome, {name}! 🎉', 'ru': 'С именинами, {name}! 🎉',
      'tr': 'İsim günün kutlu olsun, {name}! 🎉',
      'ja': '{name}さん、聖名祝日おめでとう！🎉',
    };
    return (wishTpl[lang] ?? wishTpl['en']!).replaceAll('{name}', name);
  }

  /// Изскачащ прозорец със списъка на контактите, които празнуват днес.
  /// Побира произволен брой (скролва), за разлика от стария вграден списък.
  Future<void> _showNameDayContacts(
      List<ContactMatch> contacts, String feast, String lang) {
    final theme = Theme.of(context);
    const closeLbl = {
      'en': 'Close', 'bg': 'Затвори', 'de': 'Schließen', 'fr': 'Fermer',
      'it': 'Chiudi', 'el': 'Κλείσιμο', 'es': 'Cerrar', 'pt': 'Fechar',
      'ru': 'Закрыть', 'tr': 'Kapat', 'ja': '閉じる',
    };
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(feast,
                    style: const TextStyle(fontSize: 16))),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: contacts.length,
              itemBuilder: (_, i) {
                final c = contacts[i];
                final initial =
                    c.name.isNotEmpty ? c.name.characters.first : '?';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFF8E24AA).withValues(alpha: 0.15),
                    child: Text(initial,
                        style: const TextStyle(
                            color: Color(0xFF8E24AA),
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(c.name),
                  trailing: Icon(Icons.more_horiz_rounded,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _onContactTap(c, lang);
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(closeLbl[lang] ?? closeLbl['en']!),
          ),
        ],
      ),
    );
  }

  /// Тегли телефоните на контакта (при нужда) и показва менюто с действия.
  Future<void> _onContactTap(ContactMatch c, String lang) async {
    final phones = await ContactNameIndex().phonesForContact(c.id);
    if (!mounted) return;
    _showContactActions(c, phones, lang);
  }

  /// Меню с действия за контакт: Обаждане / SMS / WhatsApp / Viber + Сподели.
  /// Нищо не се праща автоматично — потребителят избира действие.
  void _showContactActions(
      ContactMatch c, List<String> phones, String lang) {
    final theme = Theme.of(context);
    final phone = phones.isNotEmpty ? phones.first : null;
    final intl = phone != null ? _phoneDigitsIntl(phone) : null;
    final wish = _wishText(c.name, lang);
    final feast = NameDaysService().forDate(_selectedDay)?.feast ?? '';

    const callLbl = {
      'en': 'Call', 'bg': 'Обаждане', 'de': 'Anrufen', 'fr': 'Appeler',
      'it': 'Chiama', 'el': 'Κλήση', 'es': 'Llamar', 'pt': 'Ligar',
      'ru': 'Позвонить', 'tr': 'Ara', 'ja': '電話',
    };
    const smsLbl = {
      'en': 'Message', 'bg': 'Съобщение', 'de': 'Nachricht', 'fr': 'SMS',
      'it': 'Messaggio', 'el': 'Μήνυμα', 'es': 'Mensaje', 'pt': 'Mensagem',
      'ru': 'Сообщение', 'tr': 'Mesaj', 'ja': 'メッセージ',
    };
    const cardLbl = {
      'en': 'Greeting card', 'bg': 'Картичка', 'de': 'Grußkarte',
      'fr': 'Carte', 'it': 'Cartolina', 'el': 'Κάρτα', 'es': 'Tarjeta',
      'pt': 'Cartão', 'ru': 'Открытка', 'tr': 'Kart', 'ja': 'カード',
    };
    const shareLbl = {
      'en': 'Share wish', 'bg': 'Сподели честитка', 'de': 'Glückwunsch teilen',
      'fr': 'Partager', 'it': 'Condividi', 'el': 'Κοινοποίηση',
      'es': 'Compartir', 'pt': 'Partilhar', 'ru': 'Поделиться',
      'tr': 'Paylaş', 'ja': '共有',
    };
    const giftLbl = {
      'en': 'Send flowers / gift', 'bg': 'Изпрати цветя/подарък',
      'de': 'Blumen / Geschenk senden', 'fr': 'Envoyer fleurs / cadeau',
      'it': 'Invia fiori / regalo', 'el': 'Στείλε λουλούδια / δώρο',
      'es': 'Enviar flores / regalo', 'pt': 'Enviar flores / presente',
      'ru': 'Цветы / подарок', 'tr': 'Çiçek / hediye gönder',
      'ja': '花・ギフトを贈る',
    };
    const noPhoneLbl = {
      'en': 'No phone number', 'bg': 'Няма телефонен номер',
      'de': 'Keine Telefonnummer', 'fr': 'Pas de numéro',
      'it': 'Nessun numero', 'el': 'Χωρίς αριθμό', 'es': 'Sin número',
      'pt': 'Sem número', 'ru': 'Нет номера', 'tr': 'Numara yok',
      'ja': '電話番号なし',
    };

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // иначе при 7+ действия долните се отрязват
      builder: (ctx) {
        Widget action(IconData icon, Color color, String label,
            VoidCallback onTap) {
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(label),
            onTap: () {
              Navigator.of(ctx).pop();
              onTap();
            },
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              if (phone != null) ...[
                action(Icons.call_rounded, Colors.green,
                    callLbl[lang] ?? callLbl['en']!,
                    () => _launchExternal('tel:$phone')),
                action(Icons.sms_rounded, Colors.blue,
                    smsLbl[lang] ?? smsLbl['en']!,
                    () => _launchExternal(
                        'sms:$phone?body=${Uri.encodeComponent(wish)}')),
                action(Icons.chat_rounded, const Color(0xFF25D366),
                    'WhatsApp', () => _launchWhatsApp(intl!, wish)),
                action(Icons.phone_in_talk_rounded, const Color(0xFF7360F2),
                    'Viber',
                    () => _launchExternal(
                        'viber://forward?text=${Uri.encodeComponent(wish)}')),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(noPhoneLbl[lang] ?? noPhoneLbl['en']!,
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              action(Icons.card_giftcard_rounded, const Color(0xFFAB47BC),
                  cardLbl[lang] ?? cardLbl['en']!,
                  () async {
                    // Отваря уеб генератора на картички (18 снимки + избор на фон)
                    // с попълнено име. По-богат от вградения + фоновете се обновяват
                    // без нов релийс.
                    final url =
                        'https://taskify1969.com/imen-den/?name=${Uri.encodeComponent(c.name)}';
                    if (!await _tryLaunch(url)) _toastLaunchFail();
                  }),
              action(Icons.celebration_rounded, const Color(0xFF8E24AA),
                  shareLbl[lang] ?? shareLbl['en']!,
                  () => _shareNameDayWish(c.name, lang)),
              // „Изпрати цветя/подарък" (монетизация — засега „Очаквайте скоро").
              action(Icons.local_florist_rounded, const Color(0xFF39FF14),
                  giftLbl[lang] ?? giftLbl['en']!,
                  () => GiftOffer.tap(context, lang: lang, kind: 'gift_nameday')),
              const SizedBox(height: 8),
            ],
          ),
          ),
        );
      },
    );
  }

  /// Нормализира телефон към международни цифри без „+" (BG по подразбиране).
  /// За WhatsApp/Viber, които искат международен формат.
  String _phoneDigitsIntl(String raw) {
    var d = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (d.startsWith('+')) return d.substring(1);
    if (d.startsWith('00')) return d.substring(2);
    if (d.startsWith('0')) return '359${d.substring(1)}'; // нац. → межд.
    return d;
  }

  /// Опитва да отвори URL във външно приложение; връща дали е успяло.
  Future<bool> _tryLaunch(String url) async {
    try {
      return await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void _toastLaunchFail() {
    final lang = LanguageScope.of(context).locale.languageCode;
    const failLbl = {
      'en': 'Could not open the app', 'bg': 'Приложението не може да се отвори',
      'de': 'App konnte nicht geöffnet werden', 'fr': "Impossible d'ouvrir",
      'it': "Impossibile aprire l'app", 'el': 'Δεν άνοιξε η εφαρμογή',
      'es': 'No se pudo abrir la app', 'pt': 'Não foi possível abrir',
      'ru': 'Не удалось открыть приложение', 'tr': 'Uygulama açılamadı',
      'ja': 'アプリを開けませんでした',
    };
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failLbl[lang] ?? failLbl['en']!)),
      );
    }
  }

  /// Отваря външно приложение (dialer/SMS/Viber). Тих toast при отказ.
  Future<void> _launchExternal(String url) async {
    if (!await _tryLaunch(url)) _toastLaunchFail();
  }

  /// WhatsApp: първо app-схемата (директно приложението), после уеб fallback.
  Future<void> _launchWhatsApp(String intl, String wish) async {
    final enc = Uri.encodeComponent(wish);
    if (await _tryLaunch('whatsapp://send?phone=$intl&text=$enc')) return;
    if (await _tryLaunch('https://wa.me/$intl?text=$enc')) return;
    _toastLaunchFail();
  }

  /// Отваря системния share лист с честитка за имен ден. Нищо не се праща
  /// автоматично — потребителят сам избира приложение/получател.
  Future<void> _shareNameDayWish(String contactName, String lang) async {
    final text = _wishText(contactName, lang);

    // iOS popover anchor (share_plus иска non-zero sharePositionOrigin на iPad).
    final box = context.findRenderObject() as RenderBox?;
    final size = MediaQuery.of(context).size;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 1,
            height: 1,
          );

    await Share.share(text, sharePositionOrigin: origin);
  }
}

/// Един чип за слот от седмичното разписание (ползван и статично, и в ротатора).
Widget scheduleSlotChip(BuildContext context, ScheduleSlot s) {
  final theme = Theme.of(context);
  final label =
      '${s.fromLabel} ${s.subject.isNotEmpty ? s.subject : (s.kind == SlotKind.lecture ? '🎓' : '🎒')}';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    ),
  );
}

/// Показва часовете за деня с редуване (по един на всеки няколко секунди), когато
/// са повече от един — за да не затрупват реда. Показва и брояч „i/n".
class _ScheduleRotator extends StatefulWidget {
  final List<ScheduleSlot> slots;
  const _ScheduleRotator({required this.slots, super.key});

  @override
  State<_ScheduleRotator> createState() => _ScheduleRotatorState();
}

class _ScheduleRotatorState extends State<_ScheduleRotator> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.slots.length < 2) return;
      setState(() => _i = (_i + 1) % widget.slots.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = _i % widget.slots.length;
    final s = widget.slots[idx];
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Container(
                key: ValueKey(s.id),
                child: scheduleSlotChip(context, s),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${idx + 1}/${widget.slots.length}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}



