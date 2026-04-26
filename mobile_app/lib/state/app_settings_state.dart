import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planning_mode.dart';

class AppSettingsState extends ChangeNotifier {
  static const _modeKey = 'planning_mode';

  PlanningMode _mode = PlanningMode.weekly;

  PlanningMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_modeKey);
    _mode = stored == PlanningMode.monthly.name
        ? PlanningMode.monthly
        : PlanningMode.weekly;
    notifyListeners();
  }

  Future<void> setMode(PlanningMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}
