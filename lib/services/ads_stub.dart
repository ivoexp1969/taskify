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
