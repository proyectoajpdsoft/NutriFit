import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nutri_app/services/ads_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class PremiumAdShell extends StatelessWidget {
  final Widget child;

  const PremiumAdShell({super.key, required this.child});

  bool _shouldShowAds(AuthService authService, AdsService adsService) {
    return adsService.canShowAdsFor(authService);
  }

  @override
  Widget build(BuildContext context) {
    final adsService = context.watch<AdsService>();
    final authService = context.watch<AuthService>();

    return FutureBuilder<void>(
      future: context.read<AdsService>().ensureInitialized(),
      builder: (context, _) {
        final showAds = _shouldShowAds(authService, adsService) &&
            adsService.shouldShowBannerPlacement &&
            adsService.bannerAdUnitId != null;

        if (!showAds) {
          return child;
        }

        return Column(
          children: [
            Expanded(child: child),
            PremiumBannerAd(adUnitId: adsService.bannerAdUnitId!),
          ],
        );
      },
    );
  }
}

class PremiumBannerAd extends StatefulWidget {
  final String adUnitId;

  const PremiumBannerAd({super.key, required this.adUnitId});

  @override
  State<PremiumBannerAd> createState() => _PremiumBannerAdState();
}

class _PremiumBannerAdState extends State<PremiumBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  @override
  void didUpdateWidget(covariant PremiumBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId) {
      _disposeBanner();
      _loadBanner();
    }
  }

  void _loadBanner() {
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdImpression: (ad) {
          unawaited(context.read<AdsService>().recordBannerImpression());
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );
    banner.load();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
