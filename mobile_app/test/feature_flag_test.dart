import 'package:flutter_test/flutter_test.dart';

import 'package:nobetci_program_mobile/config/feature_flags.dart';
import 'package:nobetci_program_mobile/models/planning_mode.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeatureFlags.premiumGateEnabled = false (test branch)', () {
    test('flag value is false', () {
      expect(FeatureFlags.premiumGateEnabled, isFalse);
    });

    test('canCreateProject: free tier, 1 existing project — would block without flag', () {
      final state = RosterState.blank();
      state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      // Without flag: canCreateProject(false) → false → blocked
      expect(state.canCreateProject(false), isFalse);
      // But with flag disabled, the gate check is skipped in UI — modelled here:
      final gateWouldBlock = FeatureFlags.premiumGateEnabled &&
          !state.canCreateProject(false);
      expect(gateWouldBlock, isFalse);
    });

    test('canCreateProject: free tier, 2 existing projects — gate skipped by flag', () {
      final state = RosterState.blank();
      state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      final gateWouldBlock = FeatureFlags.premiumGateEnabled &&
          !state.canCreateProject(false);
      expect(gateWouldBlock, isFalse);
    });

    test('isLocked: free tier, locked project — flag disables lock', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.setFreeProjectId(id1);

      // canAccessProject would return false for id2 in free tier
      expect(state.canAccessProject(id2, false), isFalse);

      // But isLocked = flag && !canAccess → false when flag is off
      final isLocked = FeatureFlags.premiumGateEnabled &&
          !state.canAccessProject(id2, false);
      expect(isLocked, isFalse);
    });

    test('isLocked: all projects appear unlocked when flag is off', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      final id3 = state.createProject(name: 'P3', planningMode: PlanningMode.weekly);
      state.setFreeProjectId(id1);

      for (final id in [id1, id2, id3]) {
        final isLocked = FeatureFlags.premiumGateEnabled &&
            !state.canAccessProject(id, false);
        expect(isLocked, isFalse, reason: 'Project $id should not be locked');
      }
    });

    test('paywall not triggered on project create when flag is off', () {
      final state = RosterState.blank();
      state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      // Simulate UI decision: show paywall?
      final showPaywall = FeatureFlags.premiumGateEnabled &&
          !state.canCreateProject(false);
      expect(showPaywall, isFalse);
    });

    test('paywall not triggered on project open when flag is off', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.setFreeProjectId(id1);

      // isLocked=false when flag off → paywall not shown
      final isLocked = FeatureFlags.premiumGateEnabled &&
          !state.canAccessProject(id2, false);
      expect(isLocked, isFalse);
    });

    test('PDF export: gate off → always uses ad path (premium=false)', () {
      // premiumGateEnabled=false → always interstitial regardless of premium
      const isPremium = false;
      final usesAdPath = !FeatureFlags.premiumGateEnabled ||
          (!isPremium);
      expect(usesAdPath, isTrue);
    });

    test('PDF export: gate off → always uses ad path (premium=true)', () {
      // Even if someone has premium, gate off means ad path used
      const isPremium = true;
      final skipAd = FeatureFlags.premiumGateEnabled && isPremium;
      expect(skipAd, isFalse);
    });
  });

  group('FeatureFlags.premiumGateEnabled = true simulation (production)', () {
    test('gate enabled: canCreateProject false blocks creation', () {
      final state = RosterState.blank();
      state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      // Simulating flag=true: check gate directly
      final gateWouldBlock = !state.canCreateProject(false);
      expect(gateWouldBlock, isTrue);
    });

    test('gate enabled: locked project blocks access', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.setFreeProjectId(id1);
      expect(state.canAccessProject(id2, false), isFalse);
    });

    test('gate enabled: premium=true unlocks everything', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.setFreeProjectId(id1);
      expect(state.canAccessProject(id2, true), isTrue);
      expect(state.canCreateProject(true), isTrue);
    });

    test('gate enabled: premium=true PDF export skips ad', () {
      const isPremium = true;
      // When gate enabled, premium skips ad
      final skipAd = isPremium; // FeatureFlags.premiumGateEnabled && isPremium
      expect(skipAd, isTrue);
    });
  });
}
