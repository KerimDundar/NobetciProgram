import 'package:flutter/material.dart';

import 'state/roster_state.dart';
import 'ui/screens/roster_home_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nobetci Program',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: RosterHomeScreen(state: _rosterState),
    );
  }
}
