/// Чиста логика за автоматичното разбиване на учебни задачи (Есе / Курсова).
///
/// Шаблоните живеят в `assets/data/task_templates.json` (за лесна редакция).
/// Тук няма зависимост от Flutter → напълно тествамо. Зареждането на asset-а е
/// в [TaskTemplateService].
library;

/// Една стъпка от шаблон: колко дни преди срока (при средна сложност) + име.
class TaskTemplateStep {
  final int daysBefore;
  final Map<String, String> title; // локализирани заглавия

  const TaskTemplateStep({required this.daysBefore, required this.title});

  static TaskTemplateStep? fromJson(Map<String, dynamic> j) {
    final raw = j['daysBefore'];
    final days = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (days == null) return null;
    final t = j['title'];
    if (t is! Map) return null;
    return TaskTemplateStep(
      daysBefore: days,
      title: t.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }

  String localizedTitle(String lang) => title[lang] ?? title['en'] ?? '';
}

/// Планирана подзадача: заглавие (локализирано) + препоръчителна дата.
class PlannedSubtask {
  final Map<String, String> title;
  final DateTime date;
  const PlannedSubtask({required this.title, required this.date});

  String localizedTitle(String lang) => title[lang] ?? title['en'] ?? '';
}

/// Множители по сложност (1 = лесно/по-кратко, 2 = средно, 3 = сложно/по-дълго).
const Map<int, double> kComplexityMultipliers = {1: 0.6, 2: 1.0, 3: 1.4};

/// ★ЯДРО★ — построява подзадачите от шаблон [steps] за краен срок [dueDate],
/// сложност [complexity] (1–3) спрямо [today].
///
/// Логика:
/// 1. Ефективните отстояния = daysBefore × множител(сложност).
/// 2. Ако най-голямото отстояние надхвърля наличните дни (кратък срок) →
///    компресираме ПРОПОРЦИОНАЛНО, за да се поберат, без да пропускаме стъпка.
/// 3. Датата на всяка стъпка = dueDate − (компресирано отстояние).
///
/// Гарантира: върнатите подзадачи са със същия брой и ред като [steps]; всяка
/// дата е в интервала [today, dueDate]; стъпката „в деня на срока" (daysBefore=0)
/// винаги пада на dueDate.
List<PlannedSubtask> planSubtasks({
  required List<TaskTemplateStep> steps,
  required DateTime dueDate,
  required DateTime today,
  int complexity = 2,
}) {
  if (steps.isEmpty) return const [];

  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final t0 = DateTime(today.year, today.month, today.day);
  final available = due.difference(t0).inDays; // може да е 0 или отрицателно

  final mult = kComplexityMultipliers[complexity] ?? 1.0;

  // Ефективни отстояния (закръглени, неотрицателни).
  final effective =
      steps.map((s) => (s.daysBefore * mult).round().clamp(0, 100000)).toList();

  final maxLead = effective.reduce((a, b) => a > b ? a : b);

  // Компресия: ако няма достатъчно дни, свиваме пропорционално.
  double scale = 1.0;
  if (available <= 0) {
    scale = 0.0; // всичко пада на срока (или днес, ако срокът е минал/днес)
  } else if (maxLead > available) {
    scale = available / maxLead;
  }

  final out = <PlannedSubtask>[];
  for (int i = 0; i < steps.length; i++) {
    int lead = (effective[i] * scale).round();
    if (lead < 0) lead = 0;
    if (lead > available && available > 0) lead = available;
    // Дата = срок − отстояние; при минал срок фиксираме на срока.
    final date = due.subtract(Duration(days: lead));
    out.add(PlannedSubtask(title: steps[i].title, date: date));
  }
  return out;
}
