import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/task_templates.dart';

/// Зарежда шаблоните за автоматично разбиване от
/// `assets/data/task_templates.json` (веднъж, кешира). Чист asset → офлайн.
class TaskTemplateService {
  TaskTemplateService._internal();
  static final TaskTemplateService _instance = TaskTemplateService._internal();
  factory TaskTemplateService() => _instance;

  static const String _assetPath = 'assets/data/task_templates.json';

  final Map<String, List<TaskTemplateStep>> _templates = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = json.decode(raw);
      if (data is Map && data['templates'] is Map) {
        (data['templates'] as Map).forEach((kind, value) {
          if (value is Map && value['steps'] is List) {
            final steps = <TaskTemplateStep>[];
            for (final s in value['steps']) {
              if (s is Map) {
                final step =
                    TaskTemplateStep.fromJson(Map<String, dynamic>.from(s));
                if (step != null) steps.add(step);
              }
            }
            if (steps.isNotEmpty) _templates[kind.toString()] = steps;
          }
        });
      }
    } catch (e) {
      debugPrint('TaskTemplateService: load failed → $e');
    }
    _loaded = true;
  }

  /// Стъпките за учебен вид ('essay' | 'coursework') или празен списък
  /// ('homework'/'regular' нямат авто-разбиване).
  List<TaskTemplateStep> stepsFor(String kind) => _templates[kind] ?? const [];

  bool get isLoaded => _loaded;
}
