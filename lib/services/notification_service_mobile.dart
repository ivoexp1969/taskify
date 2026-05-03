import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/task.dart';
import '../main.dart';

// Top-level функция за alarm callback (Android only)
@pragma('vm:entry-point')
Future<void> _alarmCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await plugin.initialize(initSettings);

  final prefs = await SharedPreferences.getInstance();
  final lang = prefs.getString('app_language') ?? 'en';

  const _fallbackTitle = {'en': 'Reminder', 'bg': 'Напомняне', 'de': 'Erinnerung', 'fr': 'Rappel', 'it': 'Promemoria', 'el': 'Υπενθύμιση', 'es': 'Recordatorio', 'pt': 'Lembrete', 'ru': 'Напоминание', 'tr': 'Hatırlatıcı'};
  const _fallbackBody = {'en': 'You have a task to complete', 'bg': 'Имаш задача за изпълнение', 'de': 'Du hast eine Aufgabe zu erledigen', 'fr': 'Vous avez une tâche à accomplir', 'it': 'Hai un\'attività da completare', 'el': 'Έχετε μια εργασία να ολοκληρώσετε', 'es': 'Tienes una tarea por completar', 'pt': 'Você tem uma tarefa para concluir', 'ru': 'У вас есть задача для выполнения', 'tr': 'Tamamlamanız gereken bir görev var'};

  final title = prefs.getString('alarm_${id}_title') ?? (_fallbackTitle[lang] ?? _fallbackTitle['en']!);
  final body = prefs.getString('alarm_${id}_body') ?? (_fallbackBody[lang] ?? _fallbackBody['en']!);
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

    tz_data.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }

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

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

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

    if (result.isBefore(now)) return null;
    return result;
  }

  String _reminderLabel(String reminderType, String lang) {
    const labels = {
      'at_time': {'en': 'Time is now!', 'bg': 'Сега е времето!', 'de': 'Zeit ist da!', 'fr': "C'est l'heure!", 'it': "È ora!", 'el': 'Ήρθε η ώρα!', 'es': '¡Es la hora!', 'pt': 'Chegou a hora!', 'ru': 'Время пришло!', 'tr': 'Şimdi zamanı!'},
      'minus_5m': {'en': 'In 5 minutes', 'bg': 'След 5 минути', 'de': 'In 5 Minuten', 'fr': 'Dans 5 minutes', 'it': 'Tra 5 minuti', 'el': 'Σε 5 λεπτά', 'es': 'En 5 minutos', 'pt': 'Em 5 minutos', 'ru': 'Через 5 минут', 'tr': '5 dakika içinde'},
      'minus_15m': {'en': 'In 15 minutes', 'bg': 'След 15 минути', 'de': 'In 15 Minuten', 'fr': 'Dans 15 minutes', 'it': 'Tra 15 minuti', 'el': 'Σε 15 λεπτά', 'es': 'En 15 minutos', 'pt': 'Em 15 minutos', 'ru': 'Через 15 минут', 'tr': '15 dakika içinde'},
      'minus_30m': {'en': 'In 30 minutes', 'bg': 'След 30 минути', 'de': 'In 30 Minuten', 'fr': 'Dans 30 minutes', 'it': 'Tra 30 minuti', 'el': 'Σε 30 λεπτά', 'es': 'En 30 minutos', 'pt': 'Em 30 minutos', 'ru': 'Через 30 минут', 'tr': '30 dakika içinde'},
      'minus_1h': {'en': 'In 1 hour', 'bg': 'След 1 час', 'de': 'In 1 Stunde', 'fr': 'Dans 1 heure', 'it': 'Tra 1 ora', 'el': 'Σε 1 ώρα', 'es': 'En 1 hora', 'pt': 'Em 1 hora', 'ru': 'Через 1 час', 'tr': '1 saat içinde'},
      'minus_2h': {'en': 'In 2 hours', 'bg': 'След 2 часа', 'de': 'In 2 Stunden', 'fr': 'Dans 2 heures', 'it': 'Tra 2 ore', 'el': 'Σε 2 ώρες', 'es': 'En 2 horas', 'pt': 'Em 2 horas', 'ru': 'Через 2 часа', 'tr': '2 saat içinde'},
      'minus_1d': {'en': 'Tomorrow', 'bg': 'Утре', 'de': 'Morgen', 'fr': 'Demain', 'it': 'Domani', 'el': 'Αύριο', 'es': 'Mañana', 'pt': 'Amanhã', 'ru': 'Завтра', 'tr': 'Yarın'},
      'same_day_8': {'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün'},
    };
    const defaultLabel = {'en': 'Reminder', 'bg': 'Напомняне', 'de': 'Erinnerung', 'fr': 'Rappel', 'it': 'Promemoria', 'el': 'Υπενθύμιση', 'es': 'Recordatorio', 'pt': 'Lembrete', 'ru': 'Напоминание', 'tr': 'Hatırlatıcı'};
    final map = labels[reminderType] ?? defaultLabel;
    return map[lang] ?? map['en'] ?? 'Reminder';
  }

  NotificationDetails _buildNotificationDetails(String title) {
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
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Future<void> cancelForTask(Task task) async {
    try {
      await _initIfNeeded();

      if (task.notificationIds != null) {
        for (final id in task.notificationIds!) {
          if (Platform.isAndroid) await AndroidAlarmManager.cancel(id);
          await _plugin.cancel(id);
        }
        task.notificationIds = null;
      }

      if (task.notificationId != null) {
        if (Platform.isAndroid) await AndroidAlarmManager.cancel(task.notificationId!);
        await _plugin.cancel(task.notificationId!);
        task.notificationId = null;
      }

      await task.save();
    } catch (e) { debugPrint('NotificationService error: $e'); }
  }

  Future<void> scheduleForTask(Task task) async {
    try {
      await _initIfNeeded();
      await cancelForTask(task);

      final remindersList = task.remindersList;
      if (remindersList.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final newIds = <int>[];

      for (final reminderType in remindersList) {
        final scheduled = _computeReminderTime(task.dueDate, reminderType);
        if (scheduled == null) continue;

        final id = Random().nextInt(0x7FFFFFFF);
        final label = _reminderLabel(reminderType, prefs.getString('app_language') ?? 'en');

        if (Platform.isAndroid) {
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

          if (success) newIds.add(id);
        } else {
          // iOS: use flutter_local_notifications zonedSchedule
          final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);
          await _plugin.zonedSchedule(
            id,
            task.title,
            label,
            tzScheduled,
            _buildNotificationDetails(task.title),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          newIds.add(id);
        }
      }

      if (newIds.isNotEmpty) {
        task.notificationIds = newIds;
        await task.save();
      }
    } catch (e) { debugPrint('NotificationService error: $e'); }
  }

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

      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('alarm_${id}_title', title);
        await prefs.setString('alarm_${id}_body', body);
        if (payload != null) await prefs.setString('alarm_${id}_payload', payload);

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
      } else {
        // iOS
        final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        const details = NotificationDetails(iOS: iosDetails);

        if (isDaily) {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            tzScheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );
        } else {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            tzScheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
        }
      }
    } catch (e) { debugPrint('NotificationService error: $e'); }
  }

  void _handleMorningBriefingTap() {
    final context = MyApp.navigatorKey.currentContext;
    if (context != null) {
      _showBriefingCallback?.call(context);
    }
  }

  static Function(BuildContext)? _showBriefingCallback;

  static void setMorningBriefingCallback(Function(BuildContext) callback) {
    _showBriefingCallback = callback;
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _initIfNeeded();
      if (Platform.isAndroid) await AndroidAlarmManager.cancel(id);
      await _plugin.cancel(id);

      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('alarm_${id}_title');
        await prefs.remove('alarm_${id}_body');
        await prefs.remove('alarm_${id}_payload');
      }
    } catch (e) { debugPrint('NotificationService error: $e'); }
  }
}
