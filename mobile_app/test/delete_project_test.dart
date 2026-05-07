import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/models/planning_mode.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/projects_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RosterState.deleteProject — unit testler', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('proje listesinden kaldırır', () {
      final state = RosterState.blank();
      final id = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      expect(state.projects.length, 1);
      state.deleteProject(id);
      expect(state.projects, isEmpty);
    });

    test('aktif olmayan proje silinince activeProjectId değişmez', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.openProject(id1);
      state.deleteProject(id2);
      expect(state.hasActiveRoster, isTrue);
      expect(state.projects.length, 1);
      expect(state.projects.first.id, id1);
    });

    test('aktif proje silinince başka projeye geçer', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.openProject(id2);
      state.deleteProject(id2);
      expect(state.hasActiveRoster, isTrue);
      expect(state.projects.length, 1);
      expect(state.projects.first.id, id1);
    });

    test('son proje silinince projects boş ve hasActiveRoster false olur', () {
      final state = RosterState.blank();
      final id = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      state.deleteProject(id);
      expect(state.projects, isEmpty);
      expect(state.hasActiveRoster, isFalse);
    });

    test('freeProjectId olan proje silinince freeProjectId null olur', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.setFreeProjectId(id1);
      expect(state.freeProjectId, id1);
      state.deleteProject(id1);
      expect(state.freeProjectId, isNull);
      expect(state.projects.any((p) => p.id == id2), isTrue);
    });

    test('freeProjectId olmayan proje silinince freeProjectId korunur', () {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      final id2 = state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.setFreeProjectId(id1);
      state.deleteProject(id2);
      expect(state.freeProjectId, id1);
    });

    test('notifyListeners tetiklenir', () {
      final state = RosterState.blank();
      final id = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      var notified = false;
      state.addListener(() => notified = true);
      state.deleteProject(id);
      expect(notified, isTrue);
    });

    test('var olmayan id silinince liste değişmez', () {
      final state = RosterState.blank();
      state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      state.deleteProject('olmayan_id');
      expect(state.projects.length, 1);
    });

    test('persistence sonrası silinen proje geri gelmez', () async {
      final state = RosterState.blank();
      final id1 = state.createProject(name: 'P1', planningMode: PlanningMode.weekly);
      state.createProject(name: 'P2', planningMode: PlanningMode.weekly);
      state.deleteProject(id1);
      await state.persistState();

      final state2 = RosterState.blank();
      await state2.load();
      expect(state2.projects.any((p) => p.id == id1), isFalse);
      expect(state2.projects.length, 1);
      expect(state2.projects.first.name, 'P2');
    });
  });

  group('ProjectsScreen silme — widget testler', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('proje kartında silme butonu görünür', (tester) async {
      final state = RosterState.blank();
      state.createProject(name: 'Test Proje', planningMode: PlanningMode.weekly);
      await tester.pumpWidget(
        MaterialApp(home: ProjectsScreen(rosterState: state)),
      );
      expect(find.byKey(const Key('projects-delete-button')), findsOneWidget);
    });

    testWidgets('silme butonuna basınca onay dialogu açılır', (tester) async {
      final state = RosterState.blank();
      state.createProject(name: 'Sil Beni', planningMode: PlanningMode.weekly);
      await tester.pumpWidget(
        MaterialApp(home: ProjectsScreen(rosterState: state)),
      );
      await tester.tap(find.byKey(const Key('projects-delete-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Projeyi sil'), findsOneWidget);
      expect(find.text('"Sil Beni" projesini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'), findsOneWidget);
    });

    testWidgets('İptal butonuna basınca proje silinmez', (tester) async {
      final state = RosterState.blank();
      state.createProject(name: 'Kalacak', planningMode: PlanningMode.weekly);
      await tester.pumpWidget(
        MaterialApp(home: ProjectsScreen(rosterState: state)),
      );
      await tester.tap(find.byKey(const Key('projects-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-delete-cancel')));
      await tester.pumpAndSettle();
      expect(state.projects.length, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Sil butonuna basınca proje kalkar ve snackbar gösterilir',
        (tester) async {
      final state = RosterState.blank();
      state.createProject(name: 'Silinecek', planningMode: PlanningMode.weekly);
      await tester.pumpWidget(
        MaterialApp(home: ProjectsScreen(rosterState: state)),
      );
      await tester.tap(find.byKey(const Key('projects-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-delete-confirm')));
      await tester.pumpAndSettle();
      expect(state.projects, isEmpty);
      expect(find.text('Proje silindi.'), findsOneWidget);
    });

    testWidgets('son proje silinince empty state görünür', (tester) async {
      final state = RosterState.blank();
      state.createProject(name: 'Son Proje', planningMode: PlanningMode.weekly);
      await tester.pumpWidget(
        MaterialApp(home: ProjectsScreen(rosterState: state)),
      );
      await tester.tap(find.byKey(const Key('projects-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('projects-create-button')), findsOneWidget);
    });

    testWidgets('çoklu projede bir proje silinince diğerleri kalır', (tester) async {
      final state = RosterState.blank();
      state.createProject(name: 'Proje A', planningMode: PlanningMode.weekly);
      state.createProject(name: 'Proje B', planningMode: PlanningMode.weekly);
      await tester.pumpWidget(
        MaterialApp(home: ProjectsScreen(rosterState: state)),
      );
      expect(find.text('Proje A'), findsOneWidget);
      expect(find.text('Proje B'), findsOneWidget);
      // Sil butonlarından ilkine bas (Proje A)
      await tester.tap(find.byKey(const Key('projects-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-delete-confirm')));
      await tester.pumpAndSettle();
      expect(state.projects.length, 1);
      expect(find.text('Proje A'), findsNothing);
      expect(find.text('Proje B'), findsOneWidget);
    });

    testWidgets('silme işlemi premium paywall açmaz (gate kapalı)', (tester) async {
      final state = RosterState.blank();
      state.createProject(name: 'Proje', planningMode: PlanningMode.weekly);
      await tester.pumpWidget(
        MaterialApp(home: ProjectsScreen(rosterState: state)),
      );
      await tester.tap(find.byKey(const Key('projects-delete-button')));
      await tester.pumpAndSettle();
      // Sadece onay dialogu açılmalı, premium paywall değil
      expect(find.text('Projeyi sil'), findsOneWidget);
      expect(find.text('Premium Ol'), findsNothing);
    });
  });
}
