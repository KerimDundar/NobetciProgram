import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/services/purchase_service.dart';
import 'package:nobetci_program_mobile/state/premium_state.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakePurchaseService', () {
    test('initialize calls onStatusChanged with current premium status', () async {
      final svc = FakePurchaseService(startPremium: false);
      bool? received;
      svc.onStatusChanged = (isPremium, _) => received = isPremium;
      await svc.initialize();
      expect(svc.initialized, isTrue);
      expect(received, isFalse);
    });

    test('startPremium=true reports isPremium=true on initialize', () async {
      final svc = FakePurchaseService(startPremium: true);
      bool? received;
      svc.onStatusChanged = (isPremium, _) => received = isPremium;
      await svc.initialize();
      expect(received, isTrue);
    });

    test('buyMonthlyPremium calls onStatusChanged with isPremium=true', () async {
      final svc = FakePurchaseService();
      bool? received;
      svc.onStatusChanged = (isPremium, _) => received = isPremium;
      await svc.buyMonthlyPremium();
      expect(received, isTrue);
      expect(svc.buyCallCount, 1);
    });

    test('buyMonthlyPremium with nextBuyError reports error', () async {
      final svc = FakePurchaseService();
      String? receivedError;
      bool? receivedPremium;
      svc.onStatusChanged = (isPremium, error) {
        receivedPremium = isPremium;
        receivedError = error;
      };
      svc.nextBuyError = 'Ödeme başarısız';
      await svc.buyMonthlyPremium();
      expect(receivedPremium, isFalse);
      expect(receivedError, 'Ödeme başarısız');
    });

    test('restorePurchases increments restoreCallCount', () async {
      final svc = FakePurchaseService(startPremium: true);
      await svc.initialize();
      await svc.restorePurchases();
      expect(svc.restoreCallCount, 1);
    });

    test('simulatePurchaseExpiry calls onStatusChanged with isPremium=false', () async {
      final svc = FakePurchaseService(startPremium: true);
      bool? received;
      svc.onStatusChanged = (isPremium, _) => received = isPremium;
      svc.simulatePurchaseExpiry();
      expect(received, isFalse);
    });
  });

  group('PremiumState', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isPremium=false initially', () {
      final state = PremiumState(purchaseService: FakePurchaseService());
      expect(state.isPremium, isFalse);
    });

    test('initialize with premium service sets isPremium=true', () async {
      final state = PremiumState(
        purchaseService: FakePurchaseService(startPremium: true),
      );
      await state.initialize();
      expect(state.isPremium, isTrue);
    });

    test('buyPremium sets isPremium=true', () async {
      final state = PremiumState(purchaseService: FakePurchaseService());
      await state.initialize();
      await state.buyPremium();
      expect(state.isPremium, isTrue);
    });

    test('buyPremium with error sets errorMessage', () async {
      final svc = FakePurchaseService();
      svc.nextBuyError = 'Hata mesajı';
      final state = PremiumState(purchaseService: svc);
      await state.initialize();
      await state.buyPremium();
      expect(state.isPremium, isFalse);
      expect(state.errorMessage, 'Hata mesajı');
    });

    test('clearError removes errorMessage', () async {
      final svc = FakePurchaseService();
      svc.nextBuyError = 'Hata';
      final state = PremiumState(purchaseService: svc);
      await state.initialize();
      await state.buyPremium();
      expect(state.errorMessage, isNotNull);
      state.clearError();
      expect(state.errorMessage, isNull);
    });

    test('restorePurchases updates isPremium', () async {
      final svc = FakePurchaseService(startPremium: true);
      final state = PremiumState(purchaseService: svc);
      await state.initialize();
      expect(state.isPremium, isTrue);
      svc.simulatePurchaseExpiry();
      expect(state.isPremium, isFalse);
    });

    test('notifies listeners on status change', () async {
      final state = PremiumState(purchaseService: FakePurchaseService());
      await state.initialize();
      var notified = false;
      state.addListener(() => notified = true);
      await state.buyPremium();
      expect(notified, isTrue);
    });
  });

  group('RosterState premium access', () {
    RosterState makeState() => RosterState.blank();

    test('canCreateProject: free tier, no projects → true', () {
      final state = makeState();
      expect(state.canCreateProject(false), isTrue);
    });

    test('canCreateProject: free tier, 1 project → false', () {
      final state = makeState();
      state.createProject(name: 'P1', planningMode: state.activePlanningMode);
      expect(state.canCreateProject(false), isFalse);
    });

    test('canCreateProject: premium, many projects → true', () {
      final state = makeState();
      state.createProject(name: 'P1', planningMode: state.activePlanningMode);
      state.createProject(name: 'P2', planningMode: state.activePlanningMode);
      expect(state.canCreateProject(true), isTrue);
    });

    test('canAccessProject: single project always accessible for free', () {
      final state = makeState();
      final id = state.createProject(
        name: 'P1',
        planningMode: state.activePlanningMode,
      );
      expect(state.canAccessProject(id, false), isTrue);
    });

    test('canAccessProject: free tier, 2 projects, only freeProjectId accessible', () {
      final state = makeState();
      final id1 = state.createProject(
        name: 'P1',
        planningMode: state.activePlanningMode,
      );
      final id2 = state.createProject(
        name: 'P2',
        planningMode: state.activePlanningMode,
      );
      state.setFreeProjectId(id1);
      expect(state.canAccessProject(id1, false), isTrue);
      expect(state.canAccessProject(id2, false), isFalse);
    });

    test('canAccessProject: premium ignores freeProjectId', () {
      final state = makeState();
      final id1 = state.createProject(
        name: 'P1',
        planningMode: state.activePlanningMode,
      );
      final id2 = state.createProject(
        name: 'P2',
        planningMode: state.activePlanningMode,
      );
      state.setFreeProjectId(id1);
      expect(state.canAccessProject(id2, true), isTrue);
    });

    test('isActiveProjectAccessible reflects active project lock status', () {
      final state = makeState();
      final id1 = state.createProject(
        name: 'P1',
        planningMode: state.activePlanningMode,
      );
      final id2 = state.createProject(
        name: 'P2',
        planningMode: state.activePlanningMode,
      );
      state.setFreeProjectId(id1);
      state.openProject(id2);
      expect(state.isActiveProjectAccessible(false), isFalse);
      state.openProject(id1);
      expect(state.isActiveProjectAccessible(false), isTrue);
    });

    test('setFreeProjectId persists and is readable', () {
      final state = makeState();
      final id = state.createProject(
        name: 'P1',
        planningMode: state.activePlanningMode,
      );
      expect(state.freeProjectId, isNull);
      state.setFreeProjectId(id);
      expect(state.freeProjectId, id);
    });
  });
}
