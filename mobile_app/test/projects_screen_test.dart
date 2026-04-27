import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/services/week_service.dart';
import 'package:nobetci_program_mobile/state/app_settings_state.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/edit_week_screen.dart';
import 'package:nobetci_program_mobile/ui/screens/projects_screen.dart';
import 'package:nobetci_program_mobile/ui/screens/roster_home_screen.dart';
import 'package:nobetci_program_mobile/ui/theme/app_theme.dart';

void _useTallTestView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1080, 2200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildProjects({RosterState? state, AppSettingsState? appSettings}) {
  SharedPreferences.setMockInitialValues({});
  return MaterialApp(
    theme: AppTheme.build(),
    home: ProjectsScreen(
      rosterState: state ?? RosterState.blank(),
      appSettingsState: appSettings,
    ),
  );
}

Future<void> _fillAndSubmitDialog(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('new-project-name-field')), name);
  await tester.tap(find.byKey(const Key('new-project-create')));
  await tester.pumpAndSettle();
}

void main() {
  group('ProjectsScreen', () {
    testWidgets('proje yoksa boş durum metni görünür', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      expect(find.text('Henüz çizelge oluşturulmadı.'), findsOneWidget);
      expect(
        find.text('İlk nöbet çizelgenizi oluşturmak için başlayın.'),
        findsOneWidget,
      );
    });

    testWidgets('Yeni çizelge oluştur butonu görünür (boş durum)',
        (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      expect(
        find.byKey(const Key('projects-create-button')),
        findsOneWidget,
      );
    });

    testWidgets('FAB her zaman görünür (boş durum)', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      expect(find.byKey(const Key('projects-new-button')), findsOneWidget);
    });

    testWidgets('FAB proje varken de görünür', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects(state: RosterState.initial()));
      expect(find.byKey(const Key('projects-new-button')), findsOneWidget);
    });

    testWidgets('Yeni çizelge oluştur butonu dialog açar', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      await tester.tap(find.byKey(const Key('projects-create-button')));
      await tester.pumpAndSettle();
      expect(find.text('Yeni proje oluştur'), findsOneWidget);
      expect(find.byKey(const Key('new-project-name-field')), findsOneWidget);
    });

    testWidgets('FAB dialog açar', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      await tester.tap(find.byKey(const Key('projects-new-button')));
      await tester.pumpAndSettle();
      expect(find.text('Yeni proje oluştur'), findsOneWidget);
    });

    testWidgets('boş proje adı hata gösterir', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      await tester.tap(find.byKey(const Key('projects-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-project-create')));
      await tester.pumpAndSettle();
      expect(find.text('Proje adı boş bırakılamaz.'), findsOneWidget);
    });

    testWidgets('İptal dialog kapatır', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      await tester.tap(find.byKey(const Key('projects-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-project-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Yeni proje oluştur'), findsNothing);
    });

    testWidgets('dialog onaylayınca EditWeekScreen açılır', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects());
      await tester.tap(find.byKey(const Key('projects-create-button')));
      await tester.pumpAndSettle();
      await _fillAndSubmitDialog(tester, 'Test Projesi');
      expect(find.text('Hafta Düzenle'), findsOneWidget);
    });

    testWidgets('EditWeekScreen kaydet sonrası hasActiveRoster true olur',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.blank();
      expect(state.hasActiveRoster, false);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: EditWeekScreen(state: state),
      ));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(state.hasActiveRoster, true);
    });

    testWidgets('EditWeekScreen kaydet sonrası RosterHomeScreen açılır',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.blank();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: ProjectsScreen(rosterState: state),
      ));
      await tester.tap(find.byKey(const Key('projects-create-button')));
      await tester.pumpAndSettle();
      await _fillAndSubmitDialog(tester, 'Okulum');
      expect(find.text('Hafta Düzenle'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.byType(RosterHomeScreen), findsOneWidget);
    });

    testWidgets('proje varsa kart gösterilir', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects(state: RosterState.initial()));
      expect(find.byKey(const Key('projects-roster-card')), findsOneWidget);
      expect(find.text('Henüz çizelge oluşturulmadı.'), findsNothing);
    });

    testWidgets('haftalık kart plan etiketi görünür', (tester) async {
      _useTallTestView(tester);
      SharedPreferences.setMockInitialValues({});
      final appSettings = AppSettingsState();
      await tester.pumpWidget(
        _buildProjects(
          state: RosterState.initial(),
          appSettings: appSettings,
        ),
      );
      expect(find.text('Haftalık Plan'), findsOneWidget);
    });

    testWidgets('aylık kart plan etiketi görünür', (tester) async {
      _useTallTestView(tester);
      SharedPreferences.setMockInitialValues({'planning_mode': 'monthly'});
      final appSettings = AppSettingsState();
      await appSettings.load();
      await tester.pumpWidget(
        _buildProjects(
          state: RosterState.initial(),
          appSettings: appSettings,
        ),
      );
      await tester.pump();
      expect(find.text('Aylık Plan'), findsOneWidget);
    });

    testWidgets('aylık kart tarih aralığı tam ay gösterir (Nisan)',
        (tester) async {
      _useTallTestView(tester);
      SharedPreferences.setMockInitialValues({'planning_mode': 'monthly'});
      final appSettings = AppSettingsState();
      await appSettings.load();
      final svc = WeekService();
      final state = RosterState(
        currentWeek: svc.buildWeek(
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 30),
          rows: const [],
          schoolName: '',
          principalName: '',
        ),
        hasActiveRoster: true,
      );
      await tester.pumpWidget(
        _buildProjects(state: state, appSettings: appSettings),
      );
      await tester.pump();
      expect(find.text('01 Nisan - 30 Nisan 2026'), findsOneWidget);
      expect(find.text('21 Mayıs 2026'), findsNothing);
    });

    testWidgets('aylık kart tarih aralığı tam ay gösterir (Şubat normal)',
        (tester) async {
      _useTallTestView(tester);
      SharedPreferences.setMockInitialValues({'planning_mode': 'monthly'});
      final appSettings = AppSettingsState();
      await appSettings.load();
      final svc = WeekService();
      final state = RosterState(
        currentWeek: svc.buildWeek(
          startDate: DateTime(2026, 2, 1),
          endDate: DateTime(2026, 2, 28),
          rows: const [],
          schoolName: '',
          principalName: '',
        ),
        hasActiveRoster: true,
      );
      await tester.pumpWidget(
        _buildProjects(state: state, appSettings: appSettings),
      );
      await tester.pump();
      expect(find.text('01 Şubat - 28 Şubat 2026'), findsOneWidget);
    });

    testWidgets('aylık kart tarih aralığı tam ay gösterir (Şubat artık yıl)',
        (tester) async {
      _useTallTestView(tester);
      SharedPreferences.setMockInitialValues({'planning_mode': 'monthly'});
      final appSettings = AppSettingsState();
      await appSettings.load();
      final svc = WeekService();
      final state = RosterState(
        currentWeek: svc.buildWeek(
          startDate: DateTime(2028, 2, 1),
          endDate: DateTime(2028, 2, 29),
          rows: const [],
          schoolName: '',
          principalName: '',
        ),
        hasActiveRoster: true,
      );
      await tester.pumpWidget(
        _buildProjects(state: state, appSettings: appSettings),
      );
      await tester.pump();
      expect(find.text('01 Şubat - 29 Şubat 2028'), findsOneWidget);
    });

    testWidgets('haftalık kart tarih aralığı görünür', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(_buildProjects(state: RosterState.initial()));
      expect(find.text('02 Şubat - 06 Şubat 2026'), findsOneWidget);
    });

    testWidgets('aylık proje oluşturulunca default tarih bulunulan ay olur',
        (tester) async {
      _useTallTestView(tester);
      SharedPreferences.setMockInitialValues({});
      final state = RosterState.blank();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: ProjectsScreen(rosterState: state),
      ));
      await tester.tap(find.byKey(const Key('projects-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aylık'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('new-project-name-field')), 'Test');
      await tester.tap(find.byKey(const Key('new-project-create')));
      await tester.pumpAndSettle();

      final svc = WeekService();
      final now = DateTime.now();
      final start = svc.monthStart(now);
      String fmt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
      expect(find.text('Başlangıç ${fmt(start)}'), findsOneWidget);
    });

    testWidgets('kart tıklaması önceki ekrana döner', (tester) async {
      _useTallTestView(tester);
      SharedPreferences.setMockInitialValues({});
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: RosterHomeScreen(state: state),
      ));
      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-projects')));
      await tester.pumpAndSettle();
      expect(find.text('Çizelgelerim'), findsOneWidget);
      await tester.tap(find.byKey(const Key('projects-roster-card')));
      await tester.pumpAndSettle();
      expect(find.text('Çizelgelerim'), findsNothing);
    });
  });
}
