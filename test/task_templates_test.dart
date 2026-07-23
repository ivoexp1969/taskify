import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/task_templates.dart';
import 'package:task_manager/models/school_calendar.dart';

/// Шаблон „есе" (5 стъпки) като в task_templates.json.
List<TaskTemplateStep> _essaySteps() => [
      const TaskTemplateStep(daysBefore: 7, title: {'en': 'Pick topic', 'bg': 'Тема'}),
      const TaskTemplateStep(daysBefore: 5, title: {'en': 'Outline', 'bg': 'План'}),
      const TaskTemplateStep(daysBefore: 3, title: {'en': 'Draft', 'bg': 'Чернова'}),
      const TaskTemplateStep(daysBefore: 1, title: {'en': 'Revise', 'bg': 'Редакция'}),
      const TaskTemplateStep(daysBefore: 0, title: {'en': 'Submit', 'bg': 'Предаване'}),
    ];

void main() {
  group('planSubtasks — нормален срок', () {
    test('всяка стъпка пада на срок − daysBefore при сложност 2', () {
      final today = DateTime(2026, 3, 1);
      final due = DateTime(2026, 3, 15); // 14 дни напред → има място
      final out = planSubtasks(
          steps: _essaySteps(), dueDate: due, today: today, complexity: 2);

      expect(out.length, 5);
      // daysBefore [7,5,3,1,0] → дати спрямо срока.
      expect(daysBetween(out[0].date, due), 7);
      expect(daysBetween(out[1].date, due), 5);
      expect(daysBetween(out[2].date, due), 3);
      expect(daysBetween(out[3].date, due), 1);
      expect(daysBetween(out[4].date, due), 0); // „в деня на срока"
      // Последната стъпка е точно на срока.
      expect(out.last.date, DateTime(2026, 3, 15));
    });
  });

  group('planSubtasks — кратък срок (компресия)', () {
    test('есе за 2 дни: 5 стъпки, нито една пропусната, всички в интервала', () {
      final today = DateTime(2026, 3, 1);
      final due = DateTime(2026, 3, 3); // само 2 дни налични
      final out = planSubtasks(
          steps: _essaySteps(), dueDate: due, today: today, complexity: 2);

      expect(out.length, 5, reason: 'нито една стъпка не се пропуска');
      for (final p in out) {
        // Всяка дата е в [today, due].
        expect(p.date.isBefore(today), isFalse);
        expect(p.date.isAfter(due), isFalse);
      }
      // Редът е запазен (не намаляваща дата).
      for (var i = 1; i < out.length; i++) {
        expect(out[i].date.isBefore(out[i - 1].date), isFalse);
      }
      // Стъпката „в деня на срока" остава на срока.
      expect(out.last.date, DateTime(2026, 3, 3));
    });

    test('срок днес (0 налични дни) → всички падат на срока', () {
      final today = DateTime(2026, 3, 10);
      final due = DateTime(2026, 3, 10);
      final out = planSubtasks(
          steps: _essaySteps(), dueDate: due, today: today, complexity: 2);
      expect(out.length, 5);
      for (final p in out) {
        expect(p.date, DateTime(2026, 3, 10));
      }
    });
  });

  group('planSubtasks — сложност', () {
    test('сложност 3 удължава отстоянията спрямо сложност 1', () {
      final today = DateTime(2026, 1, 1);
      final due = DateTime(2026, 6, 1); // много място → без компресия
      final easy = planSubtasks(
          steps: _essaySteps(), dueDate: due, today: today, complexity: 1);
      final hard = planSubtasks(
          steps: _essaySteps(), dueDate: due, today: today, complexity: 3);
      // Първата стъпка (daysBefore=7): сложност 1 → 4 дни, сложност 3 → 10 дни.
      expect(daysBetween(easy[0].date, due), 4);
      expect(daysBetween(hard[0].date, due), 10);
    });
  });

  group('planSubtasks — гранични', () {
    test('празни стъпки → празен резултат', () {
      final out = planSubtasks(
          steps: const [],
          dueDate: DateTime(2026, 5, 1),
          today: DateTime(2026, 4, 1));
      expect(out, isEmpty);
    });
  });

  group('SchoolExam.enabled', () {
    test('enabled:false → изпитът се пропуска (fromJson връща null)', () {
      final disabled = SchoolExam.fromJson({
        'key': 'nvo4_bel',
        'name': 'НВО БЕЛ',
        'date': '2026-05-27',
        'grades': '4',
        'enabled': false,
      });
      expect(disabled, isNull);
    });

    test('липсващ enabled → изпитът важи (по подразбиране активен)', () {
      final e = SchoolExam.fromJson({
        'key': 'nvo4_bel',
        'name': 'НВО БЕЛ',
        'date': '2026-05-27',
        'grades': '4',
        'subject': 'БЕЛ',
      });
      expect(e, isNotNull);
      expect(e!.subject, 'БЕЛ');
      expect(e.mandatory, isTrue);
    });
  });
}
