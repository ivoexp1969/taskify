import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/ad_service.dart';
import '../services/pro_service.dart';

// Условен import
import '../services/ads_stub.dart' if (dart.library.io) 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  final AdService _adService = AdService();
  final ProService _proService = ProService();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _adService.addListener(_onAdServiceChanged);
      _proService.addListener(_onProStatusChanged);
      _loadAd();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _adService.removeListener(_onAdServiceChanged);
      _proService.removeListener(_onProStatusChanged);
    }
    super.dispose();
  }

  void _onAdServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onProStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAd() async {
    await _adService.loadBannerAd();
  }

  @override
  Widget build(BuildContext context) {
    // На web не показваме реклами
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    if (_proService.isPro) {
      return const SizedBox.shrink();
    }

    final bannerAd = _adService.bannerAd;

    if (!_adService.isBannerAdLoaded || bannerAd == null) {
      return const SizedBox(height: 50);
    }

    return Container(
      alignment: Alignment.center,
      width: bannerAd.size.width.toDouble(),
      height: bannerAd.size.height.toDouble(),
      child: AdWidget(ad: bannerAd),
    );
  }
}
