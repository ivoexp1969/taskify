// Stub за web - тези класове не съществуват на web
import 'package:flutter/material.dart';

class MobileAds {
  static final MobileAds instance = MobileAds._();
  MobileAds._();
  Future<void> initialize() async {}
}

class BannerAd {
  final String adUnitId;
  final AdSize size;
  final AdRequest request;
  final BannerAdListener listener;

  BannerAd({
    required this.adUnitId,
    required this.size,
    required this.request,
    required this.listener,
  });

  Future<void> load() async {}
  void dispose() {}
}

class AdSize {
  static const AdSize banner = AdSize._(320, 50);
  final int width;
  final int height;
  const AdSize._(this.width, this.height);

  // Web стъб — adaptive размерът никога не се ползва (kIsWeb short-circuit).
  static Future<AdSize?> getAnchoredAdaptiveBannerAdSize(
    Orientation orientation,
    int width,
  ) async =>
      null;
}

class AdRequest {
  const AdRequest();
}

class BannerAdListener {
  final void Function(Ad)? onAdLoaded;
  final void Function(Ad, LoadAdError)? onAdFailedToLoad;
  final void Function(Ad)? onAdOpened;
  final void Function(Ad)? onAdClosed;

  BannerAdListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdOpened,
    this.onAdClosed,
  });
}

class Ad {
  void dispose() {}
}

class LoadAdError {
  @override
  String toString() => 'LoadAdError';
}

class AdWidget extends StatelessWidget {
  final dynamic ad;
  const AdWidget({super.key, required this.ad});
  
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class FullScreenContentCallback {
  final void Function(Ad)? onAdDismissedFullScreenContent;
  final void Function(Ad, dynamic)? onAdFailedToShowFullScreenContent;
  const FullScreenContentCallback({this.onAdDismissedFullScreenContent, this.onAdFailedToShowFullScreenContent});
}

class InterstitialAdLoadCallback {
  final void Function(InterstitialAd) onAdLoaded;
  final void Function(dynamic) onAdFailedToLoad;
  const InterstitialAdLoadCallback({required this.onAdLoaded, required this.onAdFailedToLoad});
}

class InterstitialAd extends Ad {
  FullScreenContentCallback? fullScreenContentCallback;
  static Future<void> load({required String adUnitId, required dynamic request, required InterstitialAdLoadCallback adLoadCallback}) async {}
  Future<void> show() async {}
}

// --- UMP (User Messaging Platform) stubs за web ---
// На web рекламите изобщо не се инициализират (kIsWeb short-circuit), тези
// класове съществуват само за да компилира условният import.
class ConsentInformation {
  static final ConsentInformation instance = ConsentInformation._();
  ConsentInformation._();
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    void Function() onSuccess,
    void Function(FormError) onError,
  ) {}
  Future<bool> canRequestAds() async => false;
  Future<bool> isConsentFormAvailable() async => false;
  void reset() {}
}

class ConsentForm {
  static Future<void> loadAndShowConsentFormIfRequired(
    void Function(FormError?) onDismissed,
  ) async {}
}

class ConsentRequestParameters {
  ConsentRequestParameters();
}

class FormError {
  final String message;
  const FormError({this.message = ''});
}
