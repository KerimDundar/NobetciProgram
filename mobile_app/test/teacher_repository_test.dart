import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/teacher_repository.dart';

void main() {
  group('InMemoryTeacherRepository', () {
    test('lists seeded teachers sorted by name', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[
          Teacher(id: 'T2', name: 'Zeynep Kaya', isActive: true),
          Teacher(id: 'T1', name: 'Ali Yilmaz', isActive: true),
        ],
      );

      final teachers = await repository.list();
      expect(teachers.map((teacher) => teacher.id), <String>['T1', 'T2']);
      repository.dispose();
    });

    test('creates, updates and deletes teachers', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[],
      );
      const id = 'T100';

      await repository.create(
        Teacher(id: id, name: 'Merve Aslan', isActive: true),
      );

      final created = await repository.getById(id);
      expect(created?.name, 'Merve Aslan');

      await repository.update(
        Teacher(id: id, name: 'Merve Aslan Guncel', isActive: false),
      );

      final updated = await repository.getById(id);
      expect(updated?.name, 'Merve Aslan Guncel');
      expect(updated?.isActive, isFalse);

      await repository.deleteById(id);
      final deleted = await repository.getById(id);
      expect(deleted, isNull);
      repository.dispose();
    });

    test('watch emits updates on mutation', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[],
      );
      final stream = repository.watch();

      final first = await stream.first;
      expect(first, isEmpty);

      final secondFuture = stream.skip(1).first;
      await repository.create(
        Teacher(id: 'T9', name: 'Elif Kartal', isActive: true),
      );
      final second = await secondFuture;
      expect(second.map((teacher) => teacher.id), <String>['T9']);
      repository.dispose();
    });

    test('throws on duplicate create and missing update/delete', () async {
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[],
      );
      final teacher = Teacher(id: 'T7', name: 'Burcu Deniz', isActive: true);

      await repository.create(teacher);

      expect(repository.create(teacher), throwsA(isA<StateError>()));
      expect(
        repository.update(
          Teacher(id: 'X1', name: 'Missing User', isActive: true),
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.deleteById('X1'), throwsA(isA<StateError>()));
      repository.dispose();
    });
  });
}
