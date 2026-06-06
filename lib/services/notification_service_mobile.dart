import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/task.dart';
import '../main.dart';

// Background handler за notification action buttons (snooze / quick_add)
@pragma('vm:entry-point')
Future<void> _onNotificationActionBackground(NotificationResponse details) async {
  if (details.actionId == 'quick_add') {
    // AndroidNotificationActionInput е Android-only — на iOS тази action не се показва
    if (!Platform.isAndroid) return;
    final text = details.input?.trim() ?? '';
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quick_add_pending_title', text);

    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: androidInit));
    final lang = prefs.getString('app_language') ?? 'en';
    const confirmTitle = {'en': 'Task added ✓', 'bg': 'Задача добавена ✓', 'de': 'Aufgabe hinzugefügt ✓', 'fr': 'Tâche ajoutée ✓', 'it': 'Attività aggiunta ✓', 'el': 'Εργασία προστέθηκε ✓', 'es': 'Tarea añadida ✓', 'pt': 'Tarefa adicionada ✓', 'ru': 'Задача добавлена ✓', 'tr': 'Görev eklendi ✓', 'ja': 'タスクを追加しました ✓'};
    await plugin.show(
      99998,
      confirmTitle[lang] ?? confirmTitle['en']!,
      text,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders', 'Task reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
    return;
  }

  if (details.actionId != 'snooze') return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await plugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

  tz_data.initializeTimeZones();
  try {
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }

  final prefs = await SharedPreferences.getInstance();
  final lang = prefs.getString('app_language') ?? 'en';
  final id = details.id ?? 0;

  const fallbackTitle = {
    'en': 'Reminder', 'bg': 'Напомняне', 'de': 'Erinnerung', 'fr': 'Rappel',
    'it': 'Promemoria', 'el': 'Υπενθύμιση', 'es': 'Recordatorio',
    'pt': 'Lembrete', 'ru': 'Напоминание', 'tr': 'Hatırlatıcı', 'ja': 'リマインダー',
  };
  final title = prefs.getString('alarm_${id}_title') ?? (fallbackTitle[lang] ?? fallbackTitle['en']!);

  const snoozeBody = {
    'en': 'Snoozed • 30 minutes', 'bg': 'Отложено • 30 минути', 'de': 'Verschoben • 30 Minuten',
    'fr': 'Reporté • 30 minutes', 'it': 'Posticipato • 30 minuti', 'el': 'Αναβλήθηκε • 30 λεπτά',
    'es': 'Pospuesto • 30 minutos', 'pt': 'Adiado • 30 minutos',
    'ru': 'Отложено • 30 минут', 'tr': 'Ertelendi • 30 dakika', 'ja': 'スヌーズ • 30分',
  };
  const snoozeLabel = {
    'en': '⏰ +30 min', 'bg': '⏰ +30 мин', 'de': '⏰ +30 Min', 'fr': '⏰ +30 min',
    'it': '⏰ +30 min', 'el': '⏰ +30 λεπτά', 'es': '⏰ +30 min',
    'pt': '⏰ +30 min', 'ru': '⏰ +30 мин', 'tr': '⏰ +30 dk', 'ja': '⏰ +30分',
  };

  final newId = (id + 5000) & 0x7FFFFFFF;
  await prefs.setString('alarm_${newId}_title', title);

  final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));

  final androidDetails = AndroidNotificationDetails(
    'task_reminders',
    'Task reminders',
    channelDescription: 'Reminders for your tasks',
    importance: Importance.max,
    priority: Priority.max,
    enableVibration: true,
    playSound: true,
    actions: [
      AndroidNotificationAction('snooze', snoozeLabel[lang] ?? snoozeLabel['en']!, cancelNotification: true),
    ],
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  await plugin.zonedSchedule(
    newId,
    title,
    snoozeBody[lang] ?? snoozeBody['en']!,
    scheduled,
    NotificationDetails(android: androidDetails, iOS: iosDetails),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  );
}

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

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

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload == 'morning_briefing') {
          _handleMorningBriefingTap();
        } else if (details.actionId == 'snooze') {
          _onNotificationActionBackground(details);
        }
      },
      onDidReceiveBackgroundNotificationResponse: _onNotificationActionBackground,
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
      'at_time': {'en': 'Time is now!', 'bg': 'Сега е времето!', 'de': 'Zeit ist da!', 'fr': "C'est l'heure!", 'it': "È ora!", 'el': 'Ήρθε η ώρα!', 'es': '¡Es la hora!', 'pt': 'Chegou a hora!', 'ru': 'Время пришло!', 'tr': 'Şimdi zamanı!', 'ja': '時間です！'},
      'minus_5m': {'en': 'In 5 minutes', 'bg': 'След 5 минути', 'de': 'In 5 Minuten', 'fr': 'Dans 5 minutes', 'it': 'Tra 5 minuti', 'el': 'Σε 5 λεπτά', 'es': 'En 5 minutos', 'pt': 'Em 5 minutos', 'ru': 'Через 5 минут', 'tr': '5 dakika içinde', 'ja': '5分後'},
      'minus_15m': {'en': 'In 15 minutes', 'bg': 'След 15 минути', 'de': 'In 15 Minuten', 'fr': 'Dans 15 minutes', 'it': 'Tra 15 minuti', 'el': 'Σε 15 λεπτά', 'es': 'En 15 minutos', 'pt': 'Em 15 minutos', 'ru': 'Через 15 минут', 'tr': '15 dakika içinde', 'ja': '15分後'},
      'minus_30m': {'en': 'In 30 minutes', 'bg': 'След 30 минути', 'de': 'In 30 Minuten', 'fr': 'Dans 30 minutes', 'it': 'Tra 30 minuti', 'el': 'Σε 30 λεπτά', 'es': 'En 30 minutos', 'pt': 'Em 30 minutos', 'ru': 'Через 30 минут', 'tr': '30 dakika içinde', 'ja': '30分後'},
      'minus_1h': {'en': 'In 1 hour', 'bg': 'След 1 час', 'de': 'In 1 Stunde', 'fr': 'Dans 1 heure', 'it': 'Tra 1 ora', 'el': 'Σε 1 ώρα', 'es': 'En 1 hora', 'pt': 'Em 1 hora', 'ru': 'Через 1 час', 'tr': '1 saat içinde', 'ja': '1時間後'},
      'minus_2h': {'en': 'In 2 hours', 'bg': 'След 2 часа', 'de': 'In 2 Stunden', 'fr': 'Dans 2 heures', 'it': 'Tra 2 ore', 'el': 'Σε 2 ώρες', 'es': 'En 2 horas', 'pt': 'Em 2 horas', 'ru': 'Через 2 часа', 'tr': '2 saat içinde', 'ja': '2時間後'},
      'minus_1d': {'en': 'Tomorrow', 'bg': 'Утре', 'de': 'Morgen', 'fr': 'Demain', 'it': 'Domani', 'el': 'Αύριο', 'es': 'Mañana', 'pt': 'Amanhã', 'ru': 'Завтра', 'tr': 'Yarın', 'ja': '明日'},
      'same_day_8': {'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün', 'ja': '今日'},
    };
    const defaultLabel = {
      'en': 'Reminder', 'bg': 'Напомняне', 'de': 'Erinnerung', 'fr': 'Rappel',
      'it': 'Promemoria', 'el': 'Υπενθύμιση', 'es': 'Recordatorio',
      'pt': 'Lembrete', 'ru': 'Напоминание', 'tr': 'Hatırlatıcı', 'ja': 'リマインダー',
    };
    final map = labels[reminderType] ?? defaultLabel;
    return map[lang] ?? map['en'] ?? 'Reminder';
  }

  NotificationDetails _buildNotificationDetails({String? lang}) {
    const snoozeLabels = {
      'en': '⏰ +30 min', 'bg': '⏰ +30 мин', 'de': '⏰ +30 Min', 'fr': '⏰ +30 min',
      'it': '⏰ +30 min', 'el': '⏰ +30 λεπτά', 'es': '⏰ +30 min',
      'pt': '⏰ +30 min', 'ru': '⏰ +30 мин', 'tr': '⏰ +30 dk', 'ja': '⏰ +30分',
    };
    final snoozeLabel = snoozeLabels[lang ?? 'en'] ?? snoozeLabels['en']!;

    final androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminders for your tasks',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction('snooze', snoozeLabel, cancelNotification: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Future<void> cancelForTask(Task task) async {
    try {
      await _initIfNeeded();

      if (task.notificationIds != null) {
        for (final id in task.notificationIds!) {
          await _plugin.cancel(id);
        }
        task.notificationIds = null;
      }

      if (task.notificationId != null) {
        await _plugin.cancel(task.notificationId!);
        task.notificationId = null;
      }

      await task.save();
    } catch (e) {
      debugPrint('NotificationService cancelForTask error: $e');
    }
  }

  Future<void> scheduleForTask(Task task) async {
    try {
      await _initIfNeeded();
      await cancelForTask(task);

      final remindersList = task.remindersList;
      if (remindersList.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_language') ?? 'en';
      final newIds = <int>[];

      for (final reminderType in remindersList) {
        final scheduled = _computeReminderTime(task.dueDate, reminderType);
        if (scheduled == null) continue;

        final id = Random().nextInt(0x7FFFFFFF);
        final label = _reminderLabel(reminderType, lang);

        // Запазваме заглавието за snooze handler
        await prefs.setString('alarm_${id}_title', task.title);

        final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);
        await _plugin.zonedSchedule(
          id,
          task.title,
          label,
          tzScheduled,
          _buildNotificationDetails(lang: lang),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        newIds.add(id);
      }

      if (newIds.isNotEmpty) {
        task.notificationIds = newIds;
        await task.save();
      }
    } catch (e) {
      debugPrint('NotificationService scheduleForTask error: $e');
    }
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

      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'task_reminders',
        'Task reminders',
        channelDescription: 'Reminders for your tasks',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: isDaily ? DateTimeComponents.time : null,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService scheduleNotification error: $e');
    }
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

  Future<void> scheduleTrialCountdownNotification(DateTime trialEndDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('trial_countdown_done') ?? false) return;
      await prefs.setBool('trial_countdown_done', true);

      final lang = prefs.getString('app_language') ?? 'en';
      const titles = {
        'en': '⏰ Pro trial ends in 3 days',
        'bg': '⏰ Pro пробният период е до 3 дни',
        'de': '⏰ Pro-Test endet in 3 Tagen',
        'fr': '⏰ L\'essai Pro se termine dans 3 jours',
        'it': '⏰ Il periodo di prova Pro finisce tra 3 giorni',
        'el': '⏰ Η δοκιμή Pro λήγει σε 3 ημέρες',
        'es': '⏰ El período de prueba Pro termina en 3 días',
        'pt': '⏰ O período de teste Pro termina em 3 dias',
        'ru': '⏰ Пробный период Pro заканчивается через 3 дня',
        'tr': '⏰ Pro deneme süresi 3 gün sonra sona eriyor', 'ja': '⏰ Proトライアルは3日後に終了',
      };
      const bodies = {
        'en': 'Upgrade now to keep all your tasks, reminders and calendar sync.',
        'bg': 'Надстрой сега, за да запазиш задачите, напомнянията и синхронизацията.',
        'de': 'Jetzt upgraden, um Aufgaben, Erinnerungen und Kalender zu behalten.',
        'fr': 'Mettez à niveau pour conserver vos tâches, rappels et la synchronisation.',
        'it': 'Aggiorna ora per mantenere attività, promemoria e sincronizzazione.',
        'el': 'Αναβαθμίστε τώρα για να διατηρήσετε εργασίες, υπενθυμίσεις και συγχρονισμό.',
        'es': 'Actualiza ahora para mantener tareas, recordatorios y sincronización.',
        'pt': 'Atualize agora para manter suas tarefas, lembretes e sincronização.',
        'ru': 'Обновитесь, чтобы сохранить задачи, напоминания и синхронизацию.',
        'tr': 'Görevlerinizi, hatırlatıcılarınızı ve senkronizasyonu korumak için yükseltin.', 'ja': '今すぐアップグレードして、すべてのタスク、リマインダー、カレンダー同期を維持しましょう。',
      };

      await _initIfNeeded();

      final notifDate = trialEndDate.subtract(const Duration(days: 3));
      final now = DateTime.now();

      if (notifDate.isBefore(now)) {
        final daysLeft = trialEndDate.difference(now).inDays;
        if (daysLeft <= 0) return;

        const androidDetails = AndroidNotificationDetails(
          'trial_countdown',
          'Trial',
          channelDescription: 'Trial expiry notifications',
          importance: Importance.high,
          priority: Priority.high,
        );
        const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);

        await _plugin.show(
          997,
          titles[lang] ?? titles['en']!,
          bodies[lang] ?? bodies['en']!,
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
          payload: 'trial_countdown',
        );
      } else {
        await scheduleNotification(
          id: 997,
          title: titles[lang] ?? titles['en']!,
          body: bodies[lang] ?? bodies['en']!,
          scheduledDate: notifDate,
          payload: 'trial_countdown',
        );
      }
    } catch (e) {
      debugPrint('scheduleTrialCountdownNotification error: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _initIfNeeded();
      await _plugin.cancel(id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_${id}_title');
      await prefs.remove('alarm_${id}_body');
      await prefs.remove('alarm_${id}_payload');
    } catch (e) {
      debugPrint('NotificationService cancelNotification error: $e');
    }
  }
}
