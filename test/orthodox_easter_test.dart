import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/utils/orthodox_easter.dart';

void main() {
  group('orthodoxEaster', () {
    // Известни дати на православния Великден (григориански календар).
    final known = <int, DateTime>{
      2020: DateTime(2020, 4, 19),
      2021: DateTime(2021, 5, 2),
      2022: DateTime(2022, 4, 24),
      2023: DateTime(2023, 4, 16),
      2024: DateTime(2024, 5, 5),
      2025: DateTime(2025, 4, 20),
      2026: DateTime(2026, 4, 12),
      2027: DateTime(2027, 5, 2),
    };

    known.forEach((year, expected) {
      test('Великден $year е ${expected.day}.${expected.month}', () {
        final result = orthodoxEaster(year);
        expect(result.year, expected.year);
        expect(result.month, expected.month);
        expect(result.day, expected.day);
      });
    });

    test('връща нормализирана дата (без час)', () {
      final e = orthodoxEaster(2024);
      expect(e.hour, 0);
      expect(e.minute, 0);
      expect(e.second, 0);
    });

    test('винаги пада в неделя', () {
      for (var year = 1900; year <= 2099; year++) {
        expect(orthodoxEaster(year).weekday, DateTime.sunday,
            reason: 'Великден $year не е неделя');
      }
    });

    // Тодоровден = първа събота на Великия пост = Великден - 43 дни.
    // Календарна аритметика (day - 43), а НЕ Duration — иначе DST дрейф
    // измества датата с ден (27 вместо 28 февруари в BG timezone).
    DateTime todorovden(int year) {
      final e = orthodoxEaster(year);
      return DateTime(e.year, e.month, e.day - 43);
    }

    test('Тодоровден е 28 февруари 2026 (събота)', () {
      expect(todorovden(2026), DateTime(2026, 2, 28));
      expect(todorovden(2026).weekday, DateTime.saturday);
    });

    test('Тодоровден винаги пада в събота', () {
      for (var year = 2020; year <= 2030; year++) {
        expect(todorovden(year).weekday, DateTime.saturday,
            reason: 'Тодоровден $year не е събота');
      }
    });
  });
}
