import '../models/task.dart';
import 'package:flutter/material.dart';

// Stub за web - празна имплементация
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  Future<void> init() async {
    // No-op на web
  }

  Future<void> cancelForTask(Task task) async {
    // No-op на web
  }

  Future<void> scheduleForTask(Task task) async {
    // No-op на web
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool isDaily = false,
    String? payload,
  }) async {
    // No-op на web
  }

  static void setMorningBriefingCallback(Function(BuildContext) callback) {
    // No-op на web
  }

  Future<void> scheduleTrialCountdownNotification(DateTime trialEndDate) async {
    // No-op на web
  }

  Future<void> cancelNotification(int id) async {
    // No-op на web
  }
}
