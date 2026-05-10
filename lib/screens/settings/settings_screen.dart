import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import 'statistics_screen.dart';
import '../../services/task_view_preference.dart';
import '../home/home_screen.dart';
import '../../services/google_calendar_service.dart';
import '../../services/morning_briefing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _viewPreference = TaskViewPreference();
  bool _isSyncing = false;
  bool _isCalendarConnected = false;
  final _calendarService = GoogleCalendarService();
  final _morningBriefingService = MorningBriefingService();
  bool _isMorningBriefingEnabled = false;
  int _briefingHour = 8;
  int _briefingMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadBriefingTime();
    _loadMorningBriefingSetting();
    _checkCalendarConnection();
  }

  Future<void> _loadMorningBriefingSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMorningBriefingEnabled = prefs.getBool('morning_briefing_enabled') ?? false;
    });
  }

  Future<void> _saveMorningBriefingSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_briefing_enabled', value);
  }

  Future<void> _checkCalendarConnection() async {
    final isConnected = _calendarService.isConnected;
    setState(() {
      _isCalendarConnected = isConnected;
    });
  }

  // Списък с предефинирани цветове за color picker
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

  /// Показва диалог за управление на категориите
  void _showCategoryManagementDialog() {
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final categoryBox = Hive.box<Category>('categories');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final categories = categoryBox.values.toList();

            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
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
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          t.categories,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(innerContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Category list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final catColor = Color(cat.colorValue);
                        final localizedName = cat.isDefault
                            ? {
                                'work': t.catWork,
                                'personal': t.catPersonal,
                                'shopping': t.catShopping,
                                'birthday': t.catBirthdays,
                                'meeting': t.catMeeting,
                                'workout': t.catWorkout,
                                'payment': t.catPayment,
                                'travel': t.catTravel,
                                'gift': t.catGift,
                              }[cat.id] ?? cat.name
                            : cat.name;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder_rounded,
                                color: catColor,
                              ),
                            ),
                            title: Text(
                              localizedName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: cat.isDefault
                                ? Text(
                                    t.defaultCategory,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    _showEditCategoryDialog(
                                      cat,
                                      t,
                                      theme,
                                      () {
                                        setSheetState(() {});
                                        setState(() {});
                                      },
                                    );
                                  },
                                ),
                                // Delete button (само за не-default)
                                if (!cat.isDefault)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: innerContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(t.deletion),
                                          content: Text(t.deleteCategoryMessage(cat.name)),
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
                                      if (confirm == true) {
                                        await categoryBox.delete(cat.id);
                                        setSheetState(() {});
                                        setState(() {});
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add category button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddCategoryDialog(t, theme, () {
                            setSheetState(() {});
                            setState(() {});
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(t.addCategory),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

  /// Показва диалог за добавяне на нова категория
  void _showAddCategoryDialog( AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController();
    Color selectedColor = Colors.blue;
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
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
                              setDialogState(() {
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
                      Navigator.pop(ctx);
                      onComplete();
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

  /// Показва диалог за редактиране на категория
  void _showEditCategoryDialog(Category cat, AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController(text: cat.name);
    Color selectedColor = Color(cat.colorValue);
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(t.editCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        enabled: !cat.isDefault, // Default категориите не могат да се преименуват
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: cat.isDefault
                              ? (t.defaultCategoryNameCannotChange)
                              : null,
                          helperMaxLines: 2,
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
                              setDialogState(() {
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
                      // За default категории, запазваме оригиналното име
                      final updatedCat = Category(
                        id: cat.id,
                        name: cat.isDefault ? cat.name : name,
                        colorValue: selectedColor.value,
                        isDefault: cat.isDefault,
                      );
                      categoryBox.put(cat.id, updatedCat);
                      Navigator.pop(ctx);
                      onComplete();
                    }
                  },
                  child: Text(t.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Показва диалог за избор на език
  void _showLanguageDialog(BuildContext context, LanguageController languageController, Locale currentLocale) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
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
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      AppText.of(context).language,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Списък с езици - SCROLLABLE
              Expanded(
                child: ListView.builder(
                  itemCount: SupportedLocales.all.length,
                  itemBuilder: (context, index) {
                    final locale = SupportedLocales.all[index];
                    final isSelected = currentLocale.languageCode == locale.languageCode;
                    return ListTile(
                      leading: Text(
                        SupportedLocales.flags[locale.languageCode] ?? '🌐',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        SupportedLocales.names[locale.languageCode] ?? locale.languageCode,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        languageController.setLocale(locale);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Load saved briefing time
  Future<void> _loadBriefingTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _briefingHour = prefs.getInt('briefing_hour') ?? 8;
      _briefingMinute = prefs.getInt('briefing_minute') ?? 0;
    });
  }

  // Format time for display
  String _formatTime(int hour, int minute) {
    final hourStr = hour.toString().padLeft(2, '0');
    
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  // Select briefing time
  Future<void> _selectBriefingTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _briefingHour, minute: _briefingMinute),
    );
    
    if (picked != null) {
      setState(() {
        _briefingHour = picked.hour;
        _briefingMinute = picked.minute;
      });
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('briefing_hour', _briefingHour);
      await prefs.setInt('briefing_minute', _briefingMinute);
      
      // Reschedule briefing
      await _morningBriefingService.scheduleDailyBriefing(
        hour: _briefingHour,
        minute: _briefingMinute,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppText.of(context).briefingTimeSetTo(_formatTime(_briefingHour, _briefingMinute))),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final t = AppText.of(context);
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;

    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      final data = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'categories': categoryBox.values.map((c) => {
          'id': c.id,
          'name': c.name,
          'colorValue': c.colorValue,
          'isDefault': c.isDefault,
        }).toList(),
        'tasks': taskBox.values.map((t) => {
          'title': t.title,
          'dueDate': t.dueDate.toIso8601String(),
          'categoryId': t.categoryId,
          'priority': t.priority,
          'isCompleted': t.isCompleted,
          'recurrence': t.recurrence,
          'reminder': t.reminder,
          'subtasks': t.subtasks,
          'notes': t.notes,
          'completedAt': t.completedAt?.toIso8601String(),
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'task_manager_backup_$timestamp.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: t.backupSubject,
        text: t.tasksBackup,
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.exportError}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final t = AppText.of(context);
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      if (context.mounted) {
        final tasksCount = (data['tasks'] as List).length;
        final categoriesCount = (data['categories'] as List).length;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.confirmation),
            content: Text(t.importConfirmMessage(tasksCount, categoriesCount)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: Text(t.replace),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      await taskBox.clear();
      await categoryBox.clear();

      final categories = data['categories'] as List<dynamic>;
      for (final c in categories) {
        final category = Category(
          id: c['id'] as String,
          name: c['name'] as String,
          colorValue: c['colorValue'] as int,
          isDefault: c['isDefault'] as bool? ?? false,
        );
        await categoryBox.put(category.id, category);
      }

      final tasks = data['tasks'] as List<dynamic>;
      for (final taskData in tasks) {
        final task = Task(
          title: taskData['title'] as String,
          dueDate: DateTime.parse(taskData['dueDate'] as String),
          categoryId: taskData['categoryId'] as String,
          priority: taskData['priority'] as int? ?? 1,
          recurrence: taskData['recurrence'] as String?,
          reminder: taskData['reminder'] as String?,
          subtasks: (taskData['subtasks'] as List<dynamic>?)?.cast<String>(),
          notes: taskData['notes'] as String?,
          completedAt: taskData['completedAt'] != null
              ? DateTime.parse(taskData['completedAt'] as String)
              : null,
        );
        task.isCompleted = taskData['isCompleted'] as bool? ?? false;
        await taskBox.add(task);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.importSuccessMessage(tasks.length, categories.length)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.importError}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    final t = AppText.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logout),
        content: Text(
          t.logoutConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(t.logout),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _uploadToCloud() async {
    final t = AppText.of(context);

    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.uploadToCloud),
        content: Text(t.uploadConfirmMessage(taskBox.length, categoryBox.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.upload),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);

    final result = await _firestoreService.uploadToCloud();

    if (mounted) {
      setState(() => _isSyncing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? t.uploadSuccessMessage(result.tasksCount, result.categoriesCount)
                : '${t.error}: ${result.error}',
          ),
          backgroundColor: result.success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _downloadFromCloud() async {
    final t = AppText.of(context);
    final cloudData = await _firestoreService.getCloudDataCount();

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.downloadFromCloud),
        content: Text(t.downloadConfirmMessage(cloudData.tasks, cloudData.categories)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text(t.download),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);

    final result = await _firestoreService.downloadFromCloud();

    if (mounted) {
      setState(() => _isSyncing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? t.downloadSuccessMessage(result.tasksCount, result.categoriesCount)
                : '${t.error}: ${result.error}',
          ),
          backgroundColor: result.success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final languageController = LanguageScope.of(context);
    final themeController = ThemeScope.of(context);
    final langCode = languageController.locale.languageCode;

    final currentLocale = languageController.locale;
    final currentMode = themeController.mode;
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Език - НАЙ-ОТГОРЕ
          Text(
            t.language,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  SupportedLocales.flags[currentLocale.languageCode] ?? '🌐',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Text(SupportedLocales.names[currentLocale.languageCode] ?? 'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context, languageController, currentLocale),
            ),
          ),

          const SizedBox(height: 24),

          // Статистики секция
          Text(
            t.activity,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.purple,
                ),
              ),
              title: Text(t.statistics),
              subtitle: Text(
                t.viewProgress,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Категории секция
          Text(
            t.categories,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Colors.teal,
                ),
              ),
              title: Text(t.manageCategories),
              subtitle: Text(
                t.editAddDeleteCategories,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showCategoryManagementDialog,
            ),
          ),

          const SizedBox(height: 24),

          // Акаунт секция
          Text(
            t.account,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: user != null
                ? ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        user.email?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(user.email ?? ''),
                    subtitle: Text(
                      t.signedIn,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _logout,
                      child: Text(
                        t.logout,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(t.login),
                    subtitle: Text(
                      t.signInToSync,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openLogin,
                  ),
          ),

          // Синхронизация (само ако е логнат)
          if (user != null) ...[
            const SizedBox(height: 24),
            Text(
              t.cloudSync,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.cloud_upload_outlined,
                              color: Colors.blue,
                            ),
                    ),
                    title: Text(t.uploadToCloud),
                    subtitle: Text(
                      t.saveToCloud,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSyncing ? null : _uploadToCloud,
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.cloud_download_outlined,
                              color: Colors.orange,
                            ),
                    ),
                    title: Text(t.downloadFromCloud),
                    subtitle: Text(
                      t.restoreFromCloud,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSyncing ? null : _downloadFromCloud,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Google Calendar
          // Google Calendar
          Text(
            t.googleCalendar,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isCalendarConnected ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isCalendarConnected ? Icons.event_available : Icons.event_busy,
                      color: _isCalendarConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(_isCalendarConnected ? t.calendarConnected : t.calendarNotConnected),
                  subtitle: Text(
                    _isCalendarConnected ? t.calendarSyncEnabled : t.connectForSync,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: Platform.isIOS && !_isCalendarConnected
                      ? null
                      : TextButton(
                    onPressed: () async {
                      if (_isCalendarConnected) {
                        await _calendarService.disconnect();
                        setState(() => _isCalendarConnected = false);
                      } else {
                        final success = await _calendarService.connect();
                        setState(() => _isCalendarConnected = success);
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.connectionFailed)),
                          );
                        }
                      }
                    },
                    child: Text(_isCalendarConnected ? t.disconnect : t.connect),
                  ),
                ),
                if (_isCalendarConnected) ...[
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sync, color: Colors.blue),
                    ),
                    title: Text(t.syncNow),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final taskBox = Hive.box<Task>('tasks');
                      int synced = 0;
                      for (final task in taskBox.values) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        if (!task.isCompleted && !task.isArchived && task.dueDate.isAfter(today.subtract(const Duration(days: 1)))) {
                          // Ресетваме старото ID ако има
                          if (task.googleCalendarEventId != null) {
                            await _calendarService.deleteCalendarEvent(task.googleCalendarEventId!);
                            task.googleCalendarEventId = null;
                          }
                          final eventId = await _calendarService.addTaskToCalendar(task);
                          if (eventId != null) {
                            task.googleCalendarEventId = eventId;
                            await task.save();
                            synced++;
                          }
                        }
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.tasksSynced(synced))),
                        );
                                            }
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cloud_download, color: Colors.orange),
                    ),
                    title: Text(t.syncFromCalendar),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final taskBox = Hive.box<Task>('tasks');
                      int updated = 0;
                      for (final task in taskBox.values) {
                        if (task.googleCalendarEventId != null) {
                          final event = await _calendarService.getCalendarEvent(task.googleCalendarEventId!);
                          if (event != null) {
                            if (event['deleted'] == true) {
                              // Събитието е изтрито - питаме потребителя
                              // Засега само маркираме
                              task.googleCalendarEventId = null;
                              await task.save();
                              updated++;
                            } else {
                              // Обновяваме задачата ако има промени
                              bool changed = false;
                              if (event['summary'] != null && event['summary'] != task.title) {
                                task.title = event['summary'];
                                changed = true;
                              }
                              if (event['description'] != null && event['description'] != (task.notes ?? '')) {
                                task.notes = event['description'].isEmpty ? null : event['description'];
                                changed = true;
                              }
                              if (event['startDateTime'] != null) {
                                try {
                                  final newDate = DateTime.parse(event['startDateTime']);
                                  if (newDate != task.dueDate) {
                                    task.dueDate = newDate;
                                    changed = true;
                                  }
                                } catch (_) {}
                              }
                              if (changed) {
                                await task.save();
                                updated++;
                              }
                            }
                          }
                        }
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.tasksUpdated(updated))),
                        );
                      }
                                        },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.download, color: Colors.purple),
                    ),
                    title: Text(t.importFromCalendar),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final taskBox = Hive.box<Task>('tasks');
                      final categoryBox = Hive.box<Category>('categories');
                      
                      // Helper функция за getOrCreate категория
                      Future<String> getOrCreateCat(String id, String name, int color) async {
                        var cat = categoryBox.get(id);
                        if (cat == null) {
                          cat = Category(id: id, name: name, colorValue: color);
                          await categoryBox.put(id, cat);
                        }
                        return cat.id;
                      }
                      
                      // Категория ID константи
                      const catIdCalendar = 'cal_events';
                      const catIdBirthdays = 'cal_birthdays';
                      const catIdOoo = 'cal_ooo';
                      const catIdFocus = 'cal_focus';
                      const catIdLocation = 'cal_location';
                      const catIdGoogleTasks = 'google_tasks'; // НОВО!
                      
                      // Вземаме съществуващите IDs (за duplicate check)
                      final existingIds = taskBox.values
                          .where((t) => t.googleCalendarEventId != null)
                          .map((t) => t.googleCalendarEventId!)
                          .toSet();
                      
                      // Title+Date set за duplicate detection
                      final existingTitleDates = <String>{};
                      for (final task in taskBox.values.where((t) => t.googleCalendarEventId != null)) {
                        if (task.dueDate != null) {
                          final dateKey = '${task.title}_${task.dueDate!.year}-${task.dueDate!.month}-${task.dueDate!.day}';
                          existingTitleDates.add(dateKey);
                        }
                      }
                      
                      int imported = 0;
                      int skipped = 0;
                      
                      print('=== IMPORT DEBUG ===');
                      
                      // === 1. IMPORT CALENDAR EVENTS ===
                      final events = await _calendarService.getUpcomingEvents(days: 60);
                      print('Total events: ${events.length}');
                      print('Existing IDs count: ${existingIds.length}');
                      
                      // Debug първите 10 birthdays
                      final birthdays = events.where((e) => e['eventType'] == 'birthday').take(10);
                      for (final bd in birthdays) {
                        print('---');
                        print('RAW ID: ${bd['id']}');
                        print('Summary: ${bd['summary']}');
                        print('Type: ${bd['eventType']}');
                      }
                      print('=== END DEBUG ===');
                      
                      // 30-day threshold
                      final now = DateTime.now();
                      final thresholdDate = now.subtract(const Duration(days: 30));
                      
                      for (final event in events) {
                        final eventId = event['id'] as String?;
                        if (eventId == null) continue;
                        
                        // ID strip logic (за recurring events)
                        String baseId = eventId;
                        if (eventId.contains('_')) {
                          baseId = eventId.split('_').first;
                        }
                        
                        // Check existing ID
                        final idExists = existingIds.any((id) => 
                          id == eventId || id == baseId || id.split('_').first == baseId
                        );
                        
                        if (idExists) {
                          print('SKIP duplicate: ${event['summary']} - ID: $eventId');
                          skipped++;
                          continue;
                        }
                        
                        // Debug non-birthday events
                        final eventType = event['eventType'] as String? ?? 'default';
                        if (eventType != 'birthday') {
                          print('Non-birthday: ${event['summary']} - Type: $eventType - Date: ${event['startDateTime']}');
                        }
                        
                        // Parse date
                        DateTime dueDate;
                        try {
                          final startDateTime = event['startDateTime'] as String?;
                          if (startDateTime == null) {
                            print('SKIP no date: ${event['summary']}');
                            skipped++;
                            continue;
                          }
                          
                          dueDate = DateTime.parse(startDateTime).toLocal();
                          
                          // Apply threshold
                          if (dueDate.isBefore(thresholdDate)) {
                            print('SKIP old event: ${event['summary']} - Date: $dueDate');
                            skipped++;
                            continue;
                          }
                        } catch (e) {
                          print('SKIP parse error: ${event['summary']} - Error: $e');
                          skipped++;
                          continue;
                        }
                        
                        // Title+Date duplicate check
                        final dateKey = '${event['summary']}_${dueDate.year}-${dueDate.month}-${dueDate.day}';
                        if (existingTitleDates.contains(dateKey)) {
                          print('SKIP duplicate title+date: ${event['summary']} - Date: ${dueDate.year}-${dueDate.month}-${dueDate.day}');
                          skipped++;
                          continue;
                        }
                        existingTitleDates.add(dateKey);
                        
                        // Category assignment
                        String categoryId;
                        switch (eventType) {
                          case 'birthday':
                            categoryId = await getOrCreateCat(catIdBirthdays, t.catBirthdays, 0xFFE91E63);
                            break;
                          case 'outOfOffice':
                            categoryId = await getOrCreateCat(catIdOoo, t.catOutOfOffice, 0xFFFF9800);
                            break;
                          case 'focusTime':
                            categoryId = await getOrCreateCat(catIdFocus, t.catFocusTime, 0xFF9C27B0);
                            break;
                          case 'workingLocation':
                            categoryId = await getOrCreateCat(catIdLocation, t.catWorkLocation, 0xFF4CAF50);
                            break;
                          default:
                            categoryId = await getOrCreateCat(catIdCalendar, t.catCalendarEvents, 0xFF2196F3);
                        }
                        
                        final newTask = Task(
                          title: event['summary'] ?? t.untitledEvent,
                          dueDate: dueDate,
                          categoryId: categoryId,
                          priority: eventType == 'birthday' ? 2 : 1,
                          notes: event['description'],
                          googleCalendarEventId: eventId,
                        );
                        await taskBox.add(newTask);
                        imported++;
                      }
                      
                      // === 2. IMPORT GOOGLE TASKS ===
                      print('=== IMPORTING GOOGLE TASKS ===');
                      final googleTasks = await _calendarService.getAllGoogleTasks();
                      print('Total Google Tasks: ${googleTasks.length}');
                      
                      for (final gTask in googleTasks) {
                        final taskId = gTask['id'] as String?;
                        if (taskId == null) continue;
                        
                        // Prefix с gtask_ за да отличаваме от calendar events
                        final prefixedId = 'gtask_$taskId';
                        
                        // Check existing
                        if (existingIds.contains(prefixedId)) {
                          print('SKIP duplicate Google Task: ${gTask['title']}');
                          skipped++;
                          continue;
                        }
                        
                        // Status check - skip completed
                        final status = gTask['status'] as String?;
                        if (status == 'completed') {
                          print('SKIP completed task: ${gTask['title']}');
                          skipped++;
                          continue;
                        }
                        
                        // Due date check - skip if no due date
                        final dueStr = gTask['due'] as String?;
                        if (dueStr == null) {
                          print('SKIP task without due date: ${gTask['title']}');
                          skipped++;
                          continue;
                        }
                        
                        // Parse due date
                        DateTime dueDate;
                        try {
                          dueDate = DateTime.parse(dueStr).toLocal();
                          
                          // Apply threshold
                          if (dueDate.isBefore(thresholdDate)) {
                            print('SKIP old Google Task: ${gTask['title']} - Date: $dueDate');
                            skipped++;
                            continue;
                          }
                        } catch (e) {
                          print('SKIP Google Task parse error: ${gTask['title']} - Error: $e');
                          skipped++;
                          continue;
                        }
                        
                        // Title+Date duplicate check
                        final dateKey = '${gTask['title']}_${dueDate.year}-${dueDate.month}-${dueDate.day}';
                        if (existingTitleDates.contains(dateKey)) {
                          print('SKIP duplicate Google Task title+date: ${gTask['title']}');
                          skipped++;
                          continue;
                        }
                        existingTitleDates.add(dateKey);
                        
                        // Create task
                        final categoryId = await getOrCreateCat(
                          catIdGoogleTasks, 
                          t.googleTasks, 
                          0xFF4CAF50, // Green color
                        );
                        
                        final newTask = Task(
                          title: gTask['title'] ?? t.untitledTask,
                          dueDate: dueDate,
                          categoryId: categoryId,
                          priority: 1,
                          notes: gTask['notes'],
                          googleCalendarEventId: prefixedId,
                        );
                        await taskBox.add(newTask);
                        imported++;
                        print('IMPORTED Google Task: ${gTask['title']}');
                      }
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.importedSkipped(imported, skipped))),
                        );
                      }
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_forever, color: Colors.red),
                    ),
                    title: Text(t.deleteAllCalendarTasks),
                    subtitle: Text(t.removeAllImported, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // Confirm dialog
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('${t.deleteAllCalendarTasks}?'),
                          content: Text(t.deleteCalendarTasksConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(t.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(t.delete, style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        final taskBox = Hive.box<Task>('tasks');
                        final tasksToDelete = taskBox.values
                            .where((t) => t.googleCalendarEventId != null)
                            .toList();
                        
                        for (final task in tasksToDelete) {
                          await task.delete();
                        }
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.deletedCalendarTasks(tasksToDelete.length)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          // Тема
          Text(
            t.theme,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<int>(
                  value: 0,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.systemTheme),
                  onChanged: (value) {
                    themeController.setMode(ThemeMode.system);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<int>(
                  value: 1,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.lightTheme),
                  onChanged: (value) {
                    themeController.setMode(ThemeMode.light);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<int>(
                  value: 2,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.darkTheme),
                  onChanged: (value) {
                    themeController.setMode(ThemeMode.dark);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<int>(
                  value: 3,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.amoledTheme),
                  subtitle: Text(
                    'OLED',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onChanged: (value) {
                    themeController.setAmoled(true);
                  },
                ),
              ],
            ),
          ),

          

          const SizedBox(height: 24),


          // Morning Briefing
          Text(
            t.morningBriefing,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: Colors.orange),
              ),
              title: Text(t.morningBriefing),
              subtitle: Text(t.dailyTaskSummaryAt(_formatTime(_briefingHour, _briefingMinute))),
              value: _isMorningBriefingEnabled,
              onChanged: (value) async {
                setState(() => _isMorningBriefingEnabled = value);
                await _saveMorningBriefingSetting(value);
                if (value) {
                  await _morningBriefingService.scheduleDailyBriefing(
                    hour: _briefingHour,
                    minute: _briefingMinute,
                  );
                } else {
                  await _morningBriefingService.cancelDailyBriefing();
                }
              },
            ),
          ),
          // Time Picker (only show if briefing enabled)
          if (_isMorningBriefingEnabled) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.blue),
                ),
                title: Text(t.briefingTime),
                subtitle: Text(_formatTime(_briefingHour, _briefingMinute)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectBriefingTime,
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Backup / Restore
          Text(
            t.localData,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.upload_rounded,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(t.exportData),
                  subtitle: Text(
                    t.shareBackup,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(context),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(t.importData),
                  subtitle: Text(
                    t.restoreFromJson,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importData(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // App info
          Center(
            child: Text(
              'Taskify v1.0',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



