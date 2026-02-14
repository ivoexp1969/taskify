import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskViewMode { compact, expanded }

class TaskViewPreference extends ChangeNotifier {
  TaskViewPreference._internal();
  static final TaskViewPreference _instance = TaskViewPreference._internal();
  factory TaskViewPreference() => _instance;
  static const String _key = 'task_view_mode';
  TaskViewMode _mode = TaskViewMode.expanded;
  bool _isInitialized = false;
  TaskViewMode get mode => _mode;
  bool get isCompact => _mode == TaskViewMode.compact;
  bool get isExpanded => _mode == TaskViewMode.expanded;
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_key);
      if (savedMode != null) _mode = savedMode == 'compact' ? TaskViewMode.compact : TaskViewMode.expanded;
      _isInitialized = true;
      notifyListeners();
    } catch (e) { _isInitialized = true; }
  }
  Future<void> setMode(TaskViewMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == TaskViewMode.compact ? 'compact' : 'expanded');
    } catch (e) {}
  }
}
