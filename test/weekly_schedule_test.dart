import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/weekly_schedule.dart';

ScheduleSlot slot({
  String id = 's',
  int day = 1,
  required int from,
  required int to,
  String subject = 'Мат',
  int term = 1,
  WeekPattern weekPattern = WeekPattern.every,
}) =>
    ScheduleSlot(
      id: id,
      day: day,
      fromMinutes: from,
      toMinutes: to,
      subject: subject,
      kind: SlotKind.lesson,
      term: term,
      weekPattern: weekPattern,
    );

void main() {
  group('hasValidRange', () {
    test('край след начало = валиден', () {
      expect(slot(from: 480, to: 525).hasValidRange, isTrue);
    });
    test('край == начало = невалиден', () {
      expect(slot(from: 480, to: 480).hasValidRange, isFalse);
    });
    test('край преди начало = невалиден', () {
      expect(slot(from: 525, to: 480).hasValidRange, isFalse);
    });
  });

  group('overlaps', () {
    test('различен ден → няма припокриване', () {
      final a = slot(id: 'a', day: 1, from: 480, to: 540);
      final b = slot(id: 'b', day: 2, from: 480, to: 540);
      expect(a.overlaps(b), isFalse);
    });

    test('долепени (край==начало) → НЕ се смятат за припокриване', () {
      final a = slot(id: 'a', from: 480, to: 540); // 08:00–09:00
      final b = slot(id: 'b', from: 540, to: 600); // 09:00–10:00
      expect(a.overlaps(b), isFalse);
      expect(b.overlaps(a), isFalse);
    });

    test('частично застъпване → припокриване', () {
      final a = slot(id: 'a', from: 480, to: 540); // 08:00–09:00
      final b = slot(id: 'b', from: 510, to: 570); // 08:30–09:30
      expect(a.overlaps(b), isTrue);
      expect(b.overlaps(a), isTrue);
    });

    test('един вътре в друг → припокриване', () {
      final a = slot(id: 'a', from: 480, to: 600); // 08:00–10:00
      final b = slot(id: 'b', from: 510, to: 540); // 08:30–09:00
      expect(a.overlaps(b), isTrue);
      expect(b.overlaps(a), isTrue);
    });

    test('идентичен интервал → припокриване', () {
      final a = slot(id: 'a', from: 480, to: 540);
      final b = slot(id: 'b', from: 480, to: 540);
      expect(a.overlaps(b), isTrue);
    });

    test('различен срок → НЕ се припокриват (дори същ час)', () {
      final a = slot(id: 'a', from: 480, to: 540, term: 1);
      final b = slot(id: 'b', from: 480, to: 540, term: 2);
      expect(a.overlaps(b), isFalse);
    });
  });

  group('term сериализация', () {
    test('fromJson без term → срок 1 (обратна съвместимост)', () {
      final s = ScheduleSlot.fromJson({
        'id': 'x', 'day': 1, 'from': 480, 'to': 540, 'subject': 'Х', 'kind': 'lesson',
      });
      expect(s!.term, 1);
    });
    test('term round-trip през JSON', () {
      final s = slot(from: 480, to: 540, term: 2);
      final back = ScheduleSlot.fromJson(s.toJson());
      expect(back!.term, 2);
    });
  });

  group('currentWeekNumber', () {
    final start = DateTime(2026, 10, 6); // понеделник, начало на семестъра

    test('semesterStart == null → 0 (без филтър)', () {
      expect(currentWeekNumber(null, DateTime(2026, 10, 20)), 0);
    });
    test('преди семестъра → 0', () {
      expect(currentWeekNumber(start, DateTime(2026, 10, 5)), 0);
    });
    test('точно първият ден → седмица 1 (нечетна)', () {
      final w = currentWeekNumber(start, DateTime(2026, 10, 6));
      expect(w, 1);
      expect(w % 2 == 1, isTrue);
    });
    test('шести ден (същата седмица) → 1', () {
      expect(currentWeekNumber(start, DateTime(2026, 10, 11)), 1);
    });
    test('седмият ден → седмица 2 (четна)', () {
      final w = currentWeekNumber(start, DateTime(2026, 10, 13));
      expect(w, 2);
      expect(w % 2 == 0, isTrue);
    });
    test('трета седмица → 3 (нечетна)', () {
      expect(currentWeekNumber(start, DateTime(2026, 10, 20)), 3);
    });
    test('устойчиво на смяна на часово време (края на октомври)', () {
      // DST в България: последната неделя на октомври 2026 (25.10) часовникът
      // се връща назад. 4 седмици по-късно трябва да е седмица 5, не 4.
      expect(currentWeekNumber(start, DateTime(2026, 11, 3)), 5);
    });
  });

  group('matchesWeek', () {
    test('every → винаги видим', () {
      final s = slot(from: 480, to: 540, weekPattern: WeekPattern.every);
      expect(s.matchesWeek(1), isTrue);
      expect(s.matchesWeek(2), isTrue);
      expect(s.matchesWeek(0), isTrue);
    });
    test('oddOnly → само нечетни седмици', () {
      final s = slot(from: 480, to: 540, weekPattern: WeekPattern.oddOnly);
      expect(s.matchesWeek(1), isTrue);
      expect(s.matchesWeek(3), isTrue);
      expect(s.matchesWeek(2), isFalse);
      expect(s.matchesWeek(4), isFalse);
    });
    test('evenOnly → само четни седмици', () {
      final s = slot(from: 480, to: 540, weekPattern: WeekPattern.evenOnly);
      expect(s.matchesWeek(2), isTrue);
      expect(s.matchesWeek(4), isTrue);
      expect(s.matchesWeek(1), isFalse);
      expect(s.matchesWeek(3), isFalse);
    });
    test('weekNumber<=0 (неизвестно начало) → показва всичко', () {
      final s = slot(from: 480, to: 540, weekPattern: WeekPattern.oddOnly);
      expect(s.matchesWeek(0), isTrue);
    });
  });

  group('overlaps + weekPattern', () {
    test('четна + нечетна в същия час → НЕ се припокриват', () {
      final a = slot(id: 'a', from: 480, to: 540, weekPattern: WeekPattern.evenOnly);
      final b = slot(id: 'b', from: 480, to: 540, weekPattern: WeekPattern.oddOnly);
      expect(a.overlaps(b), isFalse);
      expect(b.overlaps(a), isFalse);
    });
    test('четна + четна в същия час → припокриват се', () {
      final a = slot(id: 'a', from: 480, to: 540, weekPattern: WeekPattern.evenOnly);
      final b = slot(id: 'b', from: 480, to: 540, weekPattern: WeekPattern.evenOnly);
      expect(a.overlaps(b), isTrue);
    });
    test('every + нечетна в същия час → припокриват се', () {
      final a = slot(id: 'a', from: 480, to: 540, weekPattern: WeekPattern.every);
      final b = slot(id: 'b', from: 480, to: 540, weekPattern: WeekPattern.oddOnly);
      expect(a.overlaps(b), isTrue);
    });
  });

  group('weekPattern + color сериализация', () {
    test('fromJson без week → every (обратна съвместимост)', () {
      final s = ScheduleSlot.fromJson({
        'id': 'x', 'day': 1, 'from': 480, 'to': 540, 'subject': 'Х', 'kind': 'lesson',
      });
      expect(s!.weekPattern, WeekPattern.every);
      expect(s.colorValue, isNull);
    });
    test('weekPattern round-trip през JSON', () {
      final s = slot(from: 480, to: 540, weekPattern: WeekPattern.evenOnly);
      final back = ScheduleSlot.fromJson(s.toJson());
      expect(back!.weekPattern, WeekPattern.evenOnly);
    });
    test('color round-trip през JSON', () {
      final s = slot(from: 480, to: 540).copyWith(colorValue: 0xFF2196F3);
      final back = ScheduleSlot.fromJson(s.toJson());
      expect(back!.colorValue, 0xFF2196F3);
    });
    test('copyWith clearColor → null', () {
      final s = slot(from: 480, to: 540).copyWith(colorValue: 0xFF2196F3);
      expect(s.copyWith(clearColor: true).colorValue, isNull);
    });
  });
}
