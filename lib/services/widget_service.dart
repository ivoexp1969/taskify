import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class WidgetService {
  static const _channel = MethodChannel('com.ivoexp.taskify/widget');

  static Future<void> updateWidget() async {
    if (kIsWeb) return;
    try {
      await _syncTasksToPrefs();
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }

  static Future<void> _syncTasksToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final taskBox = Hive.box<Task>('tasks');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final todayTasks = taskBox.values.where((t) {
        if (t.isCompleted) return false;
        final taskDate = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
        return taskDate.isBefore(tomorrow);
      }).toList();

      todayTasks.sort((a, b) {
        final aOverdue = a.dueDate.isBefore(now);
        final bOverdue = b.dueDate.isBefore(now);
        if (aOverdue && !bOverdue) return -1;
        if (!aOverdue && bOverdue) return 1;
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.dueDate.compareTo(b.dueDate);
      });

      final tasksJson = todayTasks.map((t) => {
        'key': t.key,
        'title': t.title,
        'isCompleted': t.isCompleted,
        'priority': t.priority,
        'dueDate': t.dueDate.toIso8601String(),
      }).toList();

      await prefs.setString('widget_tasks', jsonEncode(tasksJson));
    } catch (e) {
      debugPrint('Sync tasks error: $e');
    }
  }

  static Future<void> requestPinWidget() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('requestPinWidget');
    } catch (e) {
      debugPrint('Request pin widget error: $e');
    }
  }

  static void setupWidgetListener() {
    if (kIsWeb) return;
    final taskBox = Hive.box<Task>('tasks');
    taskBox.watch().listen((_) {
      updateWidget();
    });
  }

  static Future<void> syncFromWidget() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('widget_tasks');
      if (tasksJson == null) return;

      final taskBox = Hive.box<Task>('tasks');
      final List<dynamic> tasks = jsonDecode(tasksJson);

      for (final taskData in tasks) {
        final key = taskData['key'];
        final isCompleted = taskData['isCompleted'] ?? false;
        if (key != null && taskBox.containsKey(key)) {
          final task = taskBox.get(key);
          if (task != null && task.isCompleted != isCompleted) {
            task.isCompleted = isCompleted;
            if (isCompleted) task.completedAt = DateTime.now();
            await task.save();
          }
        }
      }
    } catch (e) {
      debugPrint('Sync from widget error: $e');
    }
  }
}
