import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/services/renewal_service.dart';

/// Помощник: активна оферта за подадени параметри.
RenewalOffer _offer({
  String doctype = 'insurance',
  String partner = 'p',
  String url = 'https://x.example/go?subid={subid}',
  bool commercial = true,
  List<String> countries = const ['bg'],
  bool enabled = true,
  String labelKey = 'renewNow',
}) {
  return RenewalOffer(
    doctype: doctype,
    partner: partner,
    urlTemplate: url,
    commercial: commercial,
    countries: countries,
    enabled: enabled,
    labelKey: labelKey,
  );
}

void main() {
  group('RenewalService.normalizeCountry', () {
    test('малки букви + trim', () {
      expect(RenewalService.normalizeCountry(' BG '), 'bg');
      expect(RenewalService.normalizeCountry('De'), 'de');
    });
    test('празно/null → xx', () {
      expect(RenewalService.normalizeCountry(null), 'xx');
      expect(RenewalService.normalizeCountry('   '), 'xx');
    });
  });

  group('RenewalService.resolveOffer', () {
    test('съвпадение по doctype + държава връща офертата', () {
      final o = _offer();
      final r = RenewalService.resolveOffer(
        offers: [o],
        doctype: 'insurance',
        country: 'bg',
      );
      expect(r, same(o));
    });

    test('грешна държава → null', () {
      final r = RenewalService.resolveOffer(
        offers: [_offer(countries: ['bg'])],
        doctype: 'insurance',
        country: 'de',
      );
      expect(r, isNull);
    });

    test('грешен doctype → null', () {
      final r = RenewalService.resolveOffer(
        offers: [_offer(doctype: 'insurance')],
        doctype: 'vignette',
        country: 'bg',
      );
      expect(r, isNull);
    });

    test('изключена оферта се пропуска', () {
      final r = RenewalService.resolveOffer(
        offers: [_offer(enabled: false)],
        doctype: 'insurance',
        country: 'bg',
      );
      expect(r, isNull);
    });

    test('оферта с празен URL се пропуска', () {
      final r = RenewalService.resolveOffer(
        offers: [_offer(url: '')],
        doctype: 'insurance',
        country: 'bg',
      );
      expect(r, isNull);
    });

    test('връща ПЪРВАТА активна при няколко съвпадения', () {
      final first = _offer(partner: 'first');
      final second = _offer(partner: 'second');
      final r = RenewalService.resolveOffer(
        offers: [first, second],
        doctype: 'insurance',
        country: 'bg',
      );
      expect(r!.partner, 'first');
    });

    test('прескача изключената и връща следващата активна', () {
      final disabled = _offer(partner: 'disabled', enabled: false);
      final active = _offer(partner: 'active');
      final r = RenewalService.resolveOffer(
        offers: [disabled, active],
        doctype: 'insurance',
        country: 'bg',
      );
      expect(r!.partner, 'active');
    });

    test('оферта за няколко държави важи за всяка от тях', () {
      final o = _offer(countries: ['bg', 'ro']);
      expect(
        RenewalService.resolveOffer(offers: [o], doctype: 'insurance', country: 'ro'),
        same(o),
      );
    });
  });

  group('RenewalService.buildUrl', () {
    test('замества {subid}', () {
      final url = RenewalService.buildUrl(
        template: 'https://x.example/go?ref=taskify&subid={subid}',
        subid: 'abc-insurance-1720',
      );
      expect(url, 'https://x.example/go?ref=taskify&subid=abc-insurance-1720');
    });

    test('URL-encode на subid-а', () {
      final url = RenewalService.buildUrl(
        template: 'https://x.example/go?subid={subid}',
        subid: 'a b/c',
      );
      expect(url.contains(' '), isFalse);
      expect(url.contains('subid=a'), isTrue);
    });

    test('без {subid} шаблонът остава непроменен', () {
      const tpl = 'https://x.example/info';
      expect(RenewalService.buildUrl(template: tpl, subid: 'z'), tpl);
    });
  });

  group('RenewalService.makeSubid', () {
    test('формат anon-doctype-epoch', () {
      expect(
        RenewalService.makeSubid(anonId: 'ab12', doctype: 'insurance', epochSeconds: 1720),
        'ab12-insurance-1720',
      );
    });

    test('чисти вътрешни тирета/интервали (за да не чупят разделителя)', () {
      final s = RenewalService.makeSubid(
          anonId: 'a-b 12', doctype: 'id-card', epochSeconds: 5);
      expect(s, 'ab12-idcard-5');
    });
  });

  group('RenewalService.parseOffers', () {
    test('парсва валиден списък и полета', () {
      const raw = '''
        {"offers":[
          {"doctype":"insurance","partner":"p","urlTemplate":"https://x/{subid}",
           "commercial":true,"countries":["BG"],"enabled":true,"labelKey":"renewNow"}
        ]}''';
      final offers = RenewalService.parseOffers(raw);
      expect(offers, hasLength(1));
      final o = offers.first;
      expect(o.doctype, 'insurance');
      expect(o.commercial, isTrue);
      expect(o.countries, ['bg']); // нормализирани към малки букви
      expect(o.enabled, isTrue);
    });

    test('пропуска повредени записи, задържа валидните', () {
      const raw = '{"offers":[123,{"doctype":"vignette","enabled":true}]}';
      final offers = RenewalService.parseOffers(raw);
      expect(offers, hasLength(1));
      expect(offers.first.doctype, 'vignette');
    });

    test('липсващи полета → безопасни стойности по подразбиране', () {
      const raw = '{"offers":[{"doctype":"other"}]}';
      final o = RenewalService.parseOffers(raw).first;
      expect(o.enabled, isFalse); // по подразбиране изключена
      expect(o.commercial, isFalse);
      expect(o.countries, isEmpty);
      expect(o.labelKey, 'renewNow');
    });

    test('невалиден JSON → празен списък (без хвърляне)', () {
      expect(RenewalService.parseOffers('не е json'), isEmpty);
      expect(RenewalService.parseOffers('{}'), isEmpty);
    });
  });

  group('RenewalService.offerFor (инстанция + inject)', () {
    test('offersForTest + offerFor резолюция', () {
      final svc = RenewalService();
      svc.offersForTest = [_offer(doctype: 'vignette', countries: ['bg'])];
      expect(
        svc.offerFor(doctype: 'vignette', country: 'BG')?.doctype,
        'vignette',
      );
      expect(svc.offerFor(doctype: 'vignette', country: 'de'), isNull);
    });
  });
}
