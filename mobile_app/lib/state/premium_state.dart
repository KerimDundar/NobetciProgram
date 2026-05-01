import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/purchase_service.dart';

class PremiumState extends ChangeNotifier {
  PremiumState({required PurchaseService purchaseService})
    : _purchaseService = purchaseService;

  final PurchaseService _purchaseService;
  static const String _storageKey = 'premium_state_v1';

  bool _isPremium = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    await _loadCached();
    _purchaseService.onStatusChanged = _onStatusChanged;
    await _purchaseService.initialize();
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _isPremium = (data['isPremium'] as bool?) ?? false;
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({'isPremium': _isPremium}),
      );
    } catch (_) {}
  }

  void _onStatusChanged(bool isPremium, String? error) {
    _isPremium = isPremium;
    _isLoading = false;
    _errorMessage = error;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> buyPremium() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _purchaseService.buyMonthlyPremium();
  }

  Future<void> restorePurchases() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _purchaseService.restorePurchases();
    if (_isLoading) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }
}
