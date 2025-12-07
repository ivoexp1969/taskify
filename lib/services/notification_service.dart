import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

// Условни импорти
import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_native.dart' as platform;

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  bool _initialized = false;

  /// Инициализация на notification service
  Future<void> _initIfNeeded() async {
    if (_initialized) return;
    await platform.initializeNotifications();
    _initialized = true;
  }

  /// Изчислява времето за напомняне спрямо типа
  DateTime? _computeReminderTime(DateTime dueDate, String reminderType) {
    final now = DateTime.now();
    DateTime result;

    switch (reminderType) {
      case 'at_time':
        result = dueDate;
        break;
      case 'minus_5m':
        result = dueDate.subtract(const Duration(minutes: 5));
        break;
      case 'minus_15m':
        result = dueDate.subtract(const Duration(minutes: 15));
        break;
      case 'minus_30m':
        result = dueDate.subtract(const Duration(minutes: 30));
        break;
      case 'minus_1h':
        result = dueDate.subtract(const Duration(hours: 1));
        break;
      case 'minus_2h':
        result = dueDate.subtract(const Duration(hours: 2));
        break;
      case 'minus_1d':
        result = dueDate.subtract(const Duration(days: 1));
        break;
      case 'same_day_8':
        result = DateTime(dueDate.year, dueDate.month, dueDate.day, 8, 0);
        break;
      default:
        return null;
    }

    if (result.isBefore(now)) {
      return null;
    }

    return result;
  }

  /// Връща текст за напомнянето
  String _reminderLabel(String reminderType, bool isBg) {
    switch (reminderType) {
      case 'at_time':
        return isBg ? 'Сега е времето!' : 'Time is now!';
      case 'minus_5m':
        return isBg ? 'След 5 минути' : 'In 5 minutes';
      case 'minus_15m':
        return isBg ? 'След 15 минути' : 'In 15 minutes';
      case 'minus_30m':
        return isBg ? 'След 30 минути' : 'In 30 minutes';
      case 'minus_1h':
        return isBg ? 'След 1 час' : 'In 1 hour';
      case 'minus_2h':
        return isBg ? 'След 2 часа' : 'In 2 hours';
      case 'minus_1d':
        return isBg ? 'Утре' : 'Tomorrow';
      case 'same_day_8':
        return isBg ? 'Днес' : 'Today';
      default:
        return isBg ? 'Напомняне' : 'Reminder';
    }
  }

  /// Отменя всички нотификации за задача
  Future<void> cancelForTask(Task task) async {
    try {
      await _initIfNeeded();

      if (task.notificationIds != null) {
        for (final id in task.notificationIds!) {
          await platform.cancelNotification(id);
        }
        task.notificationIds = null;
      }

      if (task.notificationId != null) {
        await platform.cancelNotification(task.notificationId!);
        task.notificationId = null;
      }

      await task.save();
    } catch (e) {
      print('Error canceling notification: $e');
    }
  }

  /// Планира всички напомняния за задача
  Future<void> scheduleForTask(Task task) async {
    try {
      await _initIfNeeded();

      // Първо отменяме старите
      await cancelForTask(task);

      final remindersList = task.remindersList;
      if (remindersList.isEmpty) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final newIds = <int>[];

      for (final reminderType in remindersList) {
        final scheduled = _computeReminderTime(task.dueDate, reminderType);
        if (scheduled == null) continue;

        final id = Random().nextInt(0x7FFFFFFF);
        final label = _reminderLabel(reminderType, true);

        // Запазваме данните за нотификацията
        await prefs.setString('alarm_${id}_title', task.title);
        await prefs.setString('alarm_${id}_body', label);
        await prefs.setString('alarm_${id}_scheduled', scheduled.toIso8601String());

        final success = await platform.scheduleNotification(
          id: id,
          title: task.title,
          body: label,
          scheduledTime: scheduled,
        );

        if (success) {
          newIds.add(id);
        }
      }

      if (newIds.isNotEmpty) {
        task.notificationIds = newIds;
        await task.save();
      }
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  /// Проверка дали нотификациите са разрешени
  Future<bool> areNotificationsEnabled() async {
    await _initIfNeeded();
    return platform.areNotificationsEnabled();
  }

  /// Заявка за разрешение за нотификации
  Future<bool> requestPermission() async {
    await _initIfNeeded();
    return platform.requestPermission();
  }
}