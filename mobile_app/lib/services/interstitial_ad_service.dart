import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

class InterstitialAdService {
  InterstitialAd? _ad;
  DateTime? _lastShownTime;
  static const _cooldown = Duration(minutes: 2);

  void preload() {
    try {
      debugPrint('[AdMob] Loading interstitial ad...');
      InterstitialAd.load(
        adUnitId: AdService.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[AdMob] Interstitial loaded successfully');
            _ad = ad;
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              '[AdMob] Interstitial failed to load: '
              'code=${error.code} message=${error.message} '
              'domain=${error.domain}',
            );
            _ad = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdMob] Interstitial load exception: $e');
    }
  }

  Future<void> showBeforePdfExport({
    required Future<void> Function() onContinue,
  }) async {
    final ad = _ad;
    final now = DateTime.now();

    final withinCooldown = _lastShownTime != null &&
        now.difference(_lastShownTime!) < _cooldown;

    debugPrint(
      '[AdMob] showBeforePdfExport: '
      'adReady=${ad != null}, withinCooldown=$withinCooldown',
    );

    if (ad == null || withinCooldown) {
      await onContinue();
      return;
    }

    _ad = null;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        debugPrint('[AdMob] Interstitial dismissed');
        _lastShownTime = DateTime.now();
        a.dispose();
        if (!completer.isCompleted) completer.complete();
        preload();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        debugPrint('[AdMob] Interstitial failed to show: ${error.message}');
        a.dispose();
        if (!completer.isCompleted) completer.complete();
        preload();
      },
    );

    try {
      debugPrint('[AdMob] Showing interstitial...');
      await ad.show();
      await completer.future;
    } catch (e) {
      debugPrint('[AdMob] Interstitial show exception: $e');
      if (!completer.isCompleted) completer.complete();
    }

    await onContinue();
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
