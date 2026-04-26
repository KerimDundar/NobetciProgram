import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/teacher_service.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';

void main() {
  group('Teacher model', () {
    test('normalizes core fields', () {
      final teacher = Teacher(
        id: '  T100  ',
        name: '  Ali   Veli  ',
        isActive: true,
      );

      expect(teacher.id, 'T100');
      expect(teacher.name, 'Ali Veli');
      expect(teacher.isActive, isTrue);
      expect(teacher.isValid, isTrue);
    });

    test('invalid when id or name is empty', () {
      expect(Teacher(id: '', name: 'Ali').isValid, isFalse);
      expect(Teacher(id: 'T1', name: '   ').isValid, isFalse);
    });
  });

  group('TeacherService', () {
    final service = TeacherService(
      teachers: [
        Teacher(id: 'T1', name: 'Ali Yilmaz', isActive: true),
        Teacher(id: 'T2', name: 'Ayse Demir', isActive: true),
        Teacher(id: 'T3', name: 'Can Aydin', isActive: false),
      ],
    );

    test('searches by query on name', () {
      expect(service.search(query: 'ali').map((teacher) => teacher.id), ['T1']);
      expect(service.search(query: 'science'), isEmpty);
    });

    test('filters by availability', () {
      expect(service.search(availableOnly: true).map((teacher) => teacher.id), [
        'T1',
        'T2',
      ]);
    });

    test('findById returns teacher or null', () {
      expect(service.findById('T2')?.name, 'Ayse Demir');
      expect(service.findById('missing'), isNull);
      expect(service.findById('   '), isNull);
    });
  });

  group('RosterState teacher assignment', () {
    test('assigns and clears teacher in selected cell', () {
      final state = RosterState.initial();

      final assignError = state.assignTeacherToCell(
        rowIndex: 0,
        dayIndex: 2,
        teacherName: 'Test Ogretmen',
      );
      expect(assignError, isNull);
      expect(state.currentWeek.rows[0].teachersByDay[2], 'Test Ogretmen');

      final clearError = state.clearTeacherFromCell(rowIndex: 0, dayIndex: 2);
      expect(clearError, isNull);
      expect(state.currentWeek.rows[0].teachersByDay[2], '');
    });

    test('adds teacher to empty cell and returns parsed list', () {
      final state = RosterState.initial();

      final addError = state.addTeacherToCell(
        rowIndex: 0,
        dayIndex: 2,
        teacherName: 'Test Ogretmen',
      );

      expect(addError, isNull);
      expect(state.currentWeek.rows[0].teachersByDay[2], 'Test Ogretmen');
      expect(state.getTeachersForCell(rowIndex: 0, dayIndex: 2), [
        'Test Ogretmen',
      ]);
    });

    test('adds second teacher without overwrite and blocks duplicate', () {
      final state = RosterState.initial();
      final existing = state
          .getTeachersForCell(rowIndex: 0, dayIndex: 0)
          .single;

      final addSecond = state.addTeacherToCell(
        rowIndex: 0,
        dayIndex: 0,
        teacherName: 'Ayse Demir',
      );
      expect(addSecond, isNull);
      final valuesAfterSecond = state.getTeachersForCell(
        rowIndex: 0,
        dayIndex: 0,
      );
      expect(valuesAfterSecond, hasLength(2));
      expect(valuesAfterSecond.first, existing);
      expect(valuesAfterSecond.last, 'Ayse Demir');

      final addDuplicate = state.addTeacherToCell(
        rowIndex: 0,
        dayIndex: 0,
        teacherName: existing,
      );
      expect(addDuplicate, isNull);
      final valuesAfterDuplicate = state.getTeachersForCell(
        rowIndex: 0,
        dayIndex: 0,
      );
      expect(valuesAfterDuplicate, hasLength(2));
      expect(
        valuesAfterDuplicate.where((name) => name == existing),
        hasLength(1),
      );
    });

    test('removes only selected teacher and clears when last removed', () {
      final state = RosterState.initial();

      state.addTeacherToCell(
        rowIndex: 0,
        dayIndex: 2,
        teacherName: 'Ali Yilmaz',
      );
      state.addTeacherToCell(
        rowIndex: 0,
        dayIndex: 2,
        teacherName: 'Ayse Demir',
      );

      final removeOne = state.removeTeacherFromCell(
        rowIndex: 0,
        dayIndex: 2,
        teacherName: 'Ali Yilmaz',
      );
      expect(removeOne, isNull);
      expect(state.currentWeek.rows[0].teachersByDay[2], 'Ayse Demir');

      final removeLast = state.removeTeacherFromCell(
        rowIndex: 0,
        dayIndex: 2,
        teacherName: 'Ayse Demir',
      );
      expect(removeLast, isNull);
      expect(state.currentWeek.rows[0].teachersByDay[2], '');
    });

    test('validates row and day indexes for all cell teacher APIs', () {
      final state = RosterState.initial();
      final rowError = state.assignTeacherToCell(
        rowIndex: -1,
        dayIndex: 0,
        teacherName: 'X',
      );
      final dayError = state.assignTeacherToCell(
        rowIndex: 0,
        dayIndex: 9,
        teacherName: 'X',
      );

      expect(rowError, isNotNull);
      expect(dayError, isNotNull);
      expect(
        state.addTeacherToCell(rowIndex: -1, dayIndex: 0, teacherName: 'X'),
        rowError,
      );
      expect(
        state.addTeacherToCell(rowIndex: 0, dayIndex: 9, teacherName: 'X'),
        dayError,
      );
      expect(
        state.removeTeacherFromCell(
          rowIndex: -1,
          dayIndex: 0,
          teacherName: 'X',
        ),
        rowError,
      );
      expect(
        state.removeTeacherFromCell(rowIndex: 0, dayIndex: 9, teacherName: 'X'),
        dayError,
      );
      expect(
        () => state.getTeachersForCell(rowIndex: -1, dayIndex: 0),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => state.getTeachersForCell(rowIndex: 0, dayIndex: 9),
        throwsA(isA<FormatException>()),
      );
    });

    test('exposes teacher list, search, and selected cell state', () {
      final state = RosterState.initial();

      expect(state.teachers, isNotEmpty);
      expect(state.searchTeachers(query: 'Ali'), isNotEmpty);

      state.selectCell(rowIndex: 1, dayIndex: 3);
      expect(state.selectedCell?.rowIndex, 1);
      expect(state.selectedCell?.dayIndex, 3);
      state.clearSelectedCell();
      expect(state.selectedCell, isNull);
    });

    test('clears assigned cells when teacher is removed from pool', () {
      final state = RosterState.initial();

      state.assignTeacherToCell(
        rowIndex: 0,
        dayIndex: 0,
        teacherName: 'Silinecek Ogretmen',
      );
      state.assignTeacherToCell(
        rowIndex: 1,
        dayIndex: 2,
        teacherName: 'Silinecek Ogretmen',
      );

      final cleared = state.clearAssignmentsForTeacher('Silinecek Ogretmen');

      expect(cleared, 2);
      expect(state.currentWeek.rows[0].teachersByDay[0], '');
      expect(state.currentWeek.rows[1].teachersByDay[2], '');
    });
  });
}
