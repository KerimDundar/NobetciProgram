import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/state/app_settings_state.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/welcome_screen.dart';
import 'package:nobetci_program_mobile/ui/screens/projects_screen.dart';
import 'package:nobetci_program_mobile/ui/theme/app_theme.dart';

Widget _buildWelcome() {
  SharedPreferences.setMockInitialValues({});
  return MaterialApp(
    theme: AppTheme.build(),
    home: WelcomeScreen(
      rosterState: RosterState.initial(),
      appSettingsState: AppSettingsState(),
    ),
  );
}

void main() {
  group('WelcomeScreen', () {
    testWidgets('HOŞ GELDİNİZ metni görünür', (tester) async {
      await tester.pumpWidget(_buildWelcome());
      expect(find.text('HOŞ GELDİNİZ'), findsOneWidget);
    });

    testWidgets('Nöbet Çizelgesi başlığı görünür', (tester) async {
      await tester.pumpWidget(_buildWelcome());
      expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    });

    testWidgets('Başla butonu görünür', (tester) async {
      await tester.pumpWidget(_buildWelcome());
      expect(find.byKey(const Key('welcome-start-button')), findsOneWidget);
    });

    testWidgets('özellik chip\'leri görünür', (tester) async {
      await tester.pumpWidget(_buildWelcome());
      expect(find.text('Haftalık Plan'), findsOneWidget);
      expect(find.text('PDF Çıktı'), findsOneWidget);
      expect(find.text('Excel Aktarım'), findsOneWidget);
    });

    testWidgets('başla butonuna tıklayınca ProjectsScreen açılır',
        (tester) async {
      await tester.pumpWidget(_buildWelcome());
      await tester.tap(find.byKey(const Key('welcome-start-button')));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsScreen), findsOneWidget);
    });
  });
}
