import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/services/ai_usage_service.dart';

void main() {
  group('AiUsageService.dateKeyFor', () {
    test('пада нулите за месец/ден', () {
      expect(AiUsageService.dateKeyFor(DateTime(2026, 6, 2)), '2026-06-02');
      expect(AiUsageService.dateKeyFor(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('AiUsageService.resolveUsed — reset логика', () {
    // Тест 1: преди полунощ (същият ден) → броячът се запазва
    test('същият ден запазва брояча', () {
      final today = AiUsageService.dateKeyFor(DateTime(2026, 6, 2, 23, 59));
      expect(
        AiUsageService.resolveUsed(storedDate: today, storedCount: 5, todayKey: today),
        5,
      );
    });

    // Тест 2: в/след полунощ (нов ден) → reset на 0
    test('пресичане на полунощ нулира брояча', () {
      final stored = AiUsageService.dateKeyFor(DateTime(2026, 6, 2, 23, 59));
      final afterMidnight = AiUsageService.dateKeyFor(DateTime(2026, 6, 3, 0, 0));
      expect(stored == afterMidnight, isFalse);
      expect(
        AiUsageService.resolveUsed(storedDate: stored, storedCount: 20, todayKey: afterMidnight),
        0,
      );
    });

    // Тест 3: смяна на дата (различен запазен ден) → reset на 0
    test('различна запазена дата нулира брояча', () {
      expect(
        AiUsageService.resolveUsed(storedDate: '2026-06-01', storedCount: 12, todayKey: '2026-06-02'),
        0,
      );
    });

    test('липсваща запазена дата (null) дава 0', () {
      expect(
        AiUsageService.resolveUsed(storedDate: null, storedCount: 0, todayKey: '2026-06-02'),
        0,
      );
    });
  });

  group('AiUsageService — end-to-end през SharedPreferences', () {
    test('застояла дата от вчера се нулира, после recordUse брои от 1', () async {
      // Симулираме вчерашен запис с пълен брояч
      final yesterday = AiUsageService.dateKeyFor(
        DateTime.now().subtract(const Duration(days: 1)));
      SharedPreferences.setMockInitialValues({
        'ai_usage_date': yesterday,
        'ai_usage_count': 20,
      });

      final svc = AiUsageService.instance;

      // Нов ден → използвани днес = 0, може да се ползва
      expect(await svc.usedToday(), 0);
      expect(await svc.canUse(), isTrue);

      // Първа заявка днес → брои от 1 с днешния ден-ключ
      await svc.recordUse();
      expect(await svc.usedToday(), 1);
      expect(await svc.remainingToday(), AiUsageService.dailyLimit - 1);
    });

    test('canUse е false при достигнат таван за днес', () async {
      final todayKey = AiUsageService.dateKeyFor(DateTime.now());
      SharedPreferences.setMockInitialValues({
        'ai_usage_date': todayKey,
        'ai_usage_count': AiUsageService.dailyLimit,
      });
      final svc = AiUsageService.instance;
      expect(await svc.usedToday(), AiUsageService.dailyLimit);
      expect(await svc.canUse(), isFalse);
    });

    test('toggle настройките се persist-ват', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = AiUsageService.instance;
      // Default — включени
      expect(await svc.isParsingEnabled(), isTrue);
      expect(await svc.isVoiceEnabled(), isTrue);
      await svc.setParsingEnabled(false);
      await svc.setVoiceEnabled(false);
      expect(await svc.isParsingEnabled(), isFalse);
      expect(await svc.isVoiceEnabled(), isFalse);
    });
  });
}
