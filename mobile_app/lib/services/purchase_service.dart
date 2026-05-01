import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

abstract class PurchaseService {
  static const String premiumMonthlyProductId = 'premium_monthly';

  void Function(bool isPremium, String? error)? onStatusChanged;

  Future<void> initialize();
  Future<void> buyMonthlyPremium();
  Future<void> restorePurchases();
  void dispose();
}

class RealPurchaseService implements PurchaseService {
  @override
  void Function(bool isPremium, String? error)? onStatusChanged;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      onStatusChanged?.call(false, 'Satın alma kullanılamıyor.');
      return;
    }

    _sub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchases,
      onError: (_) => onStatusChanged?.call(false, 'Satın alma hatası.'),
    );

    await _restoreAndCheck();
  }

  Future<void> _restoreAndCheck() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      // No active subscription — free tier
    }
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != PurchaseService.premiumMonthlyProductId) {
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchase);
        }
        onStatusChanged?.call(true, null);
      } else if (purchase.status == PurchaseStatus.error) {
        final msg = purchase.error?.message ?? 'Bilinmeyen hata.';
        onStatusChanged?.call(false, msg);
      } else if (purchase.status == PurchaseStatus.canceled) {
        onStatusChanged?.call(false, null);
      }
    }
  }

  @override
  Future<void> buyMonthlyPremium() async {
    final response = await InAppPurchase.instance.queryProductDetails(
      {PurchaseService.premiumMonthlyProductId},
    );

    if (response.notFoundIDs.isNotEmpty) {
      onStatusChanged?.call(false, 'Ürün bulunamadı.');
      return;
    }

    final product = response.productDetails.first;
    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

class FakePurchaseService implements PurchaseService {
  FakePurchaseService({bool startPremium = false})
    : _isPremium = startPremium;

  bool _isPremium;
  bool initialized = false;
  int buyCallCount = 0;
  int restoreCallCount = 0;
  String? nextBuyError;

  @override
  void Function(bool isPremium, String? error)? onStatusChanged;

  @override
  Future<void> initialize() async {
    initialized = true;
    onStatusChanged?.call(_isPremium, null);
  }

  void simulatePurchaseSuccess() {
    _isPremium = true;
    onStatusChanged?.call(true, null);
  }

  void simulatePurchaseExpiry() {
    _isPremium = false;
    onStatusChanged?.call(false, null);
  }

  @override
  Future<void> buyMonthlyPremium() async {
    buyCallCount++;
    if (nextBuyError != null) {
      onStatusChanged?.call(false, nextBuyError);
      nextBuyError = null;
      return;
    }
    simulatePurchaseSuccess();
  }

  @override
  Future<void> restorePurchases() async {
    restoreCallCount++;
    onStatusChanged?.call(_isPremium, null);
  }

  @override
  void dispose() {}
}
