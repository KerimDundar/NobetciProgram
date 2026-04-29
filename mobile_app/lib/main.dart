import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_settings_state.dart';
import 'state/roster_state.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const NobetciProgramApp());
}

class NobetciProgramApp extends StatefulWidget {
  const NobetciProgramApp({super.key});

  @override
  State<NobetciProgramApp> createState() => _NobetciProgramAppState();
}

class _NobetciProgramAppState extends State<NobetciProgramApp> {
  late final RosterState _rosterState = RosterState.blank();
  late final AppSettingsState _appSettingsState = AppSettingsState();

  @override
  void initState() {
    super.initState();
    _appSettingsState.load();
    _rosterState.load();
  }

  @override
  void dispose() {
    _appSettingsState.dispose();
    _rosterState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nobetci Program',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: WelcomeScreen(
        rosterState: _rosterState,
        appSettingsState: _appSettingsState,
      ),
    );
  }
}
