import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/school_calendar.dart';
import 'package:task_manager/services/school_calendar_service.dart';

/// Тестова учебна година (ISO низове, като вградения asset). Ваканции с
/// различни класове + различен край на годината по клас.
SchoolYear _year() => SchoolYear.fromJson({
      'year': '2025/2026',
      'country': 'bg',
      'enabled': true,
      'official': false,
      'startOfYear': '2025-09-15',
      'vacations': [
        {'key': 'autumn', 'name': 'Есенна', 'start': '2025-10-31', 'end': '2025-11-03'},
        {'key': 'winter', 'name': 'Коледна', 'start': '2025-12-24', 'end': '2026-01-04'},
        {'key': 'spring', 'name': 'Пролетна', 'start': '2026-04-04', 'end': '2026-04-13', 'grades': '1-11'},
      ],
      'endOfYear': [
        {'grades': '1-3', 'date': '2026-05-29'},
        {'grades': '7-11', 'date': '2026-06-30'},
        {'grades': '12', 'date': '2026-05-15'},
      ],
      'exams': [
        {'key': 'nvo7_bel', 'name': 'НВО БЕЛ', 'date': '2026-06-10', 'grades': '7'},
        {'key': 'dzi_bel', 'name': 'ДЗИ БЕЛ', 'date': '2026-05-19', 'grades': '12'},
      ],
    });

void main() {
  group('gradeMatches', () {
    test('диапазон, единично, списък, „всички"', () {
      expect(gradeMatches(2, '1-3'), isTrue);
      expect(gradeMatches(4, '1-3'), isFalse);
      expect(gradeMatches(7, '7'), isTrue);
      expect(gradeMatches(12, '7,12'), isTrue);
      expect(gradeMatches(5, ''), isTrue); // празно = всички
      expect(gradeMatches(5, '1-12'), isTrue);
      expect(gradeMatches(11, '1-11'), isTrue);
      expect(gradeMatches(12, '1-11'), isFalse);
    });
  });

  group('SchoolCalendarService.yearKeyFor', () {
    test('септември+ → текущата година; преди септември → предходната', () {
      expect(SchoolCalendarService.yearKeyFor(DateTime(2026, 9, 15)),
          'bg_2026_2027');
      expect(SchoolCalendarService.yearKeyFor(DateTime(2026, 12, 20)),
          'bg_2026_2027');
      expect(SchoolCalendarService.yearKeyFor(DateTime(2026, 5, 1)),
          'bg_2025_2026');
      expect(SchoolCalendarService.yearKeyFor(DateTime(2026, 8, 31)),
          'bg_2025_2026');
    });
  });

  group('computeCountdown — граничнни случаи', () {
    final y = _year();

    test('няма данни → noData', () {
      final cd = computeCountdown(now: DateTime(2025, 12, 1), year: null, grade: 5);
      expect(cd.phase, SchoolPhase.noData);
    });

    test('обикновен ден → отброява до следваща ваканция', () {
      // 20 окт 2025, клас 5 → следваща е Есенната (31 окт).
      final cd = computeCountdown(now: DateTime(2025, 10, 20), year: y, grade: 5);
      expect(cd.phase, SchoolPhase.toVacation);
      expect(cd.vacationKey, 'autumn');
      expect(cd.days, 11);
    });

    test('ДНЕС е първи ден на ваканция → inVacation, не броене до нея', () {
      final cd = computeCountdown(now: DateTime(2025, 10, 31), year: y, grade: 5);
      expect(cd.phase, SchoolPhase.inVacation);
      expect(cd.vacationKey, 'autumn');
      expect(cd.days, 3); // 31 окт → 3 ноем = 3 дни почивка напред
    });

    test('последен ден на ваканция → inVacation, days=0', () {
      final cd = computeCountdown(now: DateTime(2025, 11, 3), year: y, grade: 5);
      expect(cd.phase, SchoolPhase.inVacation);
      expect(cd.days, 0);
    });

    test('последен учебен ден преди ваканция → toVacation, days=1', () {
      final cd = computeCountdown(now: DateTime(2025, 10, 30), year: y, grade: 5);
      expect(cd.phase, SchoolPhase.toVacation);
      expect(cd.days, 1);
    });

    test('преди началото на годината → beforeStart', () {
      final cd = computeCountdown(now: DateTime(2025, 9, 1), year: y, grade: 5);
      expect(cd.phase, SchoolPhase.beforeStart);
      expect(cd.days, 14);
    });

    test('след последната ваканция → отброява до лятото (край на година)', () {
      // 20 апр 2026, клас 8 → пролетната свърши (13 апр); край за 7-11 = 30 юни.
      final cd = computeCountdown(now: DateTime(2026, 4, 20), year: y, grade: 8);
      expect(cd.phase, SchoolPhase.toSummer);
      expect(cd.targetDate, DateTime(2026, 6, 30));
    });

    test('годината е свършила за класа → summerBreak', () {
      // Клас 2, край 29 май → на 1 юни вече е лято.
      final cd = computeCountdown(now: DateTime(2026, 6, 1), year: y, grade: 2);
      expect(cd.phase, SchoolPhase.summerBreak);
    });

    test('различен край по клас: 12. клас свършва по-рано (15 май)', () {
      // 20 май 2026: клас 12 вече е в лято; клас 8 още учи (край 30 юни).
      final cd12 = computeCountdown(now: DateTime(2026, 5, 20), year: y, grade: 12);
      expect(cd12.phase, SchoolPhase.summerBreak);
      final cd8 = computeCountdown(now: DateTime(2026, 5, 20), year: y, grade: 8);
      expect(cd8.phase, SchoolPhase.toSummer);
    });

    test('пролетната ваканция важи за 1-11, но НЕ за 12', () {
      // 6 апр 2026: клас 5 е във ваканция; клас 12 — не (за него няма spring).
      final cd5 = computeCountdown(now: DateTime(2026, 4, 6), year: y, grade: 5);
      expect(cd5.phase, SchoolPhase.inVacation);
      final cd12 = computeCountdown(now: DateTime(2026, 4, 6), year: y, grade: 12);
      expect(cd12.phase, isNot(SchoolPhase.inVacation));
    });
  });

  group('upcomingExamsFor', () {
    final y = _year();
    test('връща само изпитите за класа, сортирани, само предстоящи', () {
      final e7 = y.upcomingExamsFor(7, DateTime(2026, 1, 1));
      expect(e7.length, 1);
      expect(e7.first.key, 'nvo7_bel');

      final e12 = y.upcomingExamsFor(12, DateTime(2026, 1, 1));
      expect(e12.length, 1);
      expect(e12.first.key, 'dzi_bel');

      // След датата на изпита → празно.
      final after = y.upcomingExamsFor(12, DateTime(2026, 6, 1));
      expect(after, isEmpty);
    });
  });

  group('parseSchoolDate', () {
    test('ISO низ и millis', () {
      expect(parseSchoolDate('2026-04-04'), DateTime(2026, 4, 4));
      expect(parseSchoolDate(''), isNull);
      expect(parseSchoolDate(null), isNull);
      final ms = DateTime(2026, 4, 4, 13, 30).millisecondsSinceEpoch;
      expect(parseSchoolDate(ms), DateTime(2026, 4, 4)); // час се отрязва
    });
  });
}
