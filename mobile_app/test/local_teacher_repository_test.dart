import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/local_teacher_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalTeacherRepository', () {
    test('seeds once and persists stored values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const key = 'teacher_repo_test_seed';
      final seedTeachers = <Teacher>[
        Teacher(id: 'S1', name: 'Ali Kaya', isActive: true),
      ];

      final repositoryA = LocalTeacherRepository(
        storageKey: key,
        seedTeachers: seedTeachers,
      );
      final firstList = await repositoryA.list();
      expect(firstList.map((teacher) => teacher.id), <String>['S1']);

      await repositoryA.create(
        Teacher(id: 'S2', name: 'Merve Aslan', isActive: true),
      );
      repositoryA.dispose();

      final repositoryB = LocalTeacherRepository(
        storageKey: key,
        seedTeachers: <Teacher>[
          Teacher(id: 'X1', name: 'Should Not Load', isActive: true),
        ],
      );
      final secondList = await repositoryB.list();
      expect(secondList.map((teacher) => teacher.id), <String>['S1', 'S2']);
      repositoryB.dispose();
    });

    test('watch emits updates after create', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const key = 'teacher_repo_test_watch';
      final repository = LocalTeacherRepository(storageKey: key);
      final stream = repository.watch();

      final first = await stream.first;
      expect(first, isNotEmpty);

      final secondFuture = stream.skip(1).first;
      await repository.create(
        Teacher(id: 'N9', name: 'Elif Kartal', isActive: true),
      );
      final second = await secondFuture;
      expect(second.where((teacher) => teacher.id == 'N9').length, equals(1));
      repository.dispose();
    });

    test('migrates legacy storage shape to simplified schema', () async {
      const key = 'teacher_repo_test_legacy_migration';
      final legacyPayload = jsonEncode(<Map<String, Object?>>[
        <String, Object?>{
          'id': 'L1',
          'fullName': 'Legacy Name',
          'department': 'Science',
          'isAvailable': false,
          'weeklyAssignmentCount': 4,
          'email': 'legacy@example.com',
          'phone': '555',
          'notes': 'old',
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-02T00:00:00.000',
        },
      ]);
      SharedPreferences.setMockInitialValues(<String, Object>{
        key: legacyPayload,
      });

      final repository = LocalTeacherRepository(storageKey: key);
      final list = await repository.list();
      expect(list, hasLength(1));
      expect(list.single.id, 'L1');
      expect(list.single.name, 'Legacy Name');
      expect(list.single.isActive, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List<dynamic>;
      final entry = decoded.single as Map<String, dynamic>;
      expect(entry.containsKey('name'), isTrue);
      expect(entry.containsKey('isActive'), isTrue);
      expect(entry.containsKey('fullName'), isFalse);
      expect(entry.containsKey('department'), isFalse);
      expect(entry.containsKey('email'), isFalse);
      expect(entry.containsKey('phone'), isFalse);
      expect(entry.containsKey('notes'), isFalse);
      expect(entry.containsKey('createdAt'), isFalse);
      expect(entry.containsKey('updatedAt'), isFalse);
      repository.dispose();
    });

    test('create update delete works with validation', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const key = 'teacher_repo_test_crud';
      final repository = LocalTeacherRepository(
        storageKey: key,
        seedTeachers: <Teacher>[],
      );

      await repository.create(
        Teacher(id: 'T50', name: 'Burcu Deniz', isActive: true),
      );
      expect(
        repository.create(
          Teacher(id: 'T50', name: 'Burcu Deniz', isActive: true),
        ),
        throwsA(isA<StateError>()),
      );

      await repository.update(
        Teacher(id: 'T50', name: 'Burcu Deniz Guncel', isActive: false),
      );
      final updated = await repository.getById('T50');
      expect(updated?.name, 'Burcu Deniz Guncel');
      expect(updated?.isActive, isFalse);

      await repository.deleteById('T50');
      expect(await repository.getById('T50'), isNull);
      repository.dispose();
    });
  });
}
