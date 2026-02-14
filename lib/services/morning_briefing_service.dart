import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import 'notification_service.dart';

class MorningBriefingService {
  /// Schedule daily morning briefing at specified time
  /// If no time specified, loads from SharedPreferences (default 8:00 AM)
  Future<void> scheduleDailyBriefing({int? hour, int? minute}) async {
    // Load saved time if not provided
    int briefingHour = hour ?? 8;
    int briefingMinute = minute ?? 0;
    
    if (hour == null || minute == null) {
      final prefs = await SharedPreferences.getInstance();
      briefingHour = prefs.getInt('briefing_hour') ?? 8;
      briefingMinute = prefs.getInt('briefing_minute') ?? 0;
    }

    // Cancel any existing briefings
    await cancelDailyBriefing();

    // Calculate next briefing time
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      briefingHour,
      briefingMinute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Use NotificationService to schedule with proper payload
    await NotificationService().scheduleNotification(
      id: 999, // Fixed ID for morning briefing
      title: 'Good Morning! 🌅',
      body: 'Tap to see your tasks for today',
      scheduledDate: scheduledDate,
      isDaily: true,
      payload: 'morning_briefing', // This triggers the dialog
    );

    print('Morning briefing scheduled for ${briefingHour}:${briefingMinute.toString().padLeft(2, '0')}');
  }

  /// Cancel daily morning briefing
  Future<void> cancelDailyBriefing() async {
    await NotificationService().cancelNotification(999);
    print('Morning briefing cancelled');
  }

  /// Check if briefing is currently enabled
  Future<bool> isBriefingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('morning_briefing_enabled') ?? false;
  }

  /// Get top priority tasks for today
  Future<List<Task>> getTopTasksForToday() async {
    final taskBox = Hive.box<Task>('tasks');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Get tasks due today or overdue
    final tasksForToday = taskBox.values.where((task) {
      if (task.isCompleted) return false;
      if (task.dueDate == null) return false;
      
      final dueDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      
      // Include overdue and today's tasks
      return dueDate.isBefore(tomorrow);
    }).toList();

    // Sort by priority (higher first) and then by due date (earlier first)
    tasksForToday.sort((a, b) {
      // First sort by priority (3 > 2 > 1)
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      
      // Then by due date (earlier first)
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    // Return top 5 tasks
    return tasksForToday.take(5).toList();
  }
}
