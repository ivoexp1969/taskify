import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../services/pro_service.dart';

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
    _loadAd();
    _proService.addListener(_onProStatusChanged);
  }

  @override
  void dispose() {
    _proService.removeListener(_onProStatusChanged);
    super.dispose();
  }

  void _onProStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAd() async {
    await _adService.loadBannerAd();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
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
