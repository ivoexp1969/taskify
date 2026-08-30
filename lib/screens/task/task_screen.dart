import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/google_calendar_service.dart';
import '../../services/ios_calendar_service.dart';
import '../../services/sync_service.dart';
import '../../services/calendar_import_service.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/task.dart';
import '../../services/analytics_service.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../utils/category_colors.dart';
import '../../services/notification_service.dart';
import '../../widgets/reminder_selector.dart';
import '../../services/widget_service.dart';
import '../../services/ad_service.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/study_countdown_card.dart';
import '../../widgets/shared_tasks_section.dart';
import 'shopping_list_screen.dart';
import 'task_type_selector.dart';
import 'eisenhower_screen.dart';
import 'editor/task_editor_sheet.dart';
import 'birthday_dialog.dart';
import 'meeting_dialog.dart';
import 'workout_dialog.dart';
import 'payment_dialog.dart';
import 'travel_dialog.dart';
import 'gift_dialog.dart';
import 'document_dialog.dart';
import 'study_task_dialog.dart';
import '../../widgets/ai_limit.dart';
import '../shared/shared_groups_screen.dart';
import '../../utils/natural_language_parser.dart';
import '../../services/ai_service.dart';
import '../../services/ai_usage_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../paywall/paywall_screen.dart';
import '../../services/pro_service.dart';
import 'sections/productivity_banner.dart';
import 'dialogs/date_picker_dialog.dart';
import 'sections/task_editor_widgets.dart';
import 'sections/task_list_tile.dart';
import 'sections/task_format.dart';

enum TaskFilter { all, active, completed, overdue, upcoming, archived }
enum TaskSort { date, priority, name, category }

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

/// Мост, който позволява на ДРУГИ екрани (напр. споделените групи) да отворят
/// ТОЧНО СЪЩИЯ редактор за задача като таб „Задачи", без дублиране на UI.
/// TaskScreen живее в IndexedStack (винаги инстанциран) → `_current` е наличен.
/// При `onSave` редакторът не пипа Hive/календар/нотификации — само връща
/// готовата [Task] през callback-а (извикващият решава къде да я запише).
class TaskEditorBridge {
  static _TaskScreenState? _current;

  static bool get isReady => _current != null;

  static Future<void> open({
    Task? existing,
    required Future<void> Function(Task draft) onSave,
  }) async {
    final s = _current;
    if (s == null) return;
    await s._openTaskDialog(existing: existing, onSave: onSave);
  }

  /// ФАЗА 4: отваря СТАНДАРТНИЯ редактор за нова задача (self-managed запис,
  /// точно като FAB бутона) — ползва се от ден-3 engagement нотификацията, за
  /// да „отвори AI полето".
  static Future<void> openNewSelfManaged() async {
    final s = _current;
    if (s == null) return;
    await s._openTaskDialog();
  }
}

class _TaskScreenState extends State<TaskScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
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
  late SpeechToText _speech;
  bool _isListening = false;
  late AnimationController _micPulseController;

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    TaskEditorBridge._current = this; // позволи на други екрани (групи) да ползват СЪЩИЯ редактор
    taskBox = Hive.box<Task>('tasks');
    categoryBox = Hive.box<Category>('categories');
    _speech = SpeechToText();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Слушаме за промени в задачите
    taskBox.listenable().addListener(_onTasksChanged);
    // Слушаме за промени в категориите (цвят/име) → картите се преоцветяват веднага
    categoryBox.listenable().addListener(_onTasksChanged);

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _listAnimationController.forward();

    if (categoryBox.isEmpty) {
      _needsDefaults = true;
    }

    _selectedCategoryId = categoryBox.isEmpty ? '' : categoryBox.values.first.id;

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingQuickAdd();
      _autoSyncCalendar();
    });
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
    _maybeDedupeCategories();
  }

  static bool _dedupeChecked = false;

  /// Еднократно де-дублиране на категории по ПОКАЗАНОТО (локализирано) име —
  /// напр. системната „Документи" (raw „Documents") и потребителска „Документи"
  /// изглеждат еднакво, но имат различни сурови имена, затова се сравняват по
  /// показаното име. Задачите се прехвърлят към канонична/първа; дублите се трият.
  void _maybeDedupeCategories() {
    if (_dedupeChecked) return;
    _dedupeChecked = true;
    final t = AppText.of(context);
    const canonical = {
      'documents', 'cal_events', 'work', 'personal', 'shopping', 'birthday',
      'meeting', 'workout', 'payment', 'travel', 'gift',
    };
    SharedPreferences.getInstance().then((prefs) async {
      // v2: трие дубликата И от облака (иначе sync го връща).
      if (prefs.getBool('dedupe_cat_display_v2') ?? false) return;
      final keptByName = <String, String>{}; // показано име (lower) → запазено id
      final toDelete = <String>[];
      for (final c in categoryBox.values) {
        final key = localizedCategoryName(c, t).trim().toLowerCase();
        if (key.isEmpty) continue;
        final keptId = keptByName[key];
        if (keptId == null) {
          keptByName[key] = c.id;
          continue;
        }
        if (keptId == c.id) continue;
        // Реши коя да запазим: предпочитаме каноничната (системна/default).
        String keep = keptId, drop = c.id;
        if (!canonical.contains(keptId) && canonical.contains(c.id)) {
          keep = c.id;
          drop = keptId;
          keptByName[key] = keep;
        }
        for (final task in taskBox.values.where((x) => x.categoryId == drop)) {
          task.categoryId = keep;
          await task.save();
        }
        toDelete.add(drop);
      }
      for (final id in toDelete) {
        await categoryBox.delete(id);
        await SyncService().deleteCloudCategory(id); // и от облака
      }
      await prefs.setBool('dedupe_cat_display_v2', true);
      if (mounted && toDelete.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    if (TaskEditorBridge._current == this) TaskEditorBridge._current = null;
    WidgetsBinding.instance.removeObserver(this);
    _listAnimationController.dispose();
    _micPulseController.dispose();
    _titleController.dispose();
    _searchController.dispose();
    if (_isListening) _speech.cancel();
    taskBox.listenable().removeListener(_onTasksChanged);
    categoryBox.listenable().removeListener(_onTasksChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPendingQuickAdd();
  }

  Future<void> _checkPendingQuickAdd() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('quick_add_pending_title')?.trim();
    if (title == null || title.isEmpty) return;
    await prefs.remove('quick_add_pending_title');
    if (!mounted) return;

    final lang = LanguageScope.of(context).locale.languageCode;
    final nlp = NaturalLanguageParser.parse(title, lang);
    final now = DateTime.now();
    final date = nlp?.date ?? DateTime(now.year, now.month, now.day);
    final finalDate = nlp?.time != null
        ? DateTime(date.year, date.month, date.day, nlp!.time!.hour, nlp.time!.minute)
        : date;

    final categoryId = categoryBox.isEmpty ? '' : categoryBox.values.first.id;
    final task = Task(
      title: title,
      dueDate: finalDate,
      categoryId: categoryId,
      priority: 1,
      recurrence: 'none',
      notes: '',
    );
    await taskBox.add(task);
    AnalyticsService().logTaskCreated(task);

    if (mounted) {
      final t = AppText.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.quickAddDone}: $title'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Автоматичен фонов синк с Google Calendar — веднъж на 24ч, без await.
  Future<void> _autoSyncCalendar() async {
    if (!await CalendarImportService.shouldAutoSync()) return;
    await CalendarImportService.markSynced();
    if (!mounted) return;
    CalendarImportService.runImport(
      taskBox,
      categoryBox,
      AppText.of(context),
    ).catchError((_) => (0, 0)); // тихо — не показваме грешка при фонов синк
  }

  void _showCategoryFilter() {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(t.all),
                  selected: _categoryFilterId == null,
                  onSelected: (_) {
                    setState(() => _categoryFilterId = null);
                    Navigator.pop(ctx);
                  },
                ),
                ...categoryBox.values.map((c) {
                  final name = localizedCategoryName(c, t);
                  final isSelected = _categoryFilterId == c.id;
                  final catColor = Color(c.colorValue);
                  return FilterChip(
                    label: Text(name),
                    selected: isSelected,
                    selectedColor: catColor.withValues(alpha: 0.2),
                    checkmarkColor: catColor,
                    side: BorderSide(color: isSelected ? catColor : Colors.transparent),
                    onSelected: (_) {
                      setState(() => _categoryFilterId = isSelected ? null : c.id);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                // Споделени списъци — вход от „Категория" (Пакет 3).
                ActionChip(
                  avatar: const Icon(Icons.groups_rounded, size: 18),
                  label: Text(t.sharedTab),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SharedGroupsScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _onTasksChanged() {
    if (mounted) setState(() {});
  }

  String _smartDateStr(BuildContext ctx, DateTime d) {
    final lang = Localizations.localeOf(ctx).languageCode;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(d.year, d.month, d.day);
    final diff = taskDay.difference(today).inDays;
    final timeStr = (d.hour != 0 || d.minute != 0)
        ? ' · ${formatTime(TimeOfDay.fromDateTime(d))}'
        : '';
    if (diff == 0) {
      const m = {'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': 'Auj.', 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün', 'ja': '今日'};
      return '${m[lang] ?? m['en']!}$timeStr';
    }
    if (diff == 1) {
      const m = {'en': 'Tomorrow', 'bg': 'Утре', 'de': 'Morgen', 'fr': 'Demain', 'it': 'Domani', 'el': 'Αύριο', 'es': 'Mañana', 'pt': 'Amanhã', 'ru': 'Завтра', 'tr': 'Yarın', 'ja': '明日'};
      return '${m[lang] ?? m['en']!}$timeStr';
    }
    if (diff > 1 && diff < 7) {
      const wd = <String, List<String>>{
        'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        'bg': ['Пон', 'Вт', 'Ср', 'Чет', 'Пет', 'Съб', 'Нед'],
        'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
        'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
        'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
        'el': ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'],
        'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
        'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
        'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
        'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
      };
      return '${(wd[lang] ?? wd['en']!)[d.weekday - 1]}$timeStr';
    }
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day.$month$timeStr';
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

  static const Map<String, String> _sharedHint = {
    'en': 'Lists with family or your team', 'bg': 'Списъци със семейството или екипа',
    'de': 'Listen mit Familie oder Team', 'fr': 'Listes avec ta famille ou ton équipe',
    'it': 'Liste con famiglia o team', 'el': 'Λίστες με οικογένεια ή ομάδα',
    'es': 'Listas con familia o equipo', 'pt': 'Listas com a família ou equipa',
    'ru': 'Списки с семьёй или командой', 'tr': 'Aile veya ekiple listeler',
    'ja': '家族やチームとのリスト',
  };

  /// Видима „категория"-подобна карта за Споделени списъци в началото на Задачи.
  Widget _buildSharedEntry(AppText t, ThemeData theme) {
    const accent = Color(0xFF378ADD);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Material(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SharedGroupsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: accent, shape: BoxShape.circle),
                  child: const Icon(Icons.groups_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.sharedTab,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(_sharedHint[t.lang] ?? _sharedHint['en']!,
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Просрочена ли е задачата. Задача с конкретен час → просрочена след часа;
  /// задача само с дата (00:00) → просрочена едва след края на деня (23:59:59).
  bool _isTaskOverdue(Task task) {
    if (task.isCompleted) return false;

    final now = DateTime.now();
    final dueDate = task.dueDate;

    // Ако задачата има конкретен час (не е 00:00), използваме стандартната проверка
    if (dueDate.hour != 0 || dueDate.minute != 0) {
      return dueDate.isBefore(now);
    }

    // За задачи само с дата (без час), те са просрочени едва след края на деня
    final endOfDueDay =
        DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59);
    return now.isAfter(endOfDueDay);
  }

  ({List<Task> filtered, int total, int completed, int overdue, int upcoming, int archived}) _computeTasks() {
    // Документите имат собствен таб „Документи" (+ Календар + напомняния) и са с
    // далечни срокове (месеци/години) → НЕ ги показваме и НЕ ги броим в главния
    // списък със задачи, за да не го затрупват.
    final all = taskBox.values.where((t) => t.template != 'document').toList();

    // Stats — single pass over all tasks
    int total = 0, completed = 0, overdue = 0, upcoming = 0, archived = 0;
    for (final t in all) {
      if (t.isArchived) { archived++; continue; }
      total++;
      if (t.isCompleted) completed++;
      else if (_isTaskOverdue(t)) overdue++;
      else upcoming++;
    }

    // Sort
    switch (_sortBy) {
      case TaskSort.date:     all.sort((a, b) => a.dueDate.compareTo(b.dueDate)); break;
      case TaskSort.priority: all.sort((a, b) => b.priority.compareTo(a.priority)); break;
      case TaskSort.name:     all.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())); break;
      case TaskSort.category: all.sort((a, b) => a.categoryId.compareTo(b.categoryId)); break;
    }

    // Filter by status
    List<Task> filtered;
    switch (_filter) {
      case TaskFilter.all:       filtered = all.where((t) => !t.isArchived).toList(); break;
      case TaskFilter.active:    filtered = all.where((t) => !t.isCompleted && !t.isArchived).toList(); break;
      case TaskFilter.completed: filtered = all.where((t) => t.isCompleted && !t.isArchived).toList(); break;
      case TaskFilter.overdue:   filtered = all.where((t) => !t.isArchived && _isTaskOverdue(t)).toList(); break;
      case TaskFilter.upcoming:  filtered = all.where((t) => !t.isCompleted && !t.isArchived && !_isTaskOverdue(t)).toList(); break;
      case TaskFilter.archived:  filtered = all.where((t) => t.isArchived).toList(); break;
    }

    // Filter by category
    if (_categoryFilterId != null && _categoryFilterId!.isNotEmpty) {
      filtered = filtered.where((t) => t.categoryId == _categoryFilterId).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((t) => t.title.toLowerCase().contains(q)).toList();
    }

    return (filtered: filtered, total: total, completed: completed, overdue: overdue, upcoming: upcoming, archived: archived);
  }


  Future<void> _openTaskDialog({Task? existing, Future<void> Function(Task draft)? onSave}) async {
    await TaskEditorSheet.show(
      context,
      existing: existing,
      onSave: onSave,
      taskBox: taskBox,
      categoryBox: categoryBox,
      initialCategoryId: _selectedCategoryId,
      initialPriority: _selectedPriority,
      initialRecurrence: _selectedRecurrence,
      onCategoryDefaultChanged: (v) => _selectedCategoryId = v,
      onPriorityDefaultChanged: (v) => _selectedPriority = v,
      onRecurrenceDefaultChanged: (v) => _selectedRecurrence = v,
      onClearCategoryFilter: () => _categoryFilterId = null,
      onChanged: () { if (mounted) setState(() {}); },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);

    final (:filtered, :total, :completed, :overdue, :upcoming, :archived) = _computeTasks();
    final tasks = filtered;
    final categoriesMap = {
      for (var c in categoryBox.values) c.id: c,
    };

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
        centerTitle: !_isSearching,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                }),
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: t.searchTasks,
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text(t.tasks, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: _isSearching
            ? []
            : [
                // Споделени списъци (обединени от отделния таб във Фаза 1).
                IconButton(
                  icon: const Icon(Icons.groups_outlined),
                  tooltip: t.sharedTab,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SharedGroupsScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.grid_view_rounded),
                  tooltip: t.matrix,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EisenhowerScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.filter_list_rounded),
                      if (_categoryFilterId != null)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: _showCategoryFilter,
                ),
                if (archived > 0)
                  IconButton(
                    icon: Badge(
                      label: Text('$archived'),
                      isLabelVisible: _filter != TaskFilter.archived,
                      child: Icon(
                        Icons.archive_outlined,
                        color: _filter == TaskFilter.archived ? theme.colorScheme.primary : null,
                      ),
                    ),
                    onPressed: () => setState(() {
                      _filter = _filter == TaskFilter.archived ? TaskFilter.all : TaskFilter.archived;
                    }),
                  ),
                PopupMenuButton<TaskSort>(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: t.sortBy,
                  onSelected: (sort) => setState(() => _sortBy = sort),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: TaskSort.date,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: _sortBy == TaskSort.date ? theme.colorScheme.primary : null),
                          const SizedBox(width: 12),
                          Text(t.date, style: TextStyle(fontWeight: _sortBy == TaskSort.date ? FontWeight.bold : null, color: _sortBy == TaskSort.date ? theme.colorScheme.primary : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: TaskSort.priority,
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded, size: 20, color: _sortBy == TaskSort.priority ? theme.colorScheme.primary : null),
                          const SizedBox(width: 12),
                          Text(t.priority, style: TextStyle(fontWeight: _sortBy == TaskSort.priority ? FontWeight.bold : null, color: _sortBy == TaskSort.priority ? theme.colorScheme.primary : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: TaskSort.name,
                      child: Row(
                        children: [
                          Icon(Icons.sort_by_alpha_rounded, size: 20, color: _sortBy == TaskSort.name ? theme.colorScheme.primary : null),
                          const SizedBox(width: 12),
                          Text(t.name, style: TextStyle(fontWeight: _sortBy == TaskSort.name ? FontWeight.bold : null, color: _sortBy == TaskSort.name ? theme.colorScheme.primary : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: TaskSort.category,
                      child: Row(
                        children: [
                          Icon(Icons.folder_rounded, size: 20, color: _sortBy == TaskSort.category ? theme.colorScheme.primary : null),
                          const SizedBox(width: 12),
                          Text(t.category, style: TextStyle(fontWeight: _sortBy == TaskSort.category ? FontWeight.bold : null, color: _sortBy == TaskSort.category ? theme.colorScheme.primary : null)),
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
            // Productivity banner — streak + today's score
            ProductivityBanner(taskBox: taskBox),

            // Режими Уча: обратно броене (Ученик до ваканция/изпит, Студент до
            // ключова дата). Само при включен режим; сама се скрива иначе.
            // Тап → пълен списък с предстоящи събития. Реактивна.
            const StudyCountdownCard(),

            // (Входът към Споделени списъци е в „Категория" избора — Пакет 3.)

            // Статистика - нов дизайн
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: Row(
                children: [
                  taskStatCard(
                    label: t.total,
                    value: total,
                    selected: _filter == TaskFilter.all,
                    onTap: () => setState(() => _filter = TaskFilter.all),
                    color: theme.colorScheme.primary,
                    icon: Icons.list_alt_rounded,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  taskStatCard(
                    label: t.upcoming,
                    value: upcoming,
                    selected: _filter == TaskFilter.upcoming,
                    onTap: () => setState(() => _filter = TaskFilter.upcoming),
                    color: Colors.blue,
                    icon: Icons.upcoming_rounded,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  taskStatCard(
                    label: t.overdue,
                    value: overdue,
                    selected: _filter == TaskFilter.overdue,
                    onTap: () => setState(() => _filter = TaskFilter.overdue),
                    color: Colors.redAccent,
                    icon: Icons.warning_amber_rounded,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  taskStatCard(
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

            // Active category filter chip (само когато е активен)
            if (_categoryFilterId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list_rounded, size: 13, color: theme.colorScheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            localizedCategoryName(categoryBox.get(_categoryFilterId), t),
                            style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () => setState(() => _categoryFilterId = null),
                            child: Icon(Icons.close_rounded, size: 13, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Списък със задачи (групиран по дата)
            Expanded(
              child: ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 8,
                      ),
                      // +1 за обособената секция „Споделени" НАЙ-ОТГОРЕ (собствен
                      // Firestore източник; скрива се сама, ако няма групови задачи).
                      itemCount: items.isEmpty ? 2 : items.length + 1,
                      itemBuilder: (_, index) {
                        if (index == 0) return const SharedTasksSection();
                        if (items.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text(
                                '—',
                                style: TextStyle(
                                    fontSize: 28, color: Colors.black26),
                              ),
                            ),
                          );
                        }
                        final item = items[index - 1];

                        if (item is DateTime) {
                          final label = formatDate(item);
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
                            localizedCategoryName(cat, t);
                        final categoryColor = cat != null 
                            ? Color(cat.colorValue)
                            : Colors.grey;
                        final priorityColor =
                            _priorityColor(task.priority);
                        final priorityText =
                            _priorityLabel(task.priority, t);
                        final dateTimeStr = _smartDateStr(context, task.dueDate);

                        final isOverdue = _isTaskOverdue(task);
                        final isCompleted = task.isCompleted;

                        // Цветът на лентата: червен ако е просрочено, иначе цвета на категорията
                        final accentColor = isOverdue
                            ? Colors.redAccent
                            : (templateAccentColor(task.template)
                                ?? categoryColor);

                        return TaskListTile(
                          task: task,
                          category: cat,
                          index: index,
                          isOverdue: isOverdue,
                          isCompleted: isCompleted,
                          isExpanded: _expandedCards.contains(task.key),
                          taskBox: taskBox,
                          categoryBox: categoryBox,
                          dateTimeStr: dateTimeStr,
                          priorityText: priorityText,
                          priorityColor: priorityColor,
                          accentColor: accentColor,
                          categoryName: categoryName,
                          recurrenceText: task.recurrence != null ? _recurrenceLabel(task.recurrence, t) : null,
                          onChanged: () => setState(() {}),
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
                          onOpenFullEditor: () => _openTaskDialog(existing: task),
                          onCelebrate: () => _checkAndCelebrate(taskDate: task.dueDate),
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
                if (type == 'document') { DocumentDialog.show(context).then((_) => setState(() {})); return; }
                if (type == 'homework' || type == 'essay' || type == 'coursework') {
                  StudyTaskDialog.show(context, kind: type).then((_) => setState(() {})); return;
                }
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

