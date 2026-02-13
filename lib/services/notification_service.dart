import 'dart:math';
import 'package:flutter/material.dart';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../main.dart';

// Top-level функция за alarm callback
@pragma('vm:entry-point')
Future<void> _alarmCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await plugin.initialize(initSettings);

  final prefs = await SharedPreferences.getInstance();
  final title = prefs.getString('alarm_${id}_title') ?? 'Напомняне';
  final body = prefs.getString('alarm_${id}_body') ?? 'Имаш задача за изпълнение';
  final payload = prefs.getString('alarm_${id}_payload');

  const androidDetails = AndroidNotificationDetails(
    'task_reminders',
    'Task reminders',
    channelDescription: 'Reminders for your tasks',
    importance: Importance.max,
    priority: Priority.max,
    visibility: NotificationVisibility.public,
    enableVibration: true,
    playSound: true,
    category: AndroidNotificationCategory.reminder,
  );

  const platformDetails = NotificationDetails(android: androidDetails);

  await plugin.show(id, title, body, platformDetails, payload: payload);

  // If this is morning briefing, set flag so app shows dialog on launch
  if (payload == 'morning_briefing') {
    await prefs.setBool('show_morning_briefing', true);
  }

  if (payload != 'morning_briefing') {
    await prefs.remove('alarm_${id}_title');
    await prefs.remove('alarm_${id}_body');
    await prefs.remove('alarm_${id}_payload');
  }
}

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Call from main() to register notification tap handler
  Future<void> init() async {
    await _initIfNeeded();
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload == 'morning_briefing') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_morning_briefing', true);
      }
    }
  }

  Future<void> _initIfNeeded() async {
    if (_initialized) return;

    await AndroidAlarmManager.initialize();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload == 'morning_briefing') {
          _handleMorningBriefingTap();
        }
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

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

      // Отменяме новите нотификации (списък)
      if (task.notificationIds != null) {
        for (final id in task.notificationIds!) {
          await AndroidAlarmManager.cancel(id);
          await _plugin.cancel(id);
        }
        task.notificationIds = null;
      }

      // Отменяме старата нотификация (за съвместимост)
      if (task.notificationId != null) {
        await AndroidAlarmManager.cancel(task.notificationId!);
        await _plugin.cancel(task.notificationId!);
        task.notificationId = null;
      }

      await task.save();
    } catch (_) {}
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
        final label = _reminderLabel(reminderType, true); // TODO: detect language

        await prefs.setString('alarm_${id}_title', task.title);
        await prefs.setString('alarm_${id}_body', label);

        final success = await AndroidAlarmManager.oneShotAt(
          scheduled,
          id,
          _alarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );

        if (success) {
          newIds.add(id);
        }
      }

      if (newIds.isNotEmpty) {
        task.notificationIds = newIds;
        await task.save();
      }
    } catch (_) {}
  }

  /// Generic method to schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool isDaily = false,
    String? payload,
  }) async {
    try {
      await _initIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('alarm_${id}_title', title);
      await prefs.setString('alarm_${id}_body', body);
      if (payload != null) {
        await prefs.setString('alarm_${id}_payload', payload);
      }

      if (isDaily) {
        await AndroidAlarmManager.periodic(
          const Duration(days: 1),
          id,
          _alarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          startAt: scheduledDate,
        );
      } else {
        await AndroidAlarmManager.oneShotAt(
          scheduledDate,
          id,
          _alarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      }
    } catch (_) {}
  }

  void _handleMorningBriefingTap() {
    // Import is needed in main.dart
    final context = MyApp.navigatorKey.currentContext;
    if (context != null) {
      // We'll import and call the dialog from main.dart
      _showBriefingCallback?.call(context);
    }
  }
  
  static Function(BuildContext)? _showBriefingCallback;
  
  static void setMorningBriefingCallback(Function(BuildContext) callback) {
    _showBriefingCallback = callback;
  }
  
  /// Generic method to cancel a notification
  Future<void> cancelNotification(int id) async {
    try {
      await _initIfNeeded();
      await AndroidAlarmManager.cancel(id);
      await _plugin.cancel(id);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_${id}_title');
      await prefs.remove('alarm_${id}_body');
      await prefs.remove('alarm_${id}_payload');
    } catch (_) {}
  }
}