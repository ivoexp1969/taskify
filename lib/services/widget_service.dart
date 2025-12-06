import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class WidgetService {
  static const platform = MethodChannel('com.example.task_manager/widget');

  /// Синхронизира задачите за днес към widget-а
  static Future<void> updateWidget() async {
    try {
      final taskBox = Hive.box<Task>('tasks');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Филтрираме задачите за днес
      final todayTasks = taskBox.values.where((task) {
        final taskDate = DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
        );
        return !task.isCompleted &&
            !taskDate.isBefore(today) &&
            taskDate.isBefore(tomorrow);
      }).toList();

      // Сортираме по приоритет (високият първи)
      todayTasks.sort((a, b) => b.priority.compareTo(a.priority));

      // Конвертираме в JSON
      final tasksJson = todayTasks.map((task) => {
        'key': task.key,
        'title': task.title,
        'priority': task.priority,
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate.toIso8601String(),
      }).toList();

      // Записваме в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_tasks', jsonEncode(tasksJson));

      // Извикваме native метод за обновяване на widget-а
      try {
        await platform.invokeMethod('updateWidget');
      } catch (e) {
        // Widget методът може да не е наличен
      }
    } catch (e) {
      print('WidgetService error: $e');
    }
  }

  /// Синхронизира промените от widget-а обратно към Hive
  static Future<void> syncFromWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('widget_tasks');
      if (tasksJson == null) return;

      final taskBox = Hive.box<Task>('tasks');
      final List<dynamic> tasks = jsonDecode(tasksJson);

      for (final taskData in tasks) {
        if (taskData['completedFromWidget'] == true) {
          final taskKey = taskData['key'] as int?;
          if (taskKey != null) {
            final task = taskBox.get(taskKey);
            if (task != null && !task.isCompleted) {
              task.isCompleted = true;
              await task.save();
            }
          }
        }
      }

      // Обновяваме widget-а след синхронизация
      await updateWidget();
    } catch (e) {
      print('WidgetService syncFromWidget error: $e');
    }
  }

  /// Маркира задача като завършена (извиква се от widget)
  static Future<void> completeTask(int taskKey) async {
    try {
      final taskBox = Hive.box<Task>('tasks');
      final task = taskBox.get(taskKey);
      if (task != null && !task.isCompleted) {
        task.isCompleted = true;
        await task.save();
        await updateWidget();
      }
    } catch (e) {
      print('WidgetService completeTask error: $e');
    }
  }

  /// Слуша за промени от widget-а
  static void setupWidgetListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'taskCompleted') {
        final taskKey = call.arguments as int?;
        if (taskKey != null) {
          await completeTask(taskKey);
        }
      }
    });
  }
}