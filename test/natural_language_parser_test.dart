import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/utils/natural_language_parser.dart';

/// Днешната дата за сравнения (без час).
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Очакваната дата за „ден/месец" — тази година, или следващата ако е минала.
DateTime _nextDateOf(int day, int month) {
  final today = _today();
  var d = DateTime(today.year, month, day);
  if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
  return d;
}

void main() {
  group('Абсолютни дати — българският набор на Иво', () {
    test('„12 декември" → 12 декември (без час)', () {
      final r = NaturalLanguageParser.parse('Пътуване до Лондон на 12 декември', 'bg');
      expect(r, isNotNull);
      expect(r!.date, _nextDateOf(12, 12));
      expect(r.time, isNull);
    });

    test('„12 декември в 17ч" → 12 декември 17:00 (бившият бъг)', () {
      final r = NaturalLanguageParser.parse('Полет до Лондон на 12 декември в 17ч', 'bg');
      expect(r, isNotNull);
      expect(r!.date, _nextDateOf(12, 12));
      expect(r.time, const TimeOfDay(hour: 17, minute: 0));
    });

    test('„12 дек" (съкратено) → 12 декември', () {
      final r = NaturalLanguageParser.parse('12 дек', 'bg');
      expect(r?.date, _nextDateOf(12, 12));
    });

    test('„12 дек." (с точка) → 12 декември', () {
      final r = NaturalLanguageParser.parse('среща 12 дек.', 'bg');
      expect(r?.date, _nextDateOf(12, 12));
    });

    test('„на 3 януари в 9" → 3 януари 09:00', () {
      final r = NaturalLanguageParser.parse('на 3 януари в 9', 'bg');
      expect(r?.date, _nextDateOf(3, 1));
      expect(r?.time, const TimeOfDay(hour: 9, minute: 0));
    });

    test('„12.12" → 12 декември', () {
      final r = NaturalLanguageParser.parse('плати 12.12', 'bg');
      expect(r?.date, _nextDateOf(12, 12));
    });

    test('„12.12.2027" → изричен год.', () {
      final r = NaturalLanguageParser.parse('плати 12.12.2027', 'bg');
      expect(r?.date, DateTime(2027, 12, 12));
    });

    test('„следващия петък" → петък', () {
      final r = NaturalLanguageParser.parse('следващия петък', 'bg');
      expect(r, isNotNull);
      expect(r!.date.weekday, DateTime.friday);
      expect(r.date.isAfter(_today()), isTrue);
    });

    test('„след 2 дни" → днес + 2', () {
      final r = NaturalLanguageParser.parse('обади се след 2 дни', 'bg');
      expect(r?.date, _today().add(const Duration(days: 2)));
    });

    test('„след 3 седмици" → днес + 21', () {
      final r = NaturalLanguageParser.parse('ваканция след 3 седмици', 'bg');
      expect(r?.date, _today().add(const Duration(days: 21)));
    });
  });

  group('Английски набор', () {
    test('„Dec 12 at 5pm" → 12 декември 17:00', () {
      final r = NaturalLanguageParser.parse('Flight to London Dec 12 at 5pm', 'en');
      expect(r?.date, _nextDateOf(12, 12));
      expect(r?.time, const TimeOfDay(hour: 17, minute: 0));
    });

    test('„December 12" (пълно) → 12 декември', () {
      final r = NaturalLanguageParser.parse('December 12', 'en');
      expect(r?.date, _nextDateOf(12, 12));
    });

    test('„in 2 days" → днес + 2', () {
      final r = NaturalLanguageParser.parse('call back in 2 days', 'en');
      expect(r?.date, _today().add(const Duration(days: 2)));
    });

    test('„3 January" → 3 януари', () {
      final r = NaturalLanguageParser.parse('meeting 3 January', 'en');
      expect(r?.date, _nextDateOf(3, 1));
    });
  });

  group('Регресия — вече работещите', () {
    test('„утре в 17" → утре 17:00', () {
      final r = NaturalLanguageParser.parse('утре в 17', 'bg');
      expect(r?.date, _today().add(const Duration(days: 1)));
      expect(r?.time, const TimeOfDay(hour: 17, minute: 0));
    });

    test('„в петък в 17ч" → петък 17:00', () {
      final r = NaturalLanguageParser.parse('в петък в 17ч', 'bg');
      expect(r, isNotNull);
      expect(r!.date.weekday, DateTime.friday);
      expect(r.time, const TimeOfDay(hour: 17, minute: 0));
    });

    test('„днес" → днес', () {
      final r = NaturalLanguageParser.parse('пазар днес', 'bg');
      expect(r?.date, _today());
    });

    test('само час „15:30" → днес 15:30', () {
      final r = NaturalLanguageParser.parse('обяд 15:30', 'bg');
      expect(r?.date, _today());
      expect(r?.time, const TimeOfDay(hour: 15, minute: 30));
    });
  });

  group('Отрицателни — числа, които НЕ са дати', () {
    test('„Плати 10.05 лв за паркинг" → null (валута)', () {
      expect(NaturalLanguageParser.parse('Плати 10.05 лв за паркинг', 'bg'), isNull);
    });
    test('„Купи 2.5 кг ябълки" → null (мярка)', () {
      expect(NaturalLanguageParser.parse('Купи 2.5 кг ябълки', 'bg'), isNull);
    });
    test('„Резултат 3-1" → null (тире не е дата)', () {
      expect(NaturalLanguageParser.parse('Резултат 3-1', 'bg'), isNull);
    });
    test('„Версия 1.0.70" → null (версия)', () {
      expect(NaturalLanguageParser.parse('Версия 1.0.70', 'bg'), isNull);
    });
    test('„Телефон 0888 123 456" → null', () {
      expect(NaturalLanguageParser.parse('Телефон 0888 123 456', 'bg'), isNull);
    });
    test('„Отстъпка 20%" → null', () {
      expect(NaturalLanguageParser.parse('Отстъпка 20%', 'bg'), isNull);
    });
    test('„в 9 клас" → null (не е час в края)', () {
      expect(NaturalLanguageParser.parse('запиши в 9 клас', 'bg'), isNull);
    });

    // „Стая 12.12" — по правилото (числова дата, щом няма валута/мярка/% наблизо)
    // ТОВА се тълкува като дата. Документирано компромисно поведение.
    test('„Стая 12.12" → дата (интенционално, виж доклада)', () {
      expect(NaturalLanguageParser.parse('Стая 12.12', 'bg'), isNotNull);
    });
  });

  group('Позитивни с предлог (проверка след стесняването)', () {
    test('„на 12.12" → 12 декември', () {
      expect(NaturalLanguageParser.parse('плати на 12.12', 'bg')?.date, _nextDateOf(12, 12));
    });
    test('„на 3 януари в 9" (час в края) → 3 ян 09:00', () {
      final r = NaturalLanguageParser.parse('на 3 януари в 9', 'bg');
      expect(r?.date, _nextDateOf(3, 1));
      expect(r?.time, const TimeOfDay(hour: 9, minute: 0));
    });
  });

  group('Без дата → null (case 3: пазаруване не бива да става „утре")', () {
    test('„Да купя хляб, мляко и яйца" → null', () {
      final r = NaturalLanguageParser.parse('Да купя хляб, мляко и яйца', 'bg');
      expect(r, isNull);
    });

    test('обикновен текст без дата/час → null', () {
      final r = NaturalLanguageParser.parse('обади се на мама', 'bg');
      expect(r, isNull);
    });
  });
}
