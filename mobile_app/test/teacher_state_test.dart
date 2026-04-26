import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/teacher_repository.dart';
import 'package:nobetci_program_mobile/state/teacher_state.dart';

void main() {
  group('TeacherState', () {
    test('loads teachers reactively from repository', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[
          Teacher(id: 'T2', name: 'Zeynep Kaya', isActive: true),
          Teacher(id: 'T1', name: 'Ali Yilmaz', isActive: true),
        ],
      );
      final state = TeacherState(repository: repository);
      await state.ready;

      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.teachers.map((teacher) => teacher.id), <String>['T1', 'T2']);

      await repository.create(
        Teacher(id: 'T3', name: 'Can Aydin', isActive: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(state.teachers.map((teacher) => teacher.id), <String>[
        'T1',
        'T3',
        'T2',
      ]);

      state.dispose();
      repository.dispose();
    });

    test('creates, updates, and deletes via state actions', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[],
      );
      final state = TeacherState(repository: repository);
      await state.ready;

      final createError = await state.createTeacher(
        Teacher(id: 'T50', name: 'Merve Aslan', isActive: true),
      );
      expect(createError, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(state.findById('T50')?.name, 'Merve Aslan');

      final updateError = await state.updateTeacher(
        Teacher(id: 'T50', name: 'Merve Aslan Guncel', isActive: false),
      );
      expect(updateError, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(state.findById('T50')?.isActive, isFalse);

      final deleteError = await state.deleteTeacher('T50');
      expect(deleteError, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(state.findById('T50'), isNull);

      state.dispose();
      repository.dispose();
    });

    test('search and active filter reflect current reactive list', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[
          Teacher(id: 'T1', name: 'Ali Yilmaz', isActive: true),
          Teacher(id: 'T2', name: 'Ayse Demir', isActive: false),
          Teacher(id: 'T3', name: 'Can Aydin', isActive: true),
        ],
      );
      final state = TeacherState(repository: repository);
      await state.ready;

      expect(state.search(query: 'ali').map((teacher) => teacher.id), <String>[
        'T1',
      ]);
      expect(
        state.search(availableOnly: true).map((teacher) => teacher.id),
        <String>['T1', 'T3'],
      );

      state.dispose();
      repository.dispose();
    });

    test('returns mapped error messages for invalid operations', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[],
      );
      final state = TeacherState(repository: repository);
      await state.ready;

      final createError = await state.createTeacher(
        Teacher(id: '', name: '', isActive: true),
      );
      expect(createError, isNotNull);
      expect(state.errorMessage, createError);

      final deleteError = await state.deleteTeacher('missing');
      expect(deleteError, isNotNull);
      expect(state.errorMessage, deleteError);

      state.dispose();
      repository.dispose();
    });
  });
}
