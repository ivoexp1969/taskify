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

/// Следващото срещане на даден ден от седмицата (винаги СЛЕД днес, като парсера).
DateTime _nextWeekday(int weekday) {
  final today = _today();
  var ahead = weekday - today.weekday;
  if (ahead <= 0) ahead += 7;
  return today.add(Duration(days: ahead));
}

/// Black Friday = петъкът след 4-ия четвъртък на ноември; ако е минал → догодина.
DateTime _blackFridayOf(int year) {
  var d = DateTime(year, 11, 1);
  var thursdays = 0;
  while (true) {
    if (d.weekday == DateTime.thursday) {
      thursdays++;
      if (thursdays == 4) break;
    }
    d = d.add(const Duration(days: 1));
  }
  return d.add(const Duration(days: 1));
}

DateTime _blackFriday() {
  final today = _today();
  var d = _blackFridayOf(today.year);
  if (d.isBefore(today)) d = _blackFridayOf(today.year + 1);
  return d;
}

DateTime _cyberMonday() {
  final today = _today();
  var d = _blackFridayOf(today.year).add(const Duration(days: 3));
  if (d.isBefore(today)) {
    d = _blackFridayOf(today.year + 1).add(const Duration(days: 3));
  }
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

    test('само час „15:30" (сега 08:00) → днес 15:30', () {
      final r = NaturalLanguageParser.parse('обяд 15:30', 'bg',
          now: DateTime(2026, 6, 10, 8, 0));
      expect(r?.date, DateTime(2026, 6, 10));
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

  group('Приоритет: изрична дата > ден от седмицата (bug fix 1.0.73)', () {
    test('„Black Friday on 27.11 at 9 am" → 27.11 09:00 (изрична дата печели)', () {
      final r = NaturalLanguageParser.parse('Black Friday on 27.11 at 9 am', 'en');
      expect(r, isNotNull);
      expect(r!.date, _nextDateOf(27, 11));
      expect(r.time, const TimeOfDay(hour: 9, minute: 0));
    });

    test('„намаление в петък на 20.11" → 20.11 (дата бие деня)', () {
      final r = NaturalLanguageParser.parse('намаление в петък на 20.11', 'bg');
      expect(r?.date, _nextDateOf(20, 11));
    });
  });

  group('Именувани събития (Black Friday / Cyber Monday)', () {
    test('„Black Friday" → петъкът след 4-ия четвъртък на ноември', () {
      final r = NaturalLanguageParser.parse('Black Friday', 'en');
      expect(r, isNotNull);
      expect(r!.date, _blackFriday());
      expect(r.date.weekday, DateTime.friday);
    });

    test('„Черен петък намаления" → Black Friday дата (не следващия петък)', () {
      final r = NaturalLanguageParser.parse('Черен петък намаления', 'bg');
      expect(r?.date, _blackFriday());
    });

    test('„Black Friday в петък в 9 часа" → ИЗРИЧНИЯТ петък 09:00 (денят бие събитието)', () {
      final r = NaturalLanguageParser.parse('Black Friday в петък в 9 часа', 'bg');
      expect(r, isNotNull);
      expect(r!.date, _nextWeekday(DateTime.friday));
      expect(r.date.weekday, DateTime.friday);
      expect(r.time, const TimeOfDay(hour: 9, minute: 0));
    });

    test('„Cyber Monday" → понеделникът след Black Friday', () {
      final r = NaturalLanguageParser.parse('Cyber Monday deals', 'en');
      expect(r?.date, _cyberMonday());
      expect(r?.date.weekday, DateTime.monday);
    });

    test('„Кибер понеделник" → Cyber Monday дата', () {
      final r = NaturalLanguageParser.parse('Кибер понеделник', 'bg');
      expect(r?.date, _cyberMonday());
    });

    test('„Meeting Friday" → следващия петък (старото поведение не се чупи)', () {
      final r = NaturalLanguageParser.parse('Meeting Friday', 'en');
      expect(r?.date, _nextWeekday(DateTime.friday));
    });
  });

  group('Гол час без am/pm → първо предстоящо 07:00/19:00 (1.0.73 r2, фикс. „сега")', () {
    test('сега 18:45 + „7 o\'clock" → днес 19:00', () {
      final r = NaturalLanguageParser.parse("Call mom at 7 o'clock", 'en',
          now: DateTime(2026, 6, 10, 18, 45));
      expect(r, isNotNull);
      expect(r!.date, DateTime(2026, 6, 10));
      expect(r.time, const TimeOfDay(hour: 19, minute: 0));
    });

    test('сега 05:00 + „at 7" → днес 07:00', () {
      final r = NaturalLanguageParser.parse('wake me at 7', 'en',
          now: DateTime(2026, 6, 10, 5, 0));
      expect(r!.date, DateTime(2026, 6, 10));
      expect(r.time, const TimeOfDay(hour: 7, minute: 0));
    });

    test('сега 20:00 + „at 7" → утре 07:00 (и двата часа минали днес)', () {
      final r = NaturalLanguageParser.parse('call at 7', 'en',
          now: DateTime(2026, 6, 10, 20, 0));
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 7, minute: 0));
    });

    test('сега 06:00 + „at 9" → днес 09:00', () {
      final r = NaturalLanguageParser.parse('call back at 9', 'en',
          now: DateTime(2026, 6, 10, 6, 0));
      expect(r!.date, DateTime(2026, 6, 10));
      expect(r.time, const TimeOfDay(hour: 9, minute: 0));
    });

    test('„at 9 am" точно 09:00; сега 20:00 → утре (никога минало)', () {
      final r = NaturalLanguageParser.parse('meeting at 9 am', 'en',
          now: DateTime(2026, 6, 10, 20, 0));
      expect(r?.time, const TimeOfDay(hour: 9, minute: 0));
      expect(r?.date, DateTime(2026, 6, 11));
    });

    test('„at 9pm" → 21:00 (am/pm точно)', () {
      final r = NaturalLanguageParser.parse('party at 9pm', 'en',
          now: DateTime(2026, 6, 10, 8, 0));
      expect(r?.time, const TimeOfDay(hour: 21, minute: 0));
    });

    test('„I may call John at 5" → без месец-дата, час 17:00 (правило 1)', () {
      final r = NaturalLanguageParser.parse('I may call John at 5', 'en',
          now: DateTime(2026, 6, 10, 10, 0));
      expect(r, isNotNull);
      expect(r!.time, const TimeOfDay(hour: 17, minute: 0));
      expect(r.date, DateTime(2026, 6, 10)); // НЕ „May 5"/„9 May"
    });

    test('„at 9 Main St" → null (без фалшив час И без фалшива дата „May 9")', () {
      final r = NaturalLanguageParser.parse('meet me at 9 Main St', 'en',
          now: DateTime(2026, 6, 10, 10, 0));
      expect(r, isNull);
    });

    test('„May"/„March" стават месец само до число: „9 May" → 9 май', () {
      final r = NaturalLanguageParser.parse('deadline 9 May', 'en');
      expect(r?.date, _nextDateOf(9, 5));
    });
  });

  group('Час 1–6 = следобед, 7–11 = предстоящо (корекция 1.0.73 r3)', () {
    // Фиксирано „сега" = 2026-06-10 19:07.
    final evening = DateTime(2026, 6, 10, 19, 7);

    test('сега 19:07 + „at 5" → утре 17:00 (1–6 следобед, минал днес)', () {
      final r = NaturalLanguageParser.parse('call at 5', 'en', now: evening);
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 17, minute: 0));
    });

    test('сега 19:07 + „at 7" → утре 07:00', () {
      final r = NaturalLanguageParser.parse('call at 7', 'en', now: evening);
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 7, minute: 0));
    });

    test('сега 19:07 + „at 8" → днес 20:00', () {
      final r = NaturalLanguageParser.parse('call at 8', 'en', now: evening);
      expect(r!.date, DateTime(2026, 6, 10));
      expect(r.time, const TimeOfDay(hour: 20, minute: 0));
    });

    // Фиксирано „сега" = 2026-06-10 10:00.
    final morning = DateTime(2026, 6, 10, 10, 0);

    test('сега 10:00 + „at 5" → днес 17:00 (1–6 следобед)', () {
      final r = NaturalLanguageParser.parse('call at 5', 'en', now: morning);
      expect(r!.date, DateTime(2026, 6, 10));
      expect(r.time, const TimeOfDay(hour: 17, minute: 0));
    });

    test('сега 10:00 + „at 7" → днес 19:00', () {
      final r = NaturalLanguageParser.parse('call at 7', 'en', now: morning);
      expect(r!.date, DateTime(2026, 6, 10));
      expect(r.time, const TimeOfDay(hour: 19, minute: 0));
    });

    test('„at 12" → 12:00 на обед (днес ако не е минал)', () {
      final r = NaturalLanguageParser.parse('lunch at 12', 'en', now: morning);
      expect(r!.date, DateTime(2026, 6, 10));
      expect(r.time, const TimeOfDay(hour: 12, minute: 0));
    });

  });

  group('Никога минало + част от деня (1.0.73 r4, сега=19:29)', () {
    final now = DateTime(2026, 6, 10, 19, 29);

    test('„Среща в 5 am" → утре 05:00', () {
      final r = NaturalLanguageParser.parse('Среща в 5 am', 'bg', now: now);
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 5, minute: 0));
    });
    test('„Среща в 5 сутринта" → утре 05:00', () {
      final r = NaturalLanguageParser.parse('Среща в 5 сутринта', 'bg', now: now);
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 5, minute: 0));
    });
    test('„Среща в 5 pm" → утре 17:00 (минал днес)', () {
      final r = NaturalLanguageParser.parse('Среща в 5 pm', 'bg', now: now);
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 17, minute: 0));
    });
    test('„Meeting at 5 am" → утре 05:00', () {
      final r = NaturalLanguageParser.parse('Meeting at 5 am', 'en', now: now);
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 5, minute: 0));
    });
    test('„Среща в 5" → утре 17:00 (1–6 следобед, минал)', () {
      final r = NaturalLanguageParser.parse('Среща в 5', 'bg', now: now);
      expect(r!.date, DateTime(2026, 6, 11));
      expect(r.time, const TimeOfDay(hour: 17, minute: 0));
    });
    test('„5 вечерта" → 17:00', () {
      final r = NaturalLanguageParser.parse('Събитие в 5 вечерта', 'bg',
          now: DateTime(2026, 6, 10, 8, 0));
      expect(r!.time, const TimeOfDay(hour: 17, minute: 0));
    });
  });

  group('Изчистване на заглавието (cleanTitle, 1.0.73 r4)', () {
    test('„Среща в 5 am" → „Среща"', () {
      expect(NaturalLanguageParser.cleanTitle('Среща в 5 am', 'bg'), 'Среща');
    });
    test('„Среща в 5 сутринта" → „Среща"', () {
      expect(NaturalLanguageParser.cleanTitle('Среща в 5 сутринта', 'bg'), 'Среща');
    });
    test('„Среща в 5 pm" → „Среща"', () {
      expect(NaturalLanguageParser.cleanTitle('Среща в 5 pm', 'bg'), 'Среща');
    });
    test('„Meeting at 5 am" → „Meeting"', () {
      expect(NaturalLanguageParser.cleanTitle('Meeting at 5 am', 'en'), 'Meeting');
    });
    test('„Среща в 5" → „Среща"', () {
      expect(NaturalLanguageParser.cleanTitle('Среща в 5', 'bg'), 'Среща');
    });
    test('„Среща в ресторант в 7" → „Среща в ресторант" (маха само часа)', () {
      expect(NaturalLanguageParser.cleanTitle('Среща в ресторант в 7', 'bg'),
          'Среща в ресторант');
    });
    test('„Restaurant at 7" → „Restaurant"', () {
      expect(NaturalLanguageParser.cleanTitle('Restaurant at 7', 'en'), 'Restaurant');
    });
    test('„Пътуване 12 декември" → „Пътуване"', () {
      expect(NaturalLanguageParser.cleanTitle('Пътуване 12 декември', 'bg'), 'Пътуване');
    });
    test('„купи мляко" (без дата/час) → непроменено', () {
      expect(NaturalLanguageParser.cleanTitle('купи мляко', 'bg'), 'купи мляко');
    });
  });
}
