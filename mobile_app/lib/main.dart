import 'package:flutter/material.dart';

import 'services/local_teacher_repository.dart';
import 'state/app_settings_state.dart';
import 'state/roster_state.dart';
import 'state/teacher_state.dart';
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
  late final RosterState _rosterState = RosterState.initial();
  late final TeacherState _teacherState = TeacherState(
    repository: LocalTeacherRepository(),
  );
  late final AppSettingsState _appSettingsState = AppSettingsState();

  @override
  void initState() {
    super.initState();
    _appSettingsState.load();
  }

  @override
  void dispose() {
    _appSettingsState.dispose();
    _teacherState.dispose();
    _rosterState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nobetci Program',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: WelcomeScreen(
        rosterState: _rosterState,
        teacherState: _teacherState,
        appSettingsState: _appSettingsState,
      ),
    );
  }
}
