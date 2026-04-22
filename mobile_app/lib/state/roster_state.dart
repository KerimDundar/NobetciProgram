import 'package:flutter/foundation.dart';

import '../models/roster_row.dart';
import '../models/week.dart';
import '../services/export_snapshot_service.dart';
import '../services/roster_service.dart';
import '../services/week_service.dart';

class RosterState extends ChangeNotifier {
  RosterState({
    required Week currentWeek,
    WeekService? weekService,
    RosterService? rosterService,
    ExportSnapshotService? exportSnapshotService,
  }) : _currentWeek = currentWeek,
       _rosterService = rosterService ?? const RosterService(),
       _exportSnapshotService =
           exportSnapshotService ?? const ExportSnapshotService(),
       _weekService = weekService ?? WeekService(rosterService: rosterService);

  final WeekService _weekService;
  final RosterService _rosterService;
  final ExportSnapshotService _exportSnapshotService;
  Week _currentWeek;

  Week get currentWeek => _currentWeek;
  ExportSnapshot get exportSnapshot =>
      _exportSnapshotService.fromCurrentWeek(_currentWeek);

  factory RosterState.initial() {
    final weekService = WeekService();
    final startDate = DateTime(2026, 2, 2);
    final endDate = DateTime(2026, 2, 6);
    final rows = [
      RosterRow(
        location: 'Bahçe',
        teachersByDay: ['Ali Yılmaz', 'Ayşe Demir', '', 'Mehmet Kaya', ''],
      ),
      RosterRow(
        location: 'Koridor',
        teachersByDay: ['Fatma Şahin', '', 'Can Aydın', '', 'Zeynep Arslan'],
      ),
      RosterRow(
        location: 'Kantin',
        teachersByDay: ['', 'Burak Çelik', 'Elif Koç', '', ''],
      ),
    ];

    return RosterState(
      weekService: weekService,
      rosterService: const RosterService(),
      currentWeek: weekService.buildWeek(
        startDate: startDate,
        endDate: endDate,
        rows: rows,
        schoolName: 'Örnek Okul',
        principalName: 'Müdür',
      ),
    );
  }

  void goToNextWeek() {
    _currentWeek = _weekService.nextWeek(_currentWeek);
    notifyListeners();
  }

  void goToPreviousWeek() {
    _currentWeek = _weekService.previousWeek(_currentWeek);
    notifyListeners();
  }

  List<RosterRow> rotateRowsForward(List<RosterRow> rows) {
    return _rosterService.rotateForward(rows);
  }

  List<RosterRow> rotateRowsBackward(List<RosterRow> rows) {
    return _rosterService.rotateBackward(rows);
  }

  String? saveWeekDraft({
    required DateTime startDate,
    required DateTime endDate,
    required String schoolName,
    required String principalName,
    required List<RosterRow> rows,
  }) {
    if (startDate.isAfter(endDate)) {
      return 'Başlangıç tarihi bitiş tarihinden büyük olamaz.';
    }

    try {
      final preparedRows = _rosterService.prepareRowsForSave(rows);
      _currentWeek = _weekService.buildWeek(
        startDate: startDate,
        endDate: endDate,
        rows: preparedRows,
        schoolName: schoolName,
        principalName: principalName,
      );
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
}
