import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Условен import — Firestore не е наличен на web build без конфиг, затова
// remote refresh е guard-нат в try/catch и никога не блокира load().
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Една оферта за подновяване на изтичащ документ: „doctype + държава → линк".
///
/// [commercial] разграничава affiliate CTA (ГО, винетка) от неутрален инфо
/// линк за държавни документи (лична карта/паспорт/книжка), където няма
/// комисиона и продаване би подвело потребителя.
@immutable
class RenewalOffer {
  /// Типът документ, за който важи: 'insurance' | 'vignette' | 'inspection' |
  /// 'id_card' | 'passport' | 'license' | 'other'. Съответства на `doctype:`
  /// в notes на document-задачата.
  final String doctype;

  /// Идентификатор на партньора (за логове/атрибуция, не се показва).
  final String partner;

  /// URL с `{subid}` placeholder, който се замества при клик за атрибуция.
  final String urlTemplate;

  /// true → affiliate CTA („Поднови сега"); false → инфо линк („Как да подновя").
  final bool commercial;

  /// ISO-3166 alpha-2 кодове (малки букви), за които офертата важи, напр. ['bg'].
  final List<String> countries;

  /// Изключените оферти се игнорират изцяло (kill-switch през remote config).
  final bool enabled;

  /// Ключ за локализирания етикет на бутона ('renewNow' | 'howToRenew').
  final String labelKey;

  const RenewalOffer({
    required this.doctype,
    required this.partner,
    required this.urlTemplate,
    required this.commercial,
    required this.countries,
    required this.enabled,
    required this.labelKey,
  });

  factory RenewalOffer.fromJson(Map<String, dynamic> json) {
    return RenewalOffer(
      doctype: (json['doctype'] as String?)?.trim() ?? 'other',
      partner: (json['partner'] as String?)?.trim() ?? 'unknown',
      urlTemplate: (json['urlTemplate'] as String?)?.trim() ?? '',
      commercial: json['commercial'] as bool? ?? false,
      countries: ((json['countries'] as List?) ?? const [])
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      enabled: json['enabled'] as bool? ?? false,
      labelKey: (json['labelKey'] as String?)?.trim() ?? 'renewNow',
    );
  }
}

/// Управлява офертите за подновяване на изтичащи документи.
///
/// Източник (по приоритет): кеширан remote (Firestore) → вграден asset
/// (`assets/data/renewal_offers.json`). Remote refresh-ът е фоново и guard-нат
/// — при липса на мрежа/конфиг приложението работи с вградените стойности.
///
/// ФАЗА 0 (монетизация, Идея 1): само данни + резолюция + сглобяване на URL.
/// UI (CTA в картата/диалога/нотификацията) идва във Фаза 1+.
class RenewalService {
  RenewalService._internal();
  static final RenewalService _instance = RenewalService._internal();
  factory RenewalService() => _instance;

  static const String _assetPath = 'assets/data/renewal_offers.json';
  static const String _kCacheJson = 'renewal_offers_cache';
  static const String _kCacheTs = 'renewal_offers_cache_ts';
  static const String _kAnonId = 'renewal_anon_id';
  static const String _kClicksTotal = 'renewal_clicks_total';
  static const String _firestoreCollection = 'renewal_offers';
  static const String _clicksCollection = 'renewal_clicks';

  /// Колко дълго кешираният remote се смята за пресен (24 часа).
  static const Duration cacheTtl = Duration(hours: 24);

  /// Бумва се щом офертите се сменят (напр. след фоново теглене от Firestore),
  /// за да могат вече изградените CTA-та да се пре-оценят и бутонът да лъсне
  /// БЕЗ рестарт (виж [RenewalCta]).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<RenewalOffer> _offers = const [];
  bool _loaded = false;

  @visibleForTesting
  set offersForTest(List<RenewalOffer> offers) {
    _offers = offers;
    _loaded = true;
  }

  /// Зарежда офертите еднократно: пресен кеш → вграден asset. Пуска фоново
  /// remote refresh за следващия път. Безопасно при повторно извикване.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    // 1) Пресен кеш от предишен remote refresh.
    final cached = prefs.getString(_kCacheJson);
    final ts = prefs.getInt(_kCacheTs);
    if (cached != null && ts != null && _isFresh(ts)) {
      final parsed = parseOffers(cached);
      if (parsed.isNotEmpty) {
        _offers = parsed;
        _loaded = true;
        return;
      }
    }

    // 2) Вграден fallback.
    try {
      final raw = await rootBundle.loadString(_assetPath);
      _offers = parseOffers(raw);
    } catch (e) {
      debugPrint('RenewalService: bundled load failed → $e');
      _offers = const [];
    }
    _loaded = true;

    // 3) Фоново обновяване за следващата сесия (не чакаме).
    unawaited(refreshFromRemote());
  }

  bool _isFresh(int tsMillis) =>
      DateTime.now().millisecondsSinceEpoch - tsMillis < cacheTtl.inMilliseconds;

  /// Тегли офертите от Firestore и ги кешира. Изцяло guard-нат — при грешка
  /// просто не прави нищо (остават вградените/кешираните стойности).
  Future<void> refreshFromRemote() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection(_firestoreCollection).get();
      final list = snap.docs.map((d) => d.data()).toList();
      if (list.isEmpty) return;
      final parsed =
          list.map((m) => RenewalOffer.fromJson(m)).toList(growable: false);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kCacheJson, json.encode({'version': 1, 'offers': list}));
      await prefs.setInt(_kCacheTs, DateTime.now().millisecondsSinceEpoch);
      _offers = parsed; // важи и за текущата сесия
      revision.value++; // → CTA-тата се пре-оценяват веднага
    } catch (e) {
      debugPrint('RenewalService: remote refresh skipped → $e');
    }
  }

  /// Оферта за конкретен документ в конкретна държава (или null).
  RenewalOffer? offerFor({required String doctype, required String? country}) {
    return resolveOffer(
      offers: _offers,
      doctype: doctype,
      country: normalizeCountry(country),
    );
  }

  /// Регистрира клик (локален брояч + guard-нат Firestore лог за собствен
  /// dashboard) и връща готовия за отваряне URL с уникален subid за атрибуция.
  /// Логването никога не блокира отварянето на линка.
  Future<String> registerClickAndBuildUrl(RenewalOffer offer) async {
    final anon = await _anonId();
    final subid = makeSubid(
      anonId: anon,
      doctype: offer.doctype,
      epochSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final url = buildUrl(template: offer.urlTemplate, subid: subid);

    // Локален брояч (за бърза диагностика без мрежа).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _kClicksTotal, (prefs.getInt(_kClicksTotal) ?? 0) + 1);
    } catch (_) {/* без значение за потока */}

    // Отдалечен лог — изцяло guard-нат. Правилата на `renewal_clicks` искат
    // `request.auth != null`; ако потребителят не е логнат, правим тих анонимен
    // вход само за да мине логът (анонимните НЕ синхронизират лични данни).
    try {
      final authed = await AuthService().ensureAuthedForLogging();
      if (!authed) return url; // офлайн/изключен доставчик → само локален брояч
      await FirebaseFirestore.instance.collection(_clicksCollection).add({
        'anonId': anon,
        'doctype': offer.doctype,
        'partner': offer.partner,
        'subid': subid,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RenewalService: click log skipped → $e');
    }

    return url;
  }

  /// Логва „интерес" към бъдеща оферта (напр. цветя/подарък за рожден/имен ден),
  /// докато реален партньор още няма. Мери търсенето ПРЕДИ старта — силен
  /// аргумент в преговорите. Същият guard-нат път като [registerClickAndBuildUrl],
  /// но без URL: локален брояч + (при логнат/анонимен вход) запис в
  /// `renewal_clicks` с `type:'interest'`. Никога не хвърля.
  Future<void> logInterest({required String kind}) async {
    final anon = await _anonId();
    final subid = makeSubid(
      anonId: anon,
      doctype: kind,
      epochSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _kClicksTotal, (prefs.getInt(_kClicksTotal) ?? 0) + 1);
    } catch (_) {/* без значение за потока */}

    try {
      final authed = await AuthService().ensureAuthedForLogging();
      if (!authed) return; // офлайн/изключен доставчик → само локален брояч
      await FirebaseFirestore.instance.collection(_clicksCollection).add({
        'anonId': anon,
        'doctype': kind,
        'partner': 'pending',
        'subid': subid,
        'type': 'interest',
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RenewalService: interest log skipped → $e');
    }
  }

  /// Общ брой кликове върху „Поднови" (локален, за бърза проверка).
  Future<int> clicksTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kClicksTotal) ?? 0;
  }

  /// Стабилен анонимен идентификатор (НЕ Firebase uid — много юзъри са
  /// анонимни). Генерира се веднъж и се пази локално.
  Future<String> _anonId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kAnonId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _randomId(12);
    await prefs.setString(_kAnonId, id);
    return id;
  }

  static String _randomId(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ── Pure функции (за тестове) ────────────────────────────────────────────

  /// Парсва JSON тяло `{ "offers": [...] }` в списък оферти. Толерантен към
  /// повредени записи (пропуска ги). Pure — за тестове.
  static List<RenewalOffer> parseOffers(String raw) {
    try {
      final data = json.decode(raw);
      final list = (data is Map<String, dynamic>) ? data['offers'] : data;
      if (list is! List) return const [];
      final out = <RenewalOffer>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            out.add(RenewalOffer.fromJson(item));
          } catch (_) {/* пропускаме повреден запис */}
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Първата активна оферта, която съвпада по doctype И държава. Pure — за
  /// тестове. Изключените ([enabled] == false) и тези с празен URL се пропускат.
  static RenewalOffer? resolveOffer({
    required List<RenewalOffer> offers,
    required String doctype,
    required String country,
  }) {
    for (final o in offers) {
      if (!o.enabled) continue;
      if (o.urlTemplate.isEmpty) continue;
      if (o.doctype != doctype) continue;
      if (!o.countries.contains(country)) continue;
      return o;
    }
    return null;
  }

  /// Замества `{subid}` с URL-encoded стойност. Pure — за тестове.
  static String buildUrl({required String template, required String subid}) {
    return template.replaceAll('{subid}', Uri.encodeQueryComponent(subid));
  }

  /// Сглобява subid за атрибуция: „anon-doctype-epoch". Чисти разделителя.
  /// Pure — за тестове.
  static String makeSubid({
    required String anonId,
    required String doctype,
    required int epochSeconds,
  }) {
    String clean(String s) => s.replaceAll('-', '').replaceAll(' ', '');
    return '${clean(anonId)}-${clean(doctype)}-$epochSeconds';
  }

  /// Нормализира кода на държавата към малки букви alpha-2; 'xx' при липса.
  /// Pure — за тестове.
  static String normalizeCountry(String? code) {
    final c = code?.trim().toLowerCase() ?? '';
    return c.isEmpty ? 'xx' : c;
  }
}
