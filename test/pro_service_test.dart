import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/services/pro_service.dart';
import 'package:task_manager/utils/debug_overrides.dart';

void main() {
  // Фиксирано „сега" за детерминизъм.
  final now = DateTime(2026, 11, 1, 12, 0);
  final past = now.subtract(const Duration(days: 1));
  final future = now.add(const Duration(days: 1));

  group('proActive (чиста логика) — НИКОГА не заключва валиден Pro', () {
    test('активен entitlement / офлайн платец (кеш) → Pro', () {
      expect(proActive(paidOrCached: true, now: now), isTrue);
      // дори с изтекъл trial отдолу
      expect(
        proActive(paidOrCached: true, trialEnd: past, now: now),
        isTrue,
      );
    });

    test('lifetime покупка/промо → Pro завинаги', () {
      expect(
        proActive(paidOrCached: false, promoType: 'lifetime', now: now),
        isTrue,
      );
      // lifetime бие дори изтекъл trial
      expect(
        proActive(
            paidOrCached: false,
            promoType: 'lifetime',
            trialEnd: past,
            now: now),
        isTrue,
      );
    });

    test('активно промо за дни → Pro', () {
      expect(
        proActive(
            paidOrCached: false,
            promoType: 'days',
            promoEnd: future,
            now: now),
        isTrue,
      );
    });

    test('активен trial → Pro', () {
      expect(
        proActive(paidOrCached: false, trialEnd: future, now: now),
        isTrue,
      );
    });
  });

  group('proActive — заключва само когато всички причини са отпаднали', () {
    test('изтекъл trial, без друг статус → free', () {
      expect(
        proActive(paidOrCached: false, trialEnd: past, now: now),
        isFalse,
      );
    });

    test('изтекло промо за дни, без друг статус → free', () {
      expect(
        proActive(
            paidOrCached: false,
            promoType: 'days',
            promoEnd: past,
            now: now),
        isFalse,
      );
    });

    test('нищо зададено → free', () {
      expect(proActive(paidOrCached: false, now: now), isFalse);
    });

    test('forceTrialExpired игнорира иначе активен trial → free', () {
      expect(
        proActive(
            paidOrCached: false,
            trialEnd: future,
            now: now,
            forceTrialExpired: true),
        isFalse,
      );
    });
  });

  group('ProService getters (read-time спрямо датата)', () {
    setUp(() {
      DebugOverrides.fakeNow = now;
      DebugOverrides.forceTrialExpired = false;
      ProService().debugSetState(
          paid: false, trialEnd: null, promoType: null, promoEnd: null);
    });

    tearDown(() {
      DebugOverrides.fakeNow = null;
      DebugOverrides.forceTrialExpired = false;
      ProService().debugSetState(
          paid: false, trialEnd: null, promoType: null, promoEnd: null);
    });

    test('платец → isPro, не trial, не promo', () {
      ProService().debugSetState(paid: true);
      expect(ProService().isPro, isTrue);
      expect(ProService().isTrial, isFalse);
      expect(ProService().isPromoCode, isFalse);
    });

    test('активен trial → isPro & isTrial', () {
      ProService().debugSetState(trialEnd: future);
      expect(ProService().isPro, isTrue);
      expect(ProService().isTrial, isTrue);
    });

    test('изтекъл trial → free', () {
      ProService().debugSetState(trialEnd: past);
      expect(ProService().isPro, isFalse);
      expect(ProService().isTrial, isFalse);
    });

    test('lifetime промо → isPro & isPromoCode', () {
      ProService().debugSetState(promoType: 'lifetime');
      expect(ProService().isPro, isTrue);
      expect(ProService().isPromoCode, isTrue);
    });

    test('активно промо за дни → isPro', () {
      ProService().debugSetState(promoType: 'days', promoEnd: future);
      expect(ProService().isPro, isTrue);
      expect(ProService().isPromoCode, isTrue);
    });

    test('изтекло промо за дни → free', () {
      ProService().debugSetState(promoType: 'days', promoEnd: past);
      expect(ProService().isPro, isFalse);
      expect(ProService().isPromoCode, isFalse);
    });

    test('debug forceTrialExpired заключва активен trial', () {
      ProService().debugSetState(trialEnd: future);
      DebugOverrides.forceTrialExpired = true;
      expect(ProService().isPro, isFalse);
      expect(ProService().isTrial, isFalse);
    });
  });
}
