import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/planning_mode.dart';
import 'package:nobetci_program_mobile/models/roster_project.dart';
import 'package:nobetci_program_mobile/models/roster_row.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';

void main() {
  group('Çoklu proje veri izolasyonu', () {
    test('proje A\'ya eklenen öğretmen proje B\'de görünmez', () async {
      final state = RosterState.blank();
      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
      );
      await state.createTeacher(
        Teacher(id: 'T001', name: 'Ali Yilmaz', isActive: true),
      );

      final idB = state.createProject(
        name: 'B',
        planningMode: PlanningMode.weekly,
      );

      expect(state.teachers, isEmpty);

      state.openProject(idA);
      expect(state.teachers.map((t) => t.id), contains('T001'));

      state.openProject(idB);
      expect(state.teachers, isEmpty);
    });

    test('proje A\'ya görev yeri eklemek proje B\'yi etkilemez', () {
      final state = RosterState.blank();

      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
      );
      state.saveWeekDraft(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        schoolName: '',
        principalName: '',
        rows: [
          RosterRow(
            location: 'Bahçe',
            teachersByDay: ['Ali', '', '', '', ''],
          ),
        ],
      );

      final idB = state.createProject(
        name: 'B',
        planningMode: PlanningMode.weekly,
      );

      expect(state.currentWeek.rows, isEmpty);

      state.openProject(idA);
      expect(state.currentWeek.rows.length, 1);
      expect(state.currentWeek.rows[0].location, 'Bahçe');

      state.openProject(idB);
      expect(state.currentWeek.rows, isEmpty);
    });

    test('yeni proje boş öğretmen listesi ile başlar', () async {
      final state = RosterState.blank();
      state.createProject(name: 'A', planningMode: PlanningMode.weekly);
      await state.createTeacher(
        Teacher(id: 'T001', name: 'Ali', isActive: true),
      );
      expect(state.teachers.length, 1);

      state.createProject(name: 'B', planningMode: PlanningMode.weekly);
      expect(state.teachers, isEmpty);
    });

    test('yeni proje boş görev yerleri ile başlar', () {
      final state = RosterState.blank();
      state.createProject(name: 'A', planningMode: PlanningMode.weekly);
      state.saveWeekDraft(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        schoolName: '',
        principalName: '',
        rows: [
          RosterRow(location: 'Koridor', teachersByDay: ['', '', '', '', '']),
        ],
      );

      state.createProject(name: 'B', planningMode: PlanningMode.weekly);
      expect(state.currentWeek.rows, isEmpty);
    });

    test('openProject sonrası teachers aktif projeye ait', () async {
      final state = RosterState.blank();
      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
      );
      await state.createTeacher(
        Teacher(id: 'T001', name: 'A Ogretmeni', isActive: true),
      );

      final idB = state.createProject(
        name: 'B',
        planningMode: PlanningMode.weekly,
      );
      await state.createTeacher(
        Teacher(id: 'T002', name: 'B Ogretmeni', isActive: true),
      );

      state.openProject(idA);
      expect(state.teachers.map((t) => t.name), contains('A Ogretmeni'));
      expect(
        state.teachers.map((t) => t.name),
        isNot(contains('B Ogretmeni')),
      );

      state.openProject(idB);
      expect(state.teachers.map((t) => t.name), contains('B Ogretmeni'));
      expect(
        state.teachers.map((t) => t.name),
        isNot(contains('A Ogretmeni')),
      );
    });

    test('openProject sonrası currentWeek aktif projeye ait', () {
      final state = RosterState.blank();

      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
      );
      state.saveWeekDraft(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        schoolName: 'Okul A',
        principalName: '',
        rows: const [],
      );

      final idB = state.createProject(
        name: 'B',
        planningMode: PlanningMode.weekly,
      );
      state.saveWeekDraft(
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 6),
        schoolName: 'Okul B',
        principalName: '',
        rows: const [],
      );

      state.openProject(idA);
      expect(state.currentWeek.schoolName, 'Okul A');

      state.openProject(idB);
      expect(state.currentWeek.schoolName, 'Okul B');
    });

    test('planningMode projeler arası izole', () {
      final state = RosterState.blank();
      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
      );
      final idB = state.createProject(
        name: 'B',
        planningMode: PlanningMode.monthly,
      );

      state.openProject(idA);
      expect(state.activePlanningMode, PlanningMode.weekly);

      state.openProject(idB);
      expect(state.activePlanningMode, PlanningMode.monthly);
    });

    test('exportSnapshot aktif projeye ait haftayı kullanır', () {
      final state = RosterState.blank();
      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
      );
      state.saveWeekDraft(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        schoolName: 'Okul A',
        principalName: '',
        rows: const [],
      );

      final idB = state.createProject(
        name: 'B',
        planningMode: PlanningMode.weekly,
      );
      state.saveWeekDraft(
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 6),
        schoolName: 'Okul B',
        principalName: '',
        rows: const [],
      );

      state.openProject(idA);
      expect(state.exportSnapshot.weeks.first.schoolName, 'Okul A');

      state.openProject(idB);
      expect(state.exportSnapshot.weeks.first.schoolName, 'Okul B');
    });

    test('proje olmadığında hasActiveRoster false döner', () {
      final state = RosterState.blank();
      expect(state.hasActiveRoster, false);
      expect(state.projects, isEmpty);
    });

    test('RosterProject toJson / fromJson round-trip', () {
      final state = RosterState.blank();
      state.createProject(
        name: 'Test Projesi',
        planningMode: PlanningMode.monthly,
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );
      final project = state.projects.first;
      final json = project.toJson();
      final restored = RosterProject.fromJson(json);

      expect(restored.id, project.id);
      expect(restored.name, project.name);
      expect(restored.planningMode, project.planningMode);
      expect(restored.currentWeek.startDate, project.currentWeek.startDate);
      expect(restored.currentWeek.endDate, project.currentWeek.endDate);
      expect(restored.currentWeek.title, project.currentWeek.title);
    });
  });
}
