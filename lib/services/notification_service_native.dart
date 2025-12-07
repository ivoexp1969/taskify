import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;

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

  await plugin.show(id, title, body, platformDetails);

  await prefs.remove('alarm_${id}_title');
  await prefs.remove('alarm_${id}_body');
  await prefs.remove('alarm_${id}_scheduled');
}

Future<void> initializeNotifications() async {
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

  await _plugin.initialize(initSettings);

  final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }

  _initialized = true;
}

Future<bool> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  try {
    final success = await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      id,
      _alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    return success;
  } catch (e) {
    print('Error scheduling native notification: $e');
    return false;
  }
}

Future<void> cancelNotification(int id) async {
  try {
    await AndroidAlarmManager.cancel(id);
    await _plugin.cancel(id);
  } catch (e) {
    print('Error canceling native notification: $e');
  }
}

Future<bool> areNotificationsEnabled() async {
  final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    return await androidPlugin.areNotificationsEnabled() ?? false;
  }
  return true; // Assume enabled for iOS
}

Future<bool> requestPermission() async {
  final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    return await androidPlugin.requestNotificationsPermission() ?? false;
  }
  return true;
}
