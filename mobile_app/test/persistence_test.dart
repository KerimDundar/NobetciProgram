import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/models/planning_mode.dart';
import 'package:nobetci_program_mobile/models/roster_row.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';

RosterState _blank() => RosterState.blank();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Persistence — round-trip izolasyon', () {
    test('Proje A ve B verisi serialize → deserialize → izolasyon korunur',
        () async {
      final state = _blank();

      final idA = state.createProject(
        name: 'Proje A',
        planningMode: PlanningMode.weekly,
        startDate: DateTime(2026, 4, 28),
        endDate: DateTime(2026, 5, 2),
      );
      await state.createTeacher(
        Teacher(id: 'A1', name: 'Ahmet Yıldız', isActive: true),
      );

      final idB = state.createProject(
        name: 'Proje B',
        planningMode: PlanningMode.monthly,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 31),
      );
      await state.createTeacher(
        Teacher(id: 'B1', name: 'Banu Kara', isActive: true),
      );

      await state.persistState();

      final state2 = _blank();
      await state2.load();

      expect(state2.projects.length, 2);

      state2.openProject(idA);
      expect(state2.teachers.map((t) => t.id), contains('A1'));
      expect(state2.teachers.map((t) => t.id), isNot(contains('B1')));
      expect(state2.activePlanningMode, PlanningMode.weekly);

      state2.openProject(idB);
      expect(state2.teachers.map((t) => t.id), contains('B1'));
      expect(state2.teachers.map((t) => t.id), isNot(contains('A1')));
      expect(state2.activePlanningMode, PlanningMode.monthly);
    });

    test('activeProjectId kalıcı kaydedilir ve geri yüklenir', () async {
      final state = _blank();
      state.createProject(
        name: 'Proje X',
        planningMode: PlanningMode.weekly,
      );
      final idY = state.createProject(
        name: 'Proje Y',
        planningMode: PlanningMode.weekly,
      );
      state.openProject(idY);
      await state.persistState();

      final state2 = _blank();
      await state2.load();

      expect(state2.hasActiveRoster, true);
      expect(state2.projectName, 'Proje Y');
    });
  });

  group('Persistence — app restart simülasyonu', () {
    test('saveWeekDraft sonrası projeler ve görev yerleri geri yüklenir',
        () async {
      final state = _blank();
      state.createProject(
        name: 'Okul Nöbeti',
        planningMode: PlanningMode.weekly,
        startDate: DateTime(2026, 4, 28),
        endDate: DateTime(2026, 5, 2),
      );

      state.saveWeekDraft(
        startDate: DateTime(2026, 4, 28),
        endDate: DateTime(2026, 5, 2),
        schoolName: 'Test Okulu',
        principalName: 'Ahmet Müdür',
        rows: [
          RosterRow(
            location: 'Bahçe',
            teachersByDay: ['Ali', 'Veli', '', '', ''],
          ),
        ],
      );

      await state.persistState();

      final state2 = _blank();
      await state2.load();

      expect(state2.hasActiveRoster, true);
      expect(state2.currentWeek.schoolName, 'Test Okulu');
      expect(state2.currentWeek.rows.length, 1);
      expect(state2.currentWeek.rows.first.location, 'Bahçe');
      expect(state2.currentWeek.rows.first.teachersByDay[0], 'Ali');
    });

    test('öğretmen eklendikten sonra restart — öğretmen geri yüklenir',
        () async {
      final state = _blank();
      state.createProject(
        name: 'Proje',
        planningMode: PlanningMode.weekly,
      );
      await state.createTeacher(
        Teacher(id: 'T1', name: 'Tuba Acar', isActive: true),
      );
      // persistState çağrısı createTeacher içinde await edildi

      final state2 = _blank();
      await state2.load();

      expect(state2.teachers.any((t) => t.id == 'T1'), true);
      expect(state2.teachers.first.name, 'Tuba Acar');
    });

    test('öğretmen silindikten sonra restart — öğretmen kaybolur', () async {
      final state = _blank();
      state.createProject(
        name: 'Proje',
        planningMode: PlanningMode.weekly,
      );
      await state.createTeacher(
        Teacher(id: 'T1', name: 'Tuba Acar', isActive: true),
      );
      await state.deleteTeacher('T1');

      final state2 = _blank();
      await state2.load();

      expect(state2.teachers.any((t) => t.id == 'T1'), false);
    });
  });

  group('Persistence — güvenlik', () {
    test('boş storage — uygulama crash etmez, blank state döner', () async {
      // setUp already sets empty mock
      final state = _blank();
      await state.load();

      expect(state.projects, isEmpty);
      expect(state.hasActiveRoster, false);
    });

    test('bozuk JSON — uygulama crash etmez, blank state döner', () async {
      SharedPreferences.setMockInitialValues({
        'roster_projects_state_v1': '{invalid json{{{{',
      });

      final state = _blank();
      await state.load();

      expect(state.projects, isEmpty);
      expect(state.hasActiveRoster, false);
    });

    test('eksik alan içeren JSON — uygulama crash etmez, blank state döner',
        () async {
      SharedPreferences.setMockInitialValues({
        'roster_projects_state_v1': '{"activeProjectId": null}',
      });

      final state = _blank();
      await state.load();

      expect(state.projects, isEmpty);
    });
  });

  group('Persistence — proje izolasyonu korunur', () {
    test("Proje A öğretmeni Proje B'de görünmez", () async {
      final state = _blank();
      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
      );
      await state.createTeacher(
        Teacher(id: 'TA', name: 'Öğretmen A', isActive: true),
      );

      state.createProject(name: 'B', planningMode: PlanningMode.weekly);
      await state.createTeacher(
        Teacher(id: 'TB', name: 'Öğretmen B', isActive: true),
      );

      await state.persistState();

      final state2 = _blank();
      await state2.load();

      state2.openProject(idA);
      expect(state2.teachers.map((t) => t.id).toList(), ['TA']);
    });

    test('haftayı kaydetmek diğer projenin haftasını değiştirmez', () async {
      final state = _blank();
      final idA = state.createProject(
        name: 'A',
        planningMode: PlanningMode.weekly,
        startDate: DateTime(2026, 4, 28),
        endDate: DateTime(2026, 5, 2),
      );
      state.saveWeekDraft(
        startDate: DateTime(2026, 4, 28),
        endDate: DateTime(2026, 5, 2),
        schoolName: 'Okul A',
        principalName: '',
        rows: [],
      );

      state.createProject(
        name: 'B',
        planningMode: PlanningMode.weekly,
        startDate: DateTime(2026, 5, 5),
        endDate: DateTime(2026, 5, 9),
      );
      state.saveWeekDraft(
        startDate: DateTime(2026, 5, 5),
        endDate: DateTime(2026, 5, 9),
        schoolName: 'Okul B',
        principalName: '',
        rows: [],
      );

      await state.persistState();

      final state2 = _blank();
      await state2.load();

      state2.openProject(idA);
      expect(state2.currentWeek.schoolName, 'Okul A');
    });
  });
}
