import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_calendar_service.dart';

class MorningBriefingService {
  static const int briefingNotificationId = 999999;
  
  /// Schedule daily morning briefing at specified time
  Future<void> scheduleDailyBriefing({int hour = 8, int minute = 0}) async {
    final now = DateTime.now();
    
var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    await NotificationService().scheduleNotification(
      id: briefingNotificationId,
      title: 'Good Morning! 🌅',
      body: 'Tap to see your top priorities for today',
      scheduledDate: scheduledDate,
      isDaily: true,
      payload: 'morning_briefing',
    );
    
    // Save scheduled time for launch check
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('morning_briefing_last_scheduled', scheduledDate.millisecondsSinceEpoch);
  }
  
  /// Cancel morning briefing
  Future<void> cancelDailyBriefing() async {
    await NotificationService().cancelNotification(briefingNotificationId);
  }
  
  /// Get top 3 tasks for today
  Future<List<Task>> getTopTasksForToday() async {
    final box = await Hive.openBox<Task>('tasks');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    // Get incomplete tasks for today or overdue
    final incompleteTasks = box.values
        .where((task) => 
            !task.isCompleted && 
            !task.isArchived &&
            task.dueDate.isBefore(tomorrow)
        )
        .toList();
    
    // Score each task
    final scoredTasks = incompleteTasks.map((task) {
      int score = 0;
      
      // Due date scoring (higher = more urgent)
      if (task.dueDate.isBefore(tomorrow)) {
        score += 100; // Due today
      } else if (task.dueDate.isBefore(today.add(const Duration(days: 3)))) {
        score += 50; // Due within 3 days
      } else if (task.dueDate.isBefore(today.add(const Duration(days: 7)))) {
        score += 25; // Due within a week
      }
      
      // Priority scoring
      score += task.priority * 20; // 0, 20, or 40 points
      
      // Overdue penalty (make them appear first)
      if (task.dueDate.isBefore(today)) {
        score += 200; // Overdue tasks get highest priority
      }
      
      return {'task': task, 'score': score};
    }).toList();
    
    // Sort by score descending
    scoredTasks.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    // Return top 3
    return scoredTasks
        .take(3)
        .map((item) => item['task'] as Task)
        .toList();
  }
  
  /// Generate briefing text
  Future<String> generateBriefingText() async {
    final topTasks = await getTopTasksForToday();
    
    if (topTasks.isEmpty) {
      return 'No tasks for today! Enjoy your day! ✨';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Your top priorities:');
    
    for (var i = 0; i < topTasks.length; i++) {
      final task = topTasks[i];
      final number = i + 1;
      buffer.writeln('$number. ${task.title}');
    }
    
    return buffer.toString().trim();
  }
}
