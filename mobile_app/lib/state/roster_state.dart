import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planning_mode.dart';
import '../models/roster_project.dart';
import '../models/roster_row.dart';
import '../models/teacher.dart';
import '../models/week.dart';
import '../services/cell_teacher_codec.dart';
import '../services/export_snapshot_service.dart';
import '../services/roster_service.dart';
import '../services/teacher_service.dart';
import '../services/text_normalizer.dart';
import '../services/week_service.dart';
import 'teacher_list_state.dart';

class RosterState extends ChangeNotifier implements TeacherListStateAdapter {
  RosterState({
    required Week currentWeek,
    bool hasActiveRoster = false,
    String projectName = '',
    WeekService? weekService,
    RosterService? rosterService,
    CellTeacherCodec? cellTeacherCodec,
    TextNormalizer? textNormalizer,
    ExportSnapshotService? exportSnapshotService,
    List<Teacher>? initialTeachers,
  }) : _weekService = weekService ?? WeekService(rosterService: rosterService),
       _rosterService = rosterService ?? const RosterService(),
       _cellTeacherCodec = cellTeacherCodec ?? const CellTeacherCodec(),
       _textNormalizer = textNormalizer ?? const TextNormalizer(),
       _exportSnapshotService =
           exportSnapshotService ?? const ExportSnapshotService() {
    if (hasActiveRoster) {
      final now = DateTime.now();
      final project = RosterProject(
        id: '_compat_${now.millisecondsSinceEpoch}_${++_idCounter}',
        name: projectName,
        planningMode: PlanningMode.weekly,
        currentWeek: currentWeek,
        teachers: initialTeachers ?? const [],
        createdAt: now,
        updatedAt: now,
      );
      _projects = [project];
      _activeProjectId = project.id;
    } else {
      _projects = [];
      _activeProjectId = null;
      _fallbackWeek = currentWeek;
    }
  }

  final WeekService _weekService;
  final RosterService _rosterService;
  final CellTeacherCodec _cellTeacherCodec;
  final TextNormalizer _textNormalizer;
  final ExportSnapshotService _exportSnapshotService;
  static const String _multiTeacherLineBreakToken = r'\n';
  static const String _storageKey = 'roster_projects_state_v1';

  static int _idCounter = 0;

  List<RosterProject> _projects = [];
  String? _activeProjectId;
  Week _fallbackWeek = _kBlankWeek;
  RosterCellSelection? _selectedCell;
  List<Week>? _generatedMonthlyWeeks;
  String? _teacherError;

  static final Week _kBlankWeek = WeekService().buildWeek(
    startDate: DateTime(2026, 2, 2),
    endDate: DateTime(2026, 2, 6),
    rows: const [],
    schoolName: '',
    principalName: '',
  );

  RosterProject? get _activeProject {
    final id = _activeProjectId;
    if (id == null) return null;
    final idx = _projects.indexWhere((p) => p.id == id);
    return idx >= 0 ? _projects[idx] : null;
  }

  // ── Public getters ──────────────────────────────────────────────────────────

  Week get currentWeek => _activeProject?.currentWeek ?? _fallbackWeek;
  bool get hasActiveRoster => _activeProjectId != null;
  String get projectName => _activeProject?.name ?? '';
  List<RosterProject> get projects => List.unmodifiable(_projects);
  RosterCellSelection? get selectedCell => _selectedCell;
  List<Week>? get generatedMonthlyWeeks => _generatedMonthlyWeeks;
  PlanningMode get activePlanningMode =>
      _activeProject?.planningMode ?? PlanningMode.weekly;

  // TeacherListStateAdapter
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => _teacherError;
  @override
  List<Teacher> get teachers => _activeProject?.teachers ?? const [];

  ExportSnapshot get exportSnapshot {
    final monthly = _generatedMonthlyWeeks;
    if (monthly != null && monthly.isNotEmpty) {
      return _exportSnapshotService.fromPreviewWeeks(monthly);
    }
    return _exportSnapshotService.fromCurrentWeek(currentWeek);
  }

  // ── Factory constructors ────────────────────────────────────────────────────

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
      hasActiveRoster: true,
      currentWeek: weekService.buildWeek(
        startDate: startDate,
        endDate: endDate,
        rows: rows,
        schoolName: 'Örnek Okul',
        principalName: 'Müdür',
      ),
      initialTeachers: TeacherService().all(),
    );
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final projectsList = (data['projects'] as List<dynamic>)
          .map((p) => RosterProject.fromJson(p as Map<String, dynamic>))
          .toList();
      _projects = projectsList;
      _activeProjectId = data['activeProjectId'] as String?;
    } catch (_) {
      // corrupt or missing — keep blank state
    } finally {
      notifyListeners();
    }
  }

  Future<void> persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'activeProjectId': _activeProjectId,
        'projects': _projects.map((p) => p.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (_) {
      // ignore write errors
    }
  }

  // ── Multi-project API ───────────────────────────────────────────────────────

  String createProject({
    required String name,
    required PlanningMode planningMode,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? now;
    final id = 'proj_${now.millisecondsSinceEpoch}_${++_idCounter}';
    final week = _weekService.buildWeek(
      startDate: start,
      endDate: end,
      rows: const [],
      schoolName: '',
      principalName: '',
      mode: planningMode,
    );
    final project = RosterProject(
      id: id,
      name: name,
      planningMode: planningMode,
      currentWeek: week,
      teachers: const [],
      createdAt: now,
      updatedAt: now,
    );
    _projects = [..._projects, project];
    _activeProjectId = id;
    notifyListeners();
    unawaited(persistState());
    return id;
  }

  void openProject(String id) {
    if (_projects.any((p) => p.id == id)) {
      _activeProjectId = id;
      _generatedMonthlyWeeks = null;
      notifyListeners();
      unawaited(persistState());
    }
  }

  // ── Single-project compat API ───────────────────────────────────────────────

  void setProjectMetadata({required String name}) {
    final p = _activeProject;
    if (p != null) {
      _updateActiveProject(p.copyWith(name: name, updatedAt: DateTime.now()));
    }
    notifyListeners();
    unawaited(persistState());
  }

  void generateMonthlyWeeks() {
    _generatedMonthlyWeeks = _weekService.generateMonthlyFromWeek(currentWeek);
    notifyListeners();
  }

  void goToNextWeek() {
    final p = _activeProject;
    if (p != null) {
      _updateActiveProject(p.copyWith(
        currentWeek: _weekService.nextWeek(p.currentWeek),
        updatedAt: DateTime.now(),
      ));
    } else {
      _fallbackWeek = _weekService.nextWeek(_fallbackWeek);
    }
    notifyListeners();
    unawaited(persistState());
  }

  void goToPreviousWeek() {
    final p = _activeProject;
    if (p != null) {
      _updateActiveProject(p.copyWith(
        currentWeek: _weekService.previousWeek(p.currentWeek),
        updatedAt: DateTime.now(),
      ));
    } else {
      _fallbackWeek = _weekService.previousWeek(_fallbackWeek);
    }
    notifyListeners();
    unawaited(persistState());
  }

  List<Teacher> searchTeachers({String? query, bool availableOnly = false}) {
    final all = teachers;
    final cleanQuery = (query ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return all.where((t) {
      if (availableOnly && !t.isActive) return false;
      if (cleanQuery.isEmpty) return true;
      return t.name.toLowerCase().contains(cleanQuery) ||
          t.id.toLowerCase().contains(cleanQuery);
    }).toList(growable: false);
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
    final rowError = _validateCellIndexes(rowIndex: rowIndex, dayIndex: dayIndex);
    if (rowError != null) return rowError;

    final rows = currentWeek.rows.toList(growable: true);
    final row = rows[rowIndex];
    final values = row.teachersByDay.toList(growable: true);
    values[dayIndex] = teacherName;
    rows[rowIndex] = row.copyWith(teachersByDay: values);
    _setCurrentWeek(currentWeek.copyWith(rows: rows));
    notifyListeners();
    unawaited(persistState());
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
    final rowError = _validateCellIndexes(rowIndex: rowIndex, dayIndex: dayIndex);
    if (rowError != null) return rowError;

    final rows = currentWeek.rows.toList(growable: true);
    final row = rows[rowIndex];
    final values = row.teachersByDay.toList(growable: true);
    final currentCell = _decodeCellTeachers(values[dayIndex]);
    final nextCell = _cellTeacherCodec.addTeacher(currentCell, teacherName);
    if (currentCell == nextCell) return null;

    values[dayIndex] = _encodeCellTeachers(nextCell);
    rows[rowIndex] = row.copyWith(teachersByDay: values);
    _setCurrentWeek(currentWeek.copyWith(rows: rows));
    notifyListeners();
    unawaited(persistState());
    return null;
  }

  String? removeTeacherFromCell({
    required int rowIndex,
    required int dayIndex,
    required String teacherName,
  }) {
    final rowError = _validateCellIndexes(rowIndex: rowIndex, dayIndex: dayIndex);
    if (rowError != null) return rowError;

    final rows = currentWeek.rows.toList(growable: true);
    final row = rows[rowIndex];
    final values = row.teachersByDay.toList(growable: true);
    final currentCell = _decodeCellTeachers(values[dayIndex]);
    final nextCell = _cellTeacherCodec.removeTeacher(currentCell, teacherName);
    if (currentCell == nextCell) return null;

    values[dayIndex] = _encodeCellTeachers(nextCell);
    rows[rowIndex] = row.copyWith(teachersByDay: values);
    _setCurrentWeek(currentWeek.copyWith(rows: rows));
    notifyListeners();
    unawaited(persistState());
    return null;
  }

  List<String> getTeachersForCell({
    required int rowIndex,
    required int dayIndex,
  }) {
    final rowError = _validateCellIndexes(rowIndex: rowIndex, dayIndex: dayIndex);
    if (rowError != null) throw FormatException(rowError);

    return _cellTeacherCodec.parse(
      _decodeCellTeachers(currentWeek.rows[rowIndex].teachersByDay[dayIndex]),
    );
  }

  int clearAssignmentsForTeacher(String teacherName) {
    final canonicalTeacher = _textNormalizer.canonical(teacherName);
    if (canonicalTeacher.isEmpty) return 0;

    var clearedCount = 0;
    final updatedRows = currentWeek.rows.map((row) {
      final tbd = row.teachersByDay.toList(growable: true);
      var changed = false;
      for (var i = 0; i < tbd.length; i++) {
        if (_textNormalizer.canonicalEquals(tbd[i], teacherName)) {
          tbd[i] = '';
          clearedCount++;
          changed = true;
        }
      }
      if (!changed) return row;
      return row.copyWith(teachersByDay: tbd);
    }).toList(growable: false);

    if (clearedCount == 0) return 0;

    _setCurrentWeek(currentWeek.copyWith(rows: updatedRows));
    notifyListeners();
    unawaited(persistState());
    return clearedCount;
  }

  List<RosterRow> rotateRowsForward(List<RosterRow> rows) =>
      _rosterService.rotateForward(rows);

  List<RosterRow> rotateRowsBackward(List<RosterRow> rows) =>
      _rosterService.rotateBackward(rows);

  List<RosterRow> rotateRowsDayForward(List<RosterRow> rows, int dayIndex) =>
      _rosterService.rotateDayForward(rows, dayIndex);

  List<RosterRow> rotateRowsDayBackward(List<RosterRow> rows, int dayIndex) =>
      _rosterService.rotateDayBackward(rows, dayIndex);

  String? saveWeekDraft({
    required DateTime startDate,
    required DateTime endDate,
    required String schoolName,
    required String principalName,
    required List<RosterRow> rows,
    PlanningMode mode = PlanningMode.weekly,
  }) {
    if (startDate.isAfter(endDate)) {
      return 'Başlangıç tarihi bitiş tarihinden büyük olamaz.';
    }

    try {
      final preparedRows = _rosterService.prepareRowsForSave(rows);
      final week = _weekService.buildWeek(
        startDate: startDate,
        endDate: endDate,
        rows: preparedRows,
        schoolName: schoolName,
        principalName: principalName,
        mode: mode,
      );

      final p = _activeProject;
      if (p != null) {
        _updateActiveProject(p.copyWith(
          currentWeek: week,
          planningMode: mode,
          updatedAt: DateTime.now(),
        ));
      } else {
        // No active project: create one for backward compat
        final now = DateTime.now();
        final id = 'proj_${now.millisecondsSinceEpoch}';
        final project = RosterProject(
          id: id,
          name: '',
          planningMode: mode,
          currentWeek: week,
          teachers: const [],
          createdAt: now,
          updatedAt: now,
        );
        _projects = [project];
        _activeProjectId = id;
      }
      notifyListeners();
      unawaited(persistState());
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  // ── TeacherListStateAdapter ─────────────────────────────────────────────────

  @override
  Future<String?> createTeacher(Teacher teacher) async {
    _teacherError = null;
    final p = _activeProject;
    if (p == null) return 'Aktif proje yok.';
    if (!teacher.isValid) return 'Geçersiz öğretmen.';
    if (p.teachers.any((t) => t.id == teacher.id)) {
      return 'Bu kimlikle zaten bir öğretmen var.';
    }
    _updateActiveProject(p.copyWith(
      teachers: [...p.teachers, teacher],
      updatedAt: DateTime.now(),
    ));
    notifyListeners();
    await persistState();
    return null;
  }

  @override
  Future<String?> updateTeacher(Teacher teacher) async {
    _teacherError = null;
    final p = _activeProject;
    if (p == null) return 'Aktif proje yok.';
    if (!teacher.isValid) return 'Geçersiz öğretmen.';
    final idx = p.teachers.indexWhere((t) => t.id == teacher.id);
    if (idx < 0) return 'Öğretmen bulunamadı.';
    final updated = p.teachers.toList(growable: true)..[idx] = teacher;
    _updateActiveProject(p.copyWith(
      teachers: updated,
      updatedAt: DateTime.now(),
    ));
    notifyListeners();
    await persistState();
    return null;
  }

  @override
  Future<String?> deleteTeacher(String id) async {
    _teacherError = null;
    final p = _activeProject;
    if (p == null) return 'Aktif proje yok.';
    final updated = p.teachers.where((t) => t.id != id).toList();
    _updateActiveProject(p.copyWith(
      teachers: updated,
      updatedAt: DateTime.now(),
    ));
    notifyListeners();
    await persistState();
    return null;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _updateActiveProject(RosterProject updated) {
    final idx = _projects.indexWhere((p) => p.id == updated.id);
    if (idx < 0) return;
    final list = _projects.toList(growable: true)..[idx] = updated;
    _projects = list;
  }

  void _setCurrentWeek(Week week) {
    final p = _activeProject;
    if (p != null) {
      _updateActiveProject(p.copyWith(currentWeek: week, updatedAt: DateTime.now()));
    } else {
      _fallbackWeek = week;
    }
  }

  String _decodeCellTeachers(String value) =>
      value.replaceAll(_multiTeacherLineBreakToken, '\n');

  String _encodeCellTeachers(String value) =>
      value.replaceAll('\n', _multiTeacherLineBreakToken);

  String? _validateCellIndexes({required int rowIndex, required int dayIndex}) {
    if (rowIndex < 0 || rowIndex >= currentWeek.rows.length) {
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
