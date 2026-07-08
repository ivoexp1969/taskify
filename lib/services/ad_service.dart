import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Orientation;

// Условен import - stub за web, реален пакет за mobile
import 'ads_stub.dart' if (dart.library.io) 'package:google_mobile_ads/google_mobile_ads.dart';

import 'pro_service.dart';

class AdService extends ChangeNotifier {
  AdService._internal();

  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  bool _isInitialized = false;
  // ФАЗА 1 (GDPR/UMP): става true само след като UMP consent процесът приключи
  // и SDK-то разреши заявки за реклами. ВСИЧКИ load точки (банер, interstitial,
  // app-open) го проверяват → нищо не се зарежда без consent gate.
  bool _canRequestAds = false;
  bool get canRequestAds => _canRequestAds;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  int _actionCount = 0;
  // По-меко (решение на потребителя): interstitial по-рядко, за да не дразни.
  static const int _actionsPerAd = 11;

  // Android production ad unit IDs
  static const String _interstitialAdUnitIdAndroid = 'ca-app-pub-4385157735120275/2061138507';
  static const String _bannerAdUnitIdAndroid = 'ca-app-pub-4385157735120275/2402990338';

  // iOS production ad unit IDs
  // TODO: създай Interstitial ad unit в AdMob конзолата и замени test ID-то
  static const String _interstitialAdUnitIdIos = 'ca-app-pub-4385157735120275/9347161535';
  static const String _bannerAdUnitIdIos = 'ca-app-pub-4385157735120275/7806895919';

  // Test ad unit IDs (от Google) — различни за Android и iOS
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  String get _interstitialAdUnitId => (defaultTargetPlatform == TargetPlatform.iOS)
      ? _interstitialAdUnitIdIos
      : _interstitialAdUnitIdAndroid;

  String get _testInterstitialAdUnitId => (defaultTargetPlatform == TargetPlatform.iOS)
      ? _testInterstitialIos
      : _testInterstitialAndroid;

  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  // Banner Ad — запазваме за banner_ad_widget.dart
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  String get _bannerAdUnitId => (defaultTargetPlatform == TargetPlatform.iOS)
      ? _bannerAdUnitIdIos
      : _bannerAdUnitIdAndroid;

  String get _testBannerAdUnitId => (defaultTargetPlatform == TargetPlatform.iOS)
      ? _testBannerIos
      : _testBannerAndroid;

  bool get isBannerAdLoaded => _isBannerAdLoaded;
  BannerAd? get bannerAd => _bannerAd;

  Future<void> loadBannerAd({double? width}) async {
    if (kIsWeb || ProService().isPro) return;
    if (!_isInitialized) await initialize();
    if (!_canRequestAds) return; // UMP consent gate
    if (_isBannerAdLoaded && _bannerAd != null) return;

    // ФАЗА 1.3: anchored ADAPTIVE банер — по-добър fill/вид от фиксирания
    // 320x50. Ширината идва от екрана (подадена от BannerAdWidget). Ако SDK-то
    // не върне adaptive размер → fallback към стандартния банер.
    AdSize size = AdSize.banner;
    if (width != null && width > 0) {
      final adaptive = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        width.truncate(),
      );
      if (adaptive != null) size = adaptive;
    }

    _bannerAd = BannerAd(
      adUnitId: kDebugMode ? _testBannerAdUnitId : _bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerAdLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isBannerAdLoaded = false;
          notifyListeners();
        },
      ),
    );
    await _bannerAd?.load();
  }

  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
    notifyListeners();
  }

  // Пази consent/init да НЕ тръгне двойно при студен старт (main.dart и
  // BannerAdWidget.initState викат initialize() почти едновременно).
  Future<void>? _initFuture;
  Future<void> initialize() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }
    try {
      // ФАЗА 1: UMP (GDPR) consent ПРЕДИ MobileAds.initialize() и ПРЕДИ всяко
      // зареждане на реклама. При студен старт main.dart вика initialize(), така
      // че и app-open проверката минава през gate-а.
      await _gatherConsent();

      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdService initialized (canRequestAds=$_canRequestAds)');
      await _loadInterstitialAd();
    } catch (e) {
      debugPrint('AdService init error: $e');
    }
  }

  /// Изисква UMP consent (ЕС/GDPR). Блокира докато формата приключи, после
  /// пита SDK-то дали изобщо може да заявява реклами (`canRequestAds`). При
  /// изключение fail-open (не блокираме рекламите завинаги заради временна
  /// грешка), но при явен отговор `false` от SDK-то — уважаваме го.
  Future<void> _gatherConsent() async {
    if (kIsWeb) return;
    try {
      final params = ConsentRequestParameters();
      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // Показва формата за съгласие само ако е нужна (ЕС/EEA/UK).
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
              if (error != null) {
                debugPrint('UMP form error: ${error.message}');
              }
              if (!completer.isCompleted) completer.complete();
            });
          } catch (e) {
            debugPrint('UMP loadAndShow error: $e');
            if (!completer.isCompleted) completer.complete();
          }
        },
        (FormError error) {
          debugPrint('UMP requestConsentInfoUpdate error: ${error.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
    } catch (e) {
      debugPrint('UMP consent error: $e');
    }
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      // canRequestAds() сам хвърли → не знаем нищо от SDK-то. За EEA/UK
      // потребител fail-CLOSED (без събран consent → без реклами; GDPR/AdMob
      // policy). Извън EEA fail-open — не губим приход при рядък локален срив.
      _canRequestAds = !_isLikelyEeaUser();
    }
  }

  /// EEA/EEA-подобни държави (GDPR обхват): EU-27 + IS/LI/NO (EEA) + GB (UK
  /// GDPR) + CH. Ползва се САМО при неопределимо consent състояние (exception),
  /// за да решим fail-closed vs fail-open.
  static const Set<String> _eeaCountries = {
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR',
    'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
    'SI', 'ES', 'SE', 'IS', 'LI', 'NO', 'GB', 'CH',
  };

  /// Груба (device-region) евристика. Не е перфектна (VPN/пътуващ), но е
  /// достатъчна за консервативно решение при exception. Неизвестна държава →
  /// приемаме EEA (по-безопасно = fail-closed).
  bool _isLikelyEeaUser() {
    try {
      final country =
          ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
      if (country == null) return true;
      return _eeaCountries.contains(country);
    } catch (_) {
      return true;
    }
  }

  Future<void> _loadInterstitialAd() async {
    if (kIsWeb || ProService().isPro) return;
    if (!_isInitialized) return;
    if (!_canRequestAds) return; // UMP consent gate

    await InterstitialAd.load(
      adUnitId: kDebugMode ? _testInterstitialAdUnitId : _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          debugPrint('Interstitial ad loaded');
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          debugPrint('Interstitial ad failed: \$error');
        },
      ),
    );
  }

  /// Вика се след всяко добавяне или завършване на задача
  Future<void> onUserAction() async {
    if (ProService().isPro || kIsWeb) return;
    _actionCount++;
    if (_actionCount >= _actionsPerAd) {
      _actionCount = 0;
      await _showInterstitial();
    }
  }

  Future<void> _showInterstitial() async {
    if (!_isInterstitialAdLoaded || _interstitialAd == null) {
      await _loadInterstitialAd();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        _loadInterstitialAd();
      },
    );
    await _interstitialAd!.show();
  }
}
