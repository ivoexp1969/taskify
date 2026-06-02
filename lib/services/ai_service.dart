import 'dart:convert';
import 'package:http/http.dart' as http;

class AiParseResult {
  final String title;
  final int priority;
  final String? categoryName;
  final String? recurring;
  final String? time; // "HH:MM" — fallback when NLP misses time

  const AiParseResult({
    required this.title,
    required this.priority,
    this.categoryName,
    this.recurring,
    this.time,
  });
}

class AiBreakdownResult {
  final List<String> subtasks;
  const AiBreakdownResult({required this.subtasks});
}

class AiService {
  static const _endpoint = 'https://taskify-ai.cbndkbr92h.workers.dev';

  static Future<AiParseResult?> parseTask(
    String text,
    List<String> categories, {
    String? lang,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'mode': 'parse',
              'categories': categories,
              'lang': lang,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      return _parseParse(response.body, text);
    } catch (_) {
      return null;
    }
  }

  static Future<AiBreakdownResult?> breakdownTask(
    String taskTitle, [
    List<String> categories = const [],
    String? lang,
  ]) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': taskTitle,
              'mode': 'breakdown',
              'categories': categories,
              'lang': lang,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;
      return _parseBreakdown(response.body);
    } catch (_) {
      return null;
    }
  }

  static AiParseResult? _parseParse(String body, String originalText) {
    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(body);
      if (match == null) return null;
      final data = jsonDecode(match.group(0)!) as Map<String, dynamic>;

      int priority = 1;
      final p = (data['priority'] as String?)?.toLowerCase();
      if (p == 'low') {
        priority = 0;
      } else if (p == 'high') {
        priority = 2;
      }

      String? recurring;
      final r = (data['recurring'] as String?)?.toLowerCase();
      if (r != null && r != 'none') recurring = r;

      // Recurring keyword fallback — catches patterns the model may miss
      if (recurring == null) {
        recurring = _detectRecurring(originalText.toLowerCase());
      }

      // Accept AI time only if it looks like "HH:MM"
      final rawTime = data['time'] as String?;
      final aiTime = (rawTime != null && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(rawTime))
          ? rawTime
          : null;

      return AiParseResult(
        title: (data['title'] as String?) ?? originalText,
        priority: priority,
        categoryName: data['category'] as String?,
        recurring: recurring,
        time: aiTime,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _detectRecurring(String lower) {
    if (RegExp(r'всеки ден|всяка ден|ежедневно|every day|daily|täglich|diario|giornaliero|quotidien|günlük|ежедневно|καθημερινά').hasMatch(lower)) {
      return 'daily';
    }
    if (RegExp(r'всяка седмица|всяка седм|weekly|wöchentlich|semanal|settimanale|hebdomadaire|haftalık|еженедельно|εβδομαδιαία').hasMatch(lower)) {
      return 'weekly';
    }
    if (RegExp(r'всеки месец|всяка месец|monthly|monatlich|mensual|mensile|mensuel|aylık|ежемесячно|μηνιαία').hasMatch(lower)) {
      return 'monthly';
    }
    if (RegExp(r'всяка година|ежегодно|yearly|annually|jährlich|anual|annuale|annuel|yıllık|ετήσια').hasMatch(lower)) {
      return 'yearly';
    }
    return null;
  }

  static AiBreakdownResult? _parseBreakdown(String body) {
    try {
      // Strip markdown code fences (```json ... ```), if present
      var cleaned = body.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '');

      // Extract the JSON object spanning the first '{' to the last '}'
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match == null) return null;
      final data = jsonDecode(match.group(0)!) as Map<String, dynamic>;

      final raw = data['subtasks'];
      if (raw is! List) return null;

      // Llama may return either ["A","B"] or [{"title":"A"},{"title":"B"}]
      final subtasks = raw
          .map((s) {
            if (s is String) return s.trim();
            if (s is Map) return ((s['title'] ?? s['text']) as String?)?.trim() ?? '';
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();

      if (subtasks.isEmpty) return null;
      return AiBreakdownResult(subtasks: subtasks);
    } catch (_) {
      return null;
    }
  }
}
