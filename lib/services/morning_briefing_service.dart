import 'package:flutter/foundation.dart';
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

    // Get localized title based on hour and language
    final prefs2 = await SharedPreferences.getInstance();
    final lang = prefs2.getString('app_language') ?? 'en';
    final title = _greetingForHour(briefingHour, lang);
    final body = _tapToSee(lang);

    // Use NotificationService to schedule with proper payload
    await NotificationService().scheduleNotification(
      id: 999, // Fixed ID for morning briefing
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      isDaily: true,
      payload: 'morning_briefing', // This triggers the dialog
    );

    debugPrint('Morning briefing scheduled for $briefingHour:${briefingMinute.toString().padLeft(2, '0')}');
  }

  /// Cancel daily morning briefing
  Future<void> cancelDailyBriefing() async {
    await NotificationService().cancelNotification(999);
    debugPrint('Morning briefing cancelled');
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
      final dueDate = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );
      return dueDate.isBefore(tomorrow);
    }).toList();

    // Sort by priority (higher first) and then by due date (earlier first)
    tasksForToday.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.dueDate.compareTo(b.dueDate);
    });

    // Return top 5 tasks
    return tasksForToday.take(5).toList();
  }

  String _greetingForHour(int hour, String lang) {
    if (hour >= 5 && hour < 12) {
      const m = {'en': 'Good Morning! 🌅', 'bg': 'Добро утро! 🌅', 'de': 'Guten Morgen! 🌅', 'fr': 'Bonjour! 🌅', 'it': 'Buongiorno! 🌅', 'el': 'Καλημέρα! 🌅', 'es': '¡Buenos días! 🌅', 'pt': 'Bom dia! 🌅', 'ru': 'Доброе утро! 🌅', 'tr': 'Günaydın! 🌅'};
      return m[lang] ?? m['en']!;
    } else if (hour >= 12 && hour < 18) {
      const m = {'en': 'Good Afternoon! ☀️', 'bg': 'Добър ден! ☀️', 'de': 'Guten Tag! ☀️', 'fr': 'Bon après-midi! ☀️', 'it': 'Buon pomeriggio! ☀️', 'el': 'Καλό απόγευμα! ☀️', 'es': '¡Buenas tardes! ☀️', 'pt': 'Boa tarde! ☀️', 'ru': 'Добрый день! ☀️', 'tr': 'İyi öğleden sonralar! ☀️'};
      return m[lang] ?? m['en']!;
    } else {
      const m = {'en': 'Good Evening! 🌙', 'bg': 'Добър вечер! 🌙', 'de': 'Guten Abend! 🌙', 'fr': 'Bonsoir! 🌙', 'it': 'Buonasera! 🌙', 'el': 'Καλό βράδυ! 🌙', 'es': '¡Buenas noches! 🌙', 'pt': 'Boa noite! 🌙', 'ru': 'Добрый вечер! 🌙', 'tr': 'İyi akşamlar! 🌙'};
      return m[lang] ?? m['en']!;
    }
  }

  String _tapToSee(String lang) {
    const m = {'en': 'Tap to see your tasks for today', 'bg': 'Натисни за преглед на задачите', 'de': 'Tippen, um deine Aufgaben zu sehen', 'fr': 'Appuyez pour voir vos tâches', 'it': 'Tocca per vedere le tue attività', 'el': 'Πατήστε για να δείτε τις εργασίες σας', 'es': 'Toca para ver tus tareas', 'pt': 'Toque para ver suas tarefas', 'ru': 'Нажмите, чтобы увидеть ваши задачи', 'tr': 'Görevlerinizi görmek için dokunun'};
    return m[lang] ?? m['en']!;
  }

  Future<void> updateBriefingContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('morning_briefing_enabled') ?? false;
      if (!enabled) return;

      final tasks = await getTopTasksForToday();
      if (tasks.isEmpty) return;

      final top3 = tasks.take(3).toList();
      final body = top3.map((t) => '• ${t.title}').join('\n');
      await prefs.setString('alarm_999_body', body);
    } catch (e) {
      debugPrint('MorningBriefingService: updateBriefingContent error: $e');
    }
  }
}
