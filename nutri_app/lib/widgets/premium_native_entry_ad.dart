import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nutri_app/services/ads_service.dart';
import 'package:provider/provider.dart';

class PremiumNativeEntryAd extends StatefulWidget {
  const PremiumNativeEntryAd({
    super.key,
    required this.adUnitId,
    required this.factoryId,
    required this.template,
    required this.timeoutMs,
  });

  final String adUnitId;
  final String factoryId;
  final String template;
  final int timeoutMs;

  @override
  State<PremiumNativeEntryAd> createState() => _PremiumNativeEntryAdState();
}

class _PremiumNativeEntryAdState extends State<PremiumNativeEntryAd> {
  NativeAd? _nativeAd;
  Timer? _timeoutTimer;
  bool _isLoaded = false;
  bool _timedOut = false;

  double get _adHeight {
    switch (widget.template) {
      case 'compact':
        return 250;
      case 'large_card':
        return 360;
      case 'small_card':
      default:
        return 310;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void didUpdateWidget(covariant PremiumNativeEntryAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId ||
        oldWidget.factoryId != widget.factoryId ||
        oldWidget.template != widget.template ||
        oldWidget.timeoutMs != widget.timeoutMs) {
      _disposeAd();
      _loadAd();
    }
  }

  void _loadAd() {
    _timedOut = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(milliseconds: widget.timeoutMs), () {
      if (!mounted || _isLoaded) {
        return;
      }
      setState(() {
        _timedOut = true;
      });
      _disposeAd();
    });

    final ad = NativeAd(
      adUnitId: widget.adUnitId,
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _timeoutTimer?.cancel();
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          _timeoutTimer?.cancel();
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isLoaded = false;
          });
        },
        onAdImpression: (ad) {
          unawaited(context.read<AdsService>().recordNativeEntryImpression());
        },
      ),
      customOptions: <String, Object>{'template': widget.template},
    );

    ad.load();
  }

  void _disposeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut || !_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      height: _adHeight,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
