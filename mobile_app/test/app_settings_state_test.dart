import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/models/planning_mode.dart';
import 'package:nobetci_program_mobile/state/app_settings_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default mode is weekly', () {
    final state = AppSettingsState();
    expect(state.mode, PlanningMode.weekly);
  });

  test('setMode(monthly) changes mode to monthly', () async {
    final state = AppSettingsState();
    await state.setMode(PlanningMode.monthly);
    expect(state.mode, PlanningMode.monthly);
  });

  test('load() restores persisted mode', () async {
    final writer = AppSettingsState();
    await writer.setMode(PlanningMode.monthly);

    final reader = AppSettingsState();
    await reader.load();
    expect(reader.mode, PlanningMode.monthly);
  });
}
