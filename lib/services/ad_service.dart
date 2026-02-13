import 'package:flutter/foundation.dart';

// Условен import - stub за web, реален пакет за mobile
import 'ads_stub.dart' if (dart.library.io) 'package:google_mobile_ads/google_mobile_ads.dart';

import 'pro_service.dart';

class AdService extends ChangeNotifier {
  AdService._internal();

  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  bool _isInitialized = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  static const String _bannerAdUnitId = 'ca-app-pub-4385157735120275/2402990338';
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  bool get isBannerAdLoaded => _isBannerAdLoaded;
  BannerAd? get bannerAd => _bannerAd;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // На web не инициализираме реклами
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdService initialized');
    } catch (e) {
      debugPrint('AdService init error: $e');
    }
  }

  Future<void> loadBannerAd() async {
    // На web не зареждаме реклами
    if (kIsWeb) return;
   
    if (ProService().isPro) {
      debugPrint('AdService: Pro user, skipping ads');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    if (_isBannerAdLoaded && _bannerAd != null) {
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: kDebugMode ? _testBannerAdUnitId : _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded');
          _isBannerAdLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerAdLoaded = false;
          notifyListeners();
        },
        onAdOpened: (ad) {
          debugPrint('Banner ad opened');
        },
        onAdClosed: (ad) {
          debugPrint('Banner ad closed');
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

  Future<void> reloadBannerAd() async {
    disposeBannerAd();
    await loadBannerAd();
  }
}
