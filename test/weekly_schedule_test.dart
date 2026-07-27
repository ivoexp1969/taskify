import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/weekly_schedule.dart';

ScheduleSlot slot({
  String id = 's',
  int day = 1,
  required int from,
  required int to,
  String subject = 'Мат',
  int term = 1,
}) =>
    ScheduleSlot(
      id: id,
      day: day,
      fromMinutes: from,
      toMinutes: to,
      subject: subject,
      kind: SlotKind.lesson,
      term: term,
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
}
