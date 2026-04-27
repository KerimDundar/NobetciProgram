import 'package:flutter/foundation.dart';

import '../models/roster_row.dart';
import '../models/teacher.dart';
import '../services/cell_teacher_codec.dart';
import '../models/week.dart';
import '../services/export_snapshot_service.dart';
import '../services/roster_service.dart';
import '../services/teacher_service.dart';
import '../services/text_normalizer.dart';
import '../services/week_service.dart';

class RosterState extends ChangeNotifier {
  RosterState({
    required Week currentWeek,
    bool hasActiveRoster = false,
    String projectName = '',
    WeekService? weekService,
    RosterService? rosterService,
    TeacherService? teacherService,
    CellTeacherCodec? cellTeacherCodec,
    TextNormalizer? textNormalizer,
    ExportSnapshotService? exportSnapshotService,
  }) : _currentWeek = currentWeek,
       _hasActiveRoster = hasActiveRoster,
       _projectName = projectName,
       _rosterService = rosterService ?? const RosterService(),
       _teacherService = teacherService ?? TeacherService(),
       _cellTeacherCodec = cellTeacherCodec ?? const CellTeacherCodec(),
       _textNormalizer = textNormalizer ?? const TextNormalizer(),
       _exportSnapshotService =
           exportSnapshotService ?? const ExportSnapshotService(),
       _weekService = weekService ?? WeekService(rosterService: rosterService);

  final WeekService _weekService;
  final RosterService _rosterService;
  final TeacherService _teacherService;
  final CellTeacherCodec _cellTeacherCodec;
  final TextNormalizer _textNormalizer;
  final ExportSnapshotService _exportSnapshotService;
  static const String _multiTeacherLineBreakToken = r'\n';
  Week _currentWeek;
  bool _hasActiveRoster;
  String _projectName;
  RosterCellSelection? _selectedCell;
  List<Week>? _generatedMonthlyWeeks;

  Week get currentWeek => _currentWeek;
  bool get hasActiveRoster => _hasActiveRoster;
  String get projectName => _projectName;
  RosterCellSelection? get selectedCell => _selectedCell;
  List<Week>? get generatedMonthlyWeeks => _generatedMonthlyWeeks;
  List<Teacher> get teachers => _teacherService.all();
  ExportSnapshot get exportSnapshot {
    final monthly = _generatedMonthlyWeeks;
    if (monthly != null && monthly.isNotEmpty) {
      return _exportSnapshotService.fromPreviewWeeks(monthly);
    }
    return _exportSnapshotService.fromCurrentWeek(_currentWeek);
  }

  factory RosterState.blank() {
    final weekService = WeekService();
    return RosterState(
      weekService: weekService,
      currentWeek: weekService.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: const [],
        schoolName: '',
        principalName: '',
      ),
    );
  }

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
      teacherService: TeacherService(),
      hasActiveRoster: true,
      currentWeek: weekService.buildWeek(
        startDate: startDate,
        endDate: endDate,
        rows: rows,
        schoolName: 'Örnek Okul',
        principalName: 'Müdür',
      ),
    );
  }

  void setProjectMetadata({required String name}) {
    _projectName = name;
    notifyListeners();
  }

  void generateMonthlyWeeks() {
    _generatedMonthlyWeeks = _weekService.generateMonthlyFromWeek(_currentWeek);
    notifyListeners();
  }

  void goToNextWeek() {
    _currentWeek = _weekService.nextWeek(_currentWeek);
    notifyListeners();
  }

  void goToPreviousWeek() {
    _currentWeek = _weekService.previousWeek(_currentWeek);
    notifyListeners();
  }

  List<Teacher> searchTeachers({String? query, bool availableOnly = false}) {
    return _teacherService.search(query: query, availableOnly: availableOnly);
  }

  void selectCell({required int rowIndex, required int dayIndex}) {
    _selectedCell = RosterCellSelection(rowIndex: rowIndex, dayIndex: dayIndex);
    notifyListeners();
  }

  void clearSelectedCell() {
    _selectedCell = null;
    notifyListeners();
  }

  String? assignTeacherToCell({
    required int rowIndex,
    required int dayIndex,
    required String teacherName,
  }) {
    final rowError = _validateCellIndexes(
      rowIndex: rowIndex,
      dayIndex: dayIndex,
    );
    if (rowError != null) {
      return rowError;
    }

    final rows = _currentWeek.rows.toList(growable: true);
    final row = rows[rowIndex];
    final values = row.teachersByDay.toList(growable: true);
    values[dayIndex] = teacherName;
    rows[rowIndex] = row.copyWith(teachersByDay: values);
    _currentWeek = _currentWeek.copyWith(rows: rows);
    notifyListeners();
    return null;
  }

  String? clearTeacherFromCell({required int rowIndex, required int dayIndex}) {
    return assignTeacherToCell(
      rowIndex: rowIndex,
      dayIndex: dayIndex,
      teacherName: '',
    );
  }

  String? addTeacherToCell({
    required int rowIndex,
    required int dayIndex,
    required String teacherName,
  }) {
    final rowError = _validateCellIndexes(
      rowIndex: rowIndex,
      dayIndex: dayIndex,
    );
    if (rowError != null) {
      return rowError;
    }

    final rows = _currentWeek.rows.toList(growable: true);
    final row = rows[rowIndex];
    final values = row.teachersByDay.toList(growable: true);
    final currentCell = _decodeCellTeachers(values[dayIndex]);
    final nextCell = _cellTeacherCodec.addTeacher(currentCell, teacherName);
    if (currentCell == nextCell) {
      return null;
    }

    values[dayIndex] = _encodeCellTeachers(nextCell);
    rows[rowIndex] = row.copyWith(teachersByDay: values);
    _currentWeek = _currentWeek.copyWith(rows: rows);
    notifyListeners();
    return null;
  }

  String? removeTeacherFromCell({
    required int rowIndex,
    required int dayIndex,
    required String teacherName,
  }) {
    final rowError = _validateCellIndexes(
      rowIndex: rowIndex,
      dayIndex: dayIndex,
    );
    if (rowError != null) {
      return rowError;
    }

    final rows = _currentWeek.rows.toList(growable: true);
    final row = rows[rowIndex];
    final values = row.teachersByDay.toList(growable: true);
    final currentCell = _decodeCellTeachers(values[dayIndex]);
    final nextCell = _cellTeacherCodec.removeTeacher(currentCell, teacherName);
    if (currentCell == nextCell) {
      return null;
    }

    values[dayIndex] = _encodeCellTeachers(nextCell);
    rows[rowIndex] = row.copyWith(teachersByDay: values);
    _currentWeek = _currentWeek.copyWith(rows: rows);
    notifyListeners();
    return null;
  }

  List<String> getTeachersForCell({
    required int rowIndex,
    required int dayIndex,
  }) {
    final rowError = _validateCellIndexes(
      rowIndex: rowIndex,
      dayIndex: dayIndex,
    );
    if (rowError != null) {
      throw FormatException(rowError);
    }

    return _cellTeacherCodec.parse(
      _decodeCellTeachers(_currentWeek.rows[rowIndex].teachersByDay[dayIndex]),
    );
  }

  int clearAssignmentsForTeacher(String teacherName) {
    final canonicalTeacher = _textNormalizer.canonical(teacherName);
    if (canonicalTeacher.isEmpty) {
      return 0;
    }

    var clearedCount = 0;
    final updatedRows = _currentWeek.rows
        .map((row) {
          final teachers = row.teachersByDay.toList(growable: true);
          var changed = false;

          for (var i = 0; i < teachers.length; i++) {
            if (_textNormalizer.canonicalEquals(teachers[i], teacherName)) {
              teachers[i] = '';
              clearedCount += 1;
              changed = true;
            }
          }

          if (!changed) {
            return row;
          }
          return row.copyWith(teachersByDay: teachers);
        })
        .toList(growable: false);

    if (clearedCount == 0) {
      return 0;
    }

    _currentWeek = _currentWeek.copyWith(rows: updatedRows);
    notifyListeners();
    return clearedCount;
  }

  List<RosterRow> rotateRowsForward(List<RosterRow> rows) {
    return _rosterService.rotateForward(rows);
  }

  List<RosterRow> rotateRowsBackward(List<RosterRow> rows) {
    return _rosterService.rotateBackward(rows);
  }

  List<RosterRow> rotateRowsDayForward(List<RosterRow> rows, int dayIndex) {
    return _rosterService.rotateDayForward(rows, dayIndex);
  }

  List<RosterRow> rotateRowsDayBackward(List<RosterRow> rows, int dayIndex) {
    return _rosterService.rotateDayBackward(rows, dayIndex);
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
      _hasActiveRoster = true;
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  String _decodeCellTeachers(String value) {
    return value.replaceAll(_multiTeacherLineBreakToken, '\n');
  }

  String _encodeCellTeachers(String value) {
    return value.replaceAll('\n', _multiTeacherLineBreakToken);
  }

  String? _validateCellIndexes({required int rowIndex, required int dayIndex}) {
    if (rowIndex < 0 || rowIndex >= _currentWeek.rows.length) {
      return 'Geçersiz satır seçimi.';
    }
    if (dayIndex < 0 || dayIndex >= rosterDayCount) {
      return 'Geçersiz gün seçimi.';
    }
    return null;
  }
}

class RosterCellSelection {
  const RosterCellSelection({required this.rowIndex, required this.dayIndex});

  final int rowIndex;
  final int dayIndex;
}
