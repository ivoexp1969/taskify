import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'holidays_service.dart';
import 'name_days_service.dart';
import 'pro_service.dart';

class WidgetService {
  static const _channel = MethodChannel('com.ivoexp.taskify/widget');

  /// Колко дни напред гледаме за изтичащ документ в widget-а.
  static const int _docLookAheadDays = 14;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> updateWidget() async {
    if (_isIOS) {
      await _syncTasksToAppGroup();
      return;
    }
    if (!_isAndroid) return;
    try {
      await _syncTasksToPrefs();
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }

  static Future<void> _syncTasksToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final taskBox = Hive.box<Task>('tasks');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final todayTasks = taskBox.values.where((t) {
        if (t.isCompleted) return false;
        final taskDate = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
        return taskDate.isBefore(tomorrow);
      }).toList();

      todayTasks.sort((a, b) {
        final aOverdue = a.dueDate.isBefore(now);
        final bOverdue = b.dueDate.isBefore(now);
        if (aOverdue && !bOverdue) return -1;
        if (!aOverdue && bOverdue) return 1;
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.dueDate.compareTo(b.dueDate);
      });

      final tasksJson = todayTasks.map((t) => {
        'key': t.key,
        'title': t.title,
        'isCompleted': t.isCompleted,
        'priority': t.priority,
        'dueDate': t.dueDate.toIso8601String(),
      }).toList();

      await prefs.setString('widget_tasks', jsonEncode(tasksJson));
      await _syncContextToPrefs(prefs);
    } catch (e) {
      debugPrint('Sync tasks error: $e');
    }
  }

  /// Локалният контекст на widget-а (диференциаторът): изтичащ документ, имен
  /// ден, официален празник. Записва се готов, ЛОКАЛИЗИРАН текст в
  /// `widget_context` (Kotlin чете `flutter.widget_context`) — само наличните
  /// ключове. Kotlin избира по приоритет: docExpiry > nameDay > holiday.
  ///
  /// Уважава Pro статуса и toggle-ите: ако не е Pro или функциите са изключени,
  /// ключът се трие → widget-ът не показва реда.
  /// Изчислява локалния контекст (готови локализирани редове), уважавайки Pro +
  /// toggle-ите. Общ за Android (пише в prefs) и iOS (изпраща към App Group).
  static Future<Map<String, String>> _computeWidgetContext(
      SharedPreferences prefs) async {
    final ctx = <String, String>{};
    if (ProService().isPro) {
      final lang = prefs.getString('app_language') ?? 'en';

      final doc = _docExpiryLine(lang);
      if (doc != null) ctx['docExpiry'] = doc;

      if (prefs.getBool('name_days_enabled') ?? false) {
        final nameDay = await _nameDayLine(lang);
        if (nameDay != null) ctx['nameDay'] = nameDay;
      }

      if (prefs.getBool('holidays_enabled') ?? false) {
        final holiday = await _holidayLine(lang);
        if (holiday != null) ctx['holiday'] = holiday;
      }
    }
    return ctx;
  }

  static Future<void> _syncContextToPrefs(SharedPreferences prefs) async {
    try {
      final ctx = await _computeWidgetContext(prefs);
      if (ctx.isEmpty) {
        await prefs.remove('widget_context');
      } else {
        await prefs.setString('widget_context', jsonEncode(ctx));
      }
    } catch (e) {
      debugPrint('Widget context sync error: $e');
    }
  }

  /// Най-близкият документ, който изтича до [_docLookAheadDays] дни.
  /// Документите са обикновени задачи (`template == 'document'`).
  static String? _docExpiryLine(String lang) {
    final taskBox = Hive.box<Task>('tasks');
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    Task? nearest;
    int nearestDays = 1 << 30;
    for (final t in taskBox.values) {
      if (t.template != 'document' || t.isCompleted || t.isArchived) continue;
      final due =
          DateTime.utc(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      final days = due.difference(today).inDays; // UTC → без DST дрейф
      if (days < 0 || days > _docLookAheadDays) continue;
      if (days < nearestDays) {
        nearest = t;
        nearestDays = days;
      }
    }
    if (nearest == null) return null;

    final name = nearest.title;
    final String tpl;
    if (nearestDays == 0) {
      tpl = _docToday[lang] ?? _docToday['en']!;
    } else if (nearestDays == 1) {
      tpl = _docTomorrow[lang] ?? _docTomorrow['en']!;
    } else {
      tpl = _docInDays[lang] ?? _docInDays['en']!;
    }
    return '⏳ ${tpl.replaceAll('{name}', name).replaceAll('{days}', '$nearestDays')}';
  }

  /// Имената, които празнуват ДНЕС (локален dataset, offline).
  static Future<String?> _nameDayLine(String lang) async {
    final service = NameDaysService();
    await service.load();
    final nameDay = service.forDate(DateTime.now());
    if (nameDay == null || nameDay.names.isEmpty) return null;

    final names = nameDay.names.length > 3
        ? '${nameDay.names.take(3).join(', ')}…'
        : nameDay.names.join(', ');
    final tpl = _nameDayToday[lang] ?? _nameDayToday['en']!;
    return '🎉 ${tpl.replaceAll('{names}', names)}';
  }

  /// Официален празник днес или утре (offline-first кеш; BG е локален).
  static Future<String?> _holidayLine(String lang) async {
    final service = HolidaysService();
    await service.loadEnabled(); // зарежда и държавата
    if (!service.hasData) await service.loadForCurrentYears();

    final now = DateTime.now();
    final today = service.forDate(now);
    if (today != null) {
      final tpl = _holidayToday[lang] ?? _holidayToday['en']!;
      return '🎈 ${tpl.replaceAll('{name}', today)}';
    }
    // Календарна аритметика (без Duration) — заради DST.
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final next = service.forDate(tomorrow);
    if (next != null) {
      final tpl = _holidayTomorrow[lang] ?? _holidayTomorrow['en']!;
      return '🎈 ${tpl.replaceAll('{name}', next)}';
    }
    return null;
  }

  static const Map<String, String> _docToday = {
    'en': '{name} expires today', 'bg': '{name} изтича ДНЕС',
    'de': '{name} läuft heute ab', 'fr': "{name} expire aujourd'hui",
    'it': '{name} scade oggi', 'el': '{name} λήγει σήμερα',
    'es': '{name} caduca hoy', 'pt': '{name} expira hoje',
    'ru': '{name} истекает сегодня', 'tr': '{name} bugün doluyor',
    'ja': '{name}は今日期限切れ',
  };

  static const Map<String, String> _docTomorrow = {
    'en': '{name} expires tomorrow', 'bg': '{name} изтича утре',
    'de': '{name} läuft morgen ab', 'fr': '{name} expire demain',
    'it': '{name} scade domani', 'el': '{name} λήγει αύριο',
    'es': '{name} caduca mañana', 'pt': '{name} expira amanhã',
    'ru': '{name} истекает завтра', 'tr': '{name} yarın doluyor',
    'ja': '{name}は明日期限切れ',
  };

  static const Map<String, String> _docInDays = {
    'en': '{name} expires in {days} days', 'bg': '{name} изтича след {days} дни',
    'de': '{name} läuft in {days} Tagen ab',
    'fr': '{name} expire dans {days} jours',
    'it': '{name} scade tra {days} giorni',
    'el': '{name} λήγει σε {days} ημέρες',
    'es': '{name} caduca en {days} días',
    'pt': '{name} expira em {days} dias',
    'ru': '{name} истекает через {days} дн.',
    'tr': '{name} {days} gün içinde doluyor',
    'ja': '{name}は{days}日後に期限切れ',
  };

  static const Map<String, String> _nameDayToday = {
    'en': 'Today {names} celebrate their name day',
    'bg': 'Днес имен ден празнуват {names}',
    'de': 'Heute haben {names} Namenstag',
    'fr': "Aujourd'hui {names} fêtent leur prénom",
    'it': "Oggi {names} festeggiano l'onomastico",
    'el': 'Σήμερα γιορτάζουν {names}',
    'es': 'Hoy celebran su santo {names}',
    'pt': 'Hoje {names} celebram o dia do nome',
    'ru': 'Сегодня именины у {names}',
    'tr': 'Bugün {names} isim gününü kutluyor',
    'ja': '今日は{names}の聖名祝日',
  };

  static const Map<String, String> _holidayToday = {
    'en': 'Today is {name}', 'bg': 'Днес е {name}', 'de': 'Heute ist {name}',
    'fr': "Aujourd'hui c'est {name}", 'it': 'Oggi è {name}',
    'el': 'Σήμερα είναι {name}', 'es': 'Hoy es {name}',
    'pt': 'Hoje é {name}', 'ru': 'Сегодня {name}', 'tr': 'Bugün {name}',
    'ja': '今日は{name}',
  };

  static const Map<String, String> _holidayTomorrow = {
    'en': 'Tomorrow is {name}', 'bg': 'Утре е {name}',
    'de': 'Morgen ist {name}', 'fr': "Demain c'est {name}",
    'it': 'Domani è {name}', 'el': 'Αύριο είναι {name}',
    'es': 'Mañana es {name}', 'pt': 'Amanhã é {name}',
    'ru': 'Завтра {name}', 'tr': 'Yarın {name}', 'ja': '明日は{name}',
  };

  static Future<void> _syncTasksToAppGroup() async {
    try {
      final taskBox = Hive.box<Task>('tasks');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final todayTasks = taskBox.values.where((t) {
        if (t.isCompleted) return false;
        final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
        // Като Android: днешни + ПРОСРОЧЕНИ (всичко до утре). Сортът слага
        // просрочените първи; Swift ги маркира червено.
        return d.isBefore(tomorrow);
      }).toList();
      todayTasks.sort((a, b) {
        final aOv = a.dueDate.isBefore(now), bOv = b.dueDate.isBefore(now);
        if (aOv && !bOv) return -1;
        if (!aOv && bOv) return 1;
        return b.priority.compareTo(a.priority);
      });
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_language') ?? 'en';
      final tasksJson = todayTasks.map((t) => {
        'key': t.key, 'title': t.title,
        'isCompleted': t.isCompleted, 'priority': t.priority,
        'dueDate': t.dueDate.toIso8601String(),
        if (t.template != null) 'template': t.template,
      }).toList();
      // Като Android: изпращаме и локалния контекст (документ/имен ден/празник).
      final ctx = await _computeWidgetContext(prefs);
      await _channel.invokeMethod('syncToAppGroup', {
        'tasks': jsonEncode(tasksJson),
        'language': lang,
        'context': jsonEncode(ctx),
      });
    } catch (e) {
      debugPrint('iOS widget sync error: $e');
    }
  }

  /// Взима (веднъж) чакащото действие от widget-а — засега само `new_task`
  /// (бутонът „+"). MainActivity го е прихванал от intent-а.
  static Future<String?> consumePendingAction() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('consumeWidgetAction');
    } catch (e) {
      debugPrint('Consume widget action error: $e');
      return null;
    }
  }

  static Future<void> requestPinWidget() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestPinWidget');
    } catch (e) {
      debugPrint('Request pin widget error: $e');
    }
  }

  static void setupWidgetListener() {
    if (!_isAndroid && !_isIOS) return;
    final taskBox = Hive.box<Task>('tasks');
    taskBox.watch().listen((_) {
      updateWidget();
    });
  }

  /// Прибира отметките, направени от widget-а, обратно в Hive.
  /// Android: чете `widget_tasks` от SharedPreferences (native пише там при чек).
  /// iOS: чете списък с ключове на завършени задачи от App Group (AppIntent-ът
  /// на widget-а ги пише там); native ги връща и ги изчиства.
  static Future<void> syncFromWidget() async {
    if (_isIOS) {
      await _syncFromWidgetIOS();
      return;
    }
    if (!_isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('widget_tasks');
      if (tasksJson == null) return;

      final taskBox = Hive.box<Task>('tasks');
      final List<dynamic> tasks = jsonDecode(tasksJson);

      for (final taskData in tasks) {
        final key = taskData['key'];
        final isCompleted = taskData['isCompleted'] ?? false;
        if (key != null && taskBox.containsKey(key)) {
          final task = taskBox.get(key);
          if (task != null && task.isCompleted != isCompleted) {
            task.isCompleted = isCompleted;
            if (isCompleted) task.completedAt = DateTime.now();
            await task.save();
          }
        }
      }
    } catch (e) {
      debugPrint('Sync from widget error: $e');
    }
  }

  static Future<void> _syncFromWidgetIOS() async {
    try {
      final keys = await _channel.invokeMethod<List<dynamic>>('getCompletedFromWidget');
      if (keys == null || keys.isEmpty) return;
      final taskBox = Hive.box<Task>('tasks');
      for (final k in keys) {
        final key = k is int ? k : int.tryParse('$k');
        if (key != null && taskBox.containsKey(key)) {
          final task = taskBox.get(key);
          if (task != null && !task.isCompleted) {
            task.isCompleted = true;
            task.completedAt = DateTime.now();
            await task.save();
          }
        }
      }
      // Прясно състояние → widget-ът показва актуалните задачи.
      await _syncTasksToAppGroup();
    } catch (e) {
      debugPrint('iOS sync from widget error: $e');
    }
  }
}
