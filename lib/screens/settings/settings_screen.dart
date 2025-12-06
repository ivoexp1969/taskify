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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _isSyncing = false;

  Future<void> _exportData(BuildContext context) async {
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';

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
        subject: 'Task Manager Backup',
        text: isBg ? 'Backup на задачите' : 'Tasks backup',
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBg ? 'Грешка при експорт: $e' : 'Export error: $e',
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
    final isBg = languageController.locale.languageCode == 'bg';

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
            title: Text(isBg ? 'Потвърждение' : 'Confirm'),
            content: Text(
              isBg
                  ? 'Ще бъдат импортирани $tasksCount задачи и $categoriesCount категории.\n\nТова ще замени всички текущи данни. Продължи?'
                  : 'Will import $tasksCount tasks and $categoriesCount categories.\n\nThis will replace all current data. Continue?',
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
                child: Text(isBg ? 'Замени' : 'Replace'),
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
            content: Text(
              isBg
                  ? 'Импортирани ${tasks.length} задачи и ${categories.length} категории'
                  : 'Imported ${tasks.length} tasks and ${categories.length} categories',
            ),
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
              isBg ? 'Грешка при импорт: $e' : 'Import error: $e',
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
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBg ? 'Изход' : 'Logout'),
        content: Text(
          isBg ? 'Сигурен ли си, че искаш да излезеш?' : 'Are you sure you want to logout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isBg ? 'Отказ' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(isBg ? 'Изход' : 'Logout'),
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
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';

    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBg ? 'Качване в облака' : 'Upload to Cloud'),
        content: Text(
          isBg
              ? 'Ще бъдат качени ${taskBox.length} задачи и ${categoryBox.length} категории.\n\nТова ще замени данните в облака. Продължи?'
              : 'Will upload ${taskBox.length} tasks and ${categoryBox.length} categories.\n\nThis will replace cloud data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isBg ? 'Отказ' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBg ? 'Качи' : 'Upload'),
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
                ? (isBg
                    ? 'Качени ${result.tasksCount} задачи и ${result.categoriesCount} категории'
                    : 'Uploaded ${result.tasksCount} tasks and ${result.categoriesCount} categories')
                : (isBg ? 'Грешка: ${result.error}' : 'Error: ${result.error}'),
          ),
          backgroundColor: result.success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _downloadFromCloud() async {
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';

    final cloudData = await _firestoreService.getCloudDataCount();

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBg ? 'Сваляне от облака' : 'Download from Cloud'),
        content: Text(
          isBg
              ? 'В облака има ${cloudData.tasks} задачи и ${cloudData.categories} категории.\n\nТова ще замени локалните данни. Продължи?'
              : 'Cloud has ${cloudData.tasks} tasks and ${cloudData.categories} categories.\n\nThis will replace local data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isBg ? 'Отказ' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text(isBg ? 'Свали' : 'Download'),
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
                ? (isBg
                    ? 'Свалени ${result.tasksCount} задачи и ${result.categoriesCount} категории'
                    : 'Downloaded ${result.tasksCount} tasks and ${result.categoriesCount} categories')
                : (isBg ? 'Грешка: ${result.error}' : 'Error: ${result.error}'),
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
    final isBg = languageController.locale.languageCode == 'bg';

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
          // Статистики секция
          Text(
            isBg ? 'Активност' : 'Activity',
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
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.purple,
                ),
              ),
              title: Text(isBg ? 'Статистики' : 'Statistics'),
              subtitle: Text(
                isBg
                    ? 'Преглед на твоя прогрес'
                    : 'View your progress',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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

          // Акаунт секция
          Text(
            isBg ? 'Акаунт' : 'Account',
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
                      isBg ? 'Влязъл си в акаунта' : 'Signed in',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _logout,
                      child: Text(
                        isBg ? 'Изход' : 'Logout',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(isBg ? 'Вход / Регистрация' : 'Login / Register'),
                    subtitle: Text(
                      isBg
                          ? 'Влез за синхронизация в облака'
                          : 'Sign in to sync to cloud',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
              isBg ? 'Синхронизация' : 'Sync',
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
                        color: Colors.blue.withOpacity(0.1),
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
                    title: Text(isBg ? 'Качи в облака' : 'Upload to Cloud'),
                    subtitle: Text(
                      isBg
                          ? 'Запази задачите в облака'
                          : 'Save tasks to cloud',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                        color: Colors.orange.withOpacity(0.1),
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
                    title: Text(isBg ? 'Свали от облака' : 'Download from Cloud'),
                    subtitle: Text(
                      isBg
                          ? 'Възстанови задачите от облака'
                          : 'Restore tasks from cloud',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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

          // Език
          Text(
            t.language,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'bg',
                  groupValue: currentLocale.languageCode,
                  title: Text(t.bulgarian),
                  onChanged: (value) {
                    if (value == null) return;
                    languageController.setLocale(const Locale('bg'));
                  },
                ),
                const Divider(height: 0),
                RadioListTile<String>(
                  value: 'en',
                  groupValue: currentLocale.languageCode,
                  title: Text(t.english),
                  onChanged: (value) {
                    if (value == null) return;
                    languageController.setLocale(const Locale('en'));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: currentMode,
                  title: Text(t.systemTheme),
                  onChanged: (mode) {
                    if (mode == null) return;
                    themeController.setMode(mode);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: currentMode,
                  title: Text(t.lightTheme),
                  onChanged: (mode) {
                    if (mode == null) return;
                    themeController.setMode(mode);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: currentMode,
                  title: Text(t.darkTheme),
                  onChanged: (mode) {
                    if (mode == null) return;
                    themeController.setMode(mode);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Backup / Restore
          Text(
            isBg ? 'Локални данни' : 'Local Data',
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
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.upload_rounded,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(isBg ? 'Експорт (JSON)' : 'Export (JSON)'),
                  subtitle: Text(
                    isBg
                        ? 'Сподели backup файл'
                        : 'Share backup file',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(isBg ? 'Импорт (JSON)' : 'Import (JSON)'),
                  subtitle: Text(
                    isBg
                        ? 'Възстанови от JSON файл'
                        : 'Restore from JSON file',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}