import 'dart:async';
import 'dart:html' as html;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

bool _initialized = false;
final Map<int, Timer> _scheduledTimers = {};

Future<void> initializeNotifications() async {
  if (_initialized) return;

  try {
    // Регистрирай Service Worker за background notifications
    if (html.window.navigator.serviceWorker != null) {
      try {
        await html.window.navigator.serviceWorker!
            .register('/firebase-messaging-sw.js');
        print('Service Worker registered successfully');
      } catch (e) {
        print('Service Worker registration failed: $e');
      }
    }

    // Възстанови scheduled notifications
    await restoreScheduledNotifications();

    _initialized = true;
    print('Web notifications initialized');
  } catch (e) {
    print('Error initializing web notifications: $e');
  }
}

Future<bool> requestPermission() async {
  try {
    if (!_isNotificationSupported()) {
      print('Notifications not supported in this browser');
      return false;
    }

    final permission = await html.Notification.requestPermission();
    print('Permission result: $permission');
    return permission == 'granted';
  } catch (e) {
    print('Error requesting permission: $e');
    return false;
  }
}

Future<bool> areNotificationsEnabled() async {
  if (!_isNotificationSupported()) return false;
  return html.Notification.permission == 'granted';
}

Future<bool> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  try {
    final now = DateTime.now();
    final delay = scheduledTime.difference(now);

    if (delay.isNegative) {
      print('Scheduled time is in the past');
      return false;
    }

    // Отмени предишен timer ако има
    _scheduledTimers[id]?.cancel();

    // Запази данните в SharedPreferences за persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('web_notif_$id', jsonEncode({
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
    }));

    // Създай timer за показване на нотификацията
    _scheduledTimers[id] = Timer(delay, () async {
      await _showWebNotification(title, body);
      
      // Премахни от storage след показване
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_notif_$id');
      _scheduledTimers.remove(id);
    });

    print('Scheduled web notification $id for ${scheduledTime.toIso8601String()}');
    return true;
  } catch (e) {
    print('Error scheduling web notification: $e');
    return false;
  }
}

Future<void> cancelNotification(int id) async {
  try {
    _scheduledTimers[id]?.cancel();
    _scheduledTimers.remove(id);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('web_notif_$id');
    
    print('Cancelled web notification $id');
  } catch (e) {
    print('Error canceling web notification: $e');
  }
}

Future<void> _showWebNotification(String title, String body) async {
  if (!_isNotificationSupported()) return;
  
  if (html.Notification.permission != 'granted') {
    print('Notification permission not granted');
    return;
  }

  try {
    html.Notification(
      title,
      body: body,
      icon: '/icons/Icon-192.png',
      tag: 'taskify-reminder',
    );
    print('Showed web notification: $title');
  } catch (e) {
    print('Error showing web notification: $e');
  }
}

bool _isNotificationSupported() {
  try {
    return html.Notification.supported;
  } catch (e) {
    return false;
  }
}

/// Възстанови scheduled notifications при презареждане на страницата
Future<void> restoreScheduledNotifications() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('web_notif_'));
    
    for (final key in keys) {
      final data = prefs.getString(key);
      if (data == null) continue;
      
      try {
        final json = jsonDecode(data);
        final scheduledTime = DateTime.parse(json['scheduledTime']);
        final id = int.parse(key.replaceFirst('web_notif_', ''));
        
        if (scheduledTime.isAfter(DateTime.now())) {
          await scheduleNotification(
            id: id,
            title: json['title'],
            body: json['body'],
            scheduledTime: scheduledTime,
          );
        } else {
          // Премахни изтекли нотификации
          await prefs.remove(key);
        }
      } catch (e) {
        print('Error restoring notification $key: $e');
      }
    }
  } catch (e) {
    print('Error restoring scheduled notifications: $e');
  }
}