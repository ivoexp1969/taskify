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
    } catch (e) { debugPrint('NotificationService error: $e'); }
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
        final label = _reminderLabel(reminderType, prefs.getString('app_language') ?? 'en');

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
    } catch (e) { debugPrint('NotificationService error: $e'); }
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
    } catch (e) { debugPrint('NotificationService error: $e'); }
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
    } catch (e) { debugPrint('NotificationService error: $e'); }
  }
}