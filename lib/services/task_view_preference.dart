import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskViewMode { compact, expanded }

/// Визуален стил на task картите. classic = сегашната ExpandableTaskCard (default),
/// ticket = алтернативна „билетна" кожа. Логиката е обща, различава се само скинът.
enum CardStyle { classic, ticket }

class TaskViewPreference extends ChangeNotifier {
  TaskViewPreference._internal();
  static final TaskViewPreference _instance = TaskViewPreference._internal();
  factory TaskViewPreference() => _instance;
  static const String _key = 'task_view_mode';
  static const String _cardStyleKey = 'card_style';
  TaskViewMode _mode = TaskViewMode.expanded;
  CardStyle _cardStyle = CardStyle.classic;
  bool _isInitialized = false;
  TaskViewMode get mode => _mode;
  bool get isCompact => _mode == TaskViewMode.compact;
  bool get isExpanded => _mode == TaskViewMode.expanded;
  CardStyle get cardStyle => _cardStyle;
  bool get isTicket => _cardStyle == CardStyle.ticket;
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_key);
      if (savedMode != null) _mode = savedMode == 'compact' ? TaskViewMode.compact : TaskViewMode.expanded;
      final savedStyle = prefs.getString(_cardStyleKey);
      if (savedStyle == 'ticket') _cardStyle = CardStyle.ticket;
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
  Future<void> setCardStyle(CardStyle style) async {
    if (_cardStyle == style) return;
    _cardStyle = style;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cardStyleKey, style == CardStyle.ticket ? 'ticket' : 'classic');
    } catch (e) {}
  }
}
