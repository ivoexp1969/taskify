// Stub файл - няма да се използва реално
// Нужен е само за conditional imports

Future<void> initializeNotifications() async {}

Future<bool> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  return false;
}

Future<void> cancelNotification(int id) async {}

Future<bool> areNotificationsEnabled() async {
  return false;
}

Future<bool> requestPermission() async {
  return false;
}
