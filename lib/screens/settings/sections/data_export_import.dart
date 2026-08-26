import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../../models/task.dart';
import '../../../models/category.dart';
import '../../../utils/localization.dart';
import '../../../utils/file_saver.dart';

/// Експорт/импорт на данни (JSON backup). Изнесено от `settings_screen.dart`
/// без промяна на поведение.

Future<void> exportData(BuildContext context) async {
  final t = AppText.of(context);

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
        // ВАЖНО: пази връзката към Google Calendar, иначе при възстановяване
        // авто-импортът ще ги мисли за нови → масови дубли.
        'googleCalendarEventId': t.googleCalendarEventId,
        'importedFromCalendar': t.importedFromCalendar,
        'template': t.template,
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    // Web: dart:io File / getTemporaryDirectory не съществуват → сваляме
    // файла директно през браузъра (Blob download).
    if (kIsWeb) {
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      await saveTextFile('task_manager_backup_$ts.json', jsonString);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.tasksBackup)),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'task_manager_backup_$timestamp.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonString);

    // iOS popover anchor: share_plus иска non-zero sharePositionOrigin,
    // иначе хвърля PlatformException на iPad/iOS. На Android се игнорира.
    final box = context.findRenderObject() as RenderBox?;
    final size = MediaQuery.of(context).size;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 1,
            height: 1,
          );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: t.backupSubject,
      text: t.tasksBackup,
      sharePositionOrigin: origin,
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

Future<void> importData(BuildContext context) async {
  final t = AppText.of(context);

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
        googleCalendarEventId: taskData['googleCalendarEventId'] as String?,
        importedFromCalendar: taskData['importedFromCalendar'] as bool?,
        template: taskData['template'] as String?,
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
