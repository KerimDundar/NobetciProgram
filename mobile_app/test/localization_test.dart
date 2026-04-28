import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/state/app_settings_state.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/welcome_screen.dart';
import 'package:nobetci_program_mobile/ui/theme/app_theme.dart';

Widget _buildApp() {
  SharedPreferences.setMockInitialValues({});
  return MaterialApp(
    theme: AppTheme.build(),
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: WelcomeScreen(
      rosterState: RosterState.initial(),
      appSettingsState: AppSettingsState(),
    ),
  );
}

void main() {
  group('Lokalizasyon konfigürasyonu', () {
    testWidgets('MaterialApp locale tr-TR olarak ayarlı', (tester) async {
      await tester.pumpWidget(_buildApp());
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.locale, const Locale('tr', 'TR'));
    });

    testWidgets('MaterialApp supportedLocales tr-TR içeriyor', (tester) async {
      await tester.pumpWidget(_buildApp());
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        materialApp.supportedLocales,
        contains(const Locale('tr', 'TR')),
      );
    });

    testWidgets('MaterialApp GlobalMaterialLocalizations delegate içeriyor',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final delegates = materialApp.localizationsDelegates!.toList();
      expect(
        delegates,
        contains(GlobalMaterialLocalizations.delegate),
      );
    });

    testWidgets('MaterialApp GlobalWidgetsLocalizations delegate içeriyor',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final delegates = materialApp.localizationsDelegates!.toList();
      expect(
        delegates,
        contains(GlobalWidgetsLocalizations.delegate),
      );
    });

    testWidgets('MaterialApp GlobalCupertinoLocalizations delegate içeriyor',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final delegates = materialApp.localizationsDelegates!.toList();
      expect(
        delegates,
        contains(GlobalCupertinoLocalizations.delegate),
      );
    });
  });
}
