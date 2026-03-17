import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Условен import - stub за web, реален пакет за mobile
import 'ads_stub.dart' if (dart.library.io) 'package:google_mobile_ads/google_mobile_ads.dart';

import 'pro_service.dart';

class AdService extends ChangeNotifier {
  AdService._internal();

  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  int _actionCount = 0;
  static const int _actionsPerAd = 5;
  static const String _lastAppOpenKey = 'last_app_open_ad';

  static const String _interstitialAdUnitId = 'ca-app-pub-4385157735120275/2061138507';
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  // Banner Ad - запазваме за banner_ad_widget.dart
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  static const String _bannerAdUnitId = 'ca-app-pub-4385157735120275/2402990338';
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  bool get isBannerAdLoaded => _isBannerAdLoaded;
  BannerAd? get bannerAd => _bannerAd;

  Future<void> loadBannerAd() async {
    if (kIsWeb || ProService().isPro) return;
    if (!_isInitialized) await initialize();
    if (_isBannerAdLoaded && _bannerAd != null) return;

    _bannerAd = BannerAd(
      adUnitId: kDebugMode ? _testBannerAdUnitId : _bannerAdUnitId,
      size: AdSize.banner,
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

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdService initialized');
      await _loadInterstitialAd();
      await _checkAppOpenAd();
    } catch (e) {
      debugPrint('AdService init error: \$e');
    }
  }

  Future<void> _loadInterstitialAd() async {
    if (kIsWeb || ProService().isPro) return;
    if (!_isInitialized) return;

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

  Future<void> _checkAppOpenAd() async {
    if (ProService().isPro || kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastAppOpenKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLast = (now - lastMs) / 3600000;
    if (hoursSinceLast >= 24) {
      await prefs.setInt(_lastAppOpenKey, now);
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
