import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/teacher_repository.dart';
import 'package:nobetci_program_mobile/state/teacher_state.dart';
import 'package:nobetci_program_mobile/ui/screens/teacher_list_screen.dart';

void main() {
  group('TeacherListScreen', () {
    testWidgets('shows loading then empty state', (WidgetTester tester) async {
      final repository = _ControlledTeacherRepository();
      final state = TeacherState(repository: repository);

      await tester.pumpWidget(
        MaterialApp(home: TeacherListScreen(state: state)),
      );

      expect(
        find.byKey(const ValueKey('teacher-list-loading')),
        findsOneWidget,
      );

      repository.emit(const <Teacher>[]);
      await tester.pump();

      expect(find.byKey(const ValueKey('teacher-list-empty')), findsOneWidget);

      state.dispose();
      repository.dispose();
    });

    testWidgets('shows teacher list when data is available', (
      WidgetTester tester,
    ) async {
      final repository = _ControlledTeacherRepository();
      final state = TeacherState(repository: repository);

      await tester.pumpWidget(
        MaterialApp(home: TeacherListScreen(state: state)),
      );

      repository.emit(<Teacher>[
        Teacher(id: 'T001', name: 'Ali Yilmaz', isActive: true),
        Teacher(id: 'T002', name: 'Ayse Demir', isActive: true),
      ]);
      await tester.pump();

      expect(find.text('Öğretmen Listesi'), findsOneWidget);
      expect(find.text('Ali Yilmaz'), findsOneWidget);
      expect(find.text('Ayse Demir'), findsOneWidget);

      state.dispose();
      repository.dispose();
    });

    testWidgets('creates teacher from add form and updates list', (
      WidgetTester tester,
    ) async {
      final repository = _ControlledTeacherRepository();
      final state = TeacherState(repository: repository);

      await tester.pumpWidget(
        MaterialApp(home: TeacherListScreen(state: state)),
      );

      repository.emit(const <Teacher>[]);
      await tester.pump();
      expect(find.byKey(const ValueKey('teacher-list-empty')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('teacher-list-add-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('teacher-create-name')),
        'Yeni Ogretmen',
      );
      await tester.tap(find.byKey(const ValueKey('teacher-create-save')));
      await tester.pumpAndSettle();

      expect(find.text('Öğretmen Listesi'), findsOneWidget);
      expect(find.text('Yeni Ogretmen'), findsOneWidget);
      expect(find.text('Öğretmen eklendi.'), findsOneWidget);

      state.dispose();
      repository.dispose();
    });

    testWidgets('updates teacher from edit form and refreshes list', (
      WidgetTester tester,
    ) async {
      final repository = _ControlledTeacherRepository();
      final state = TeacherState(repository: repository);

      await tester.pumpWidget(
        MaterialApp(home: TeacherListScreen(state: state)),
      );

      repository.emit(<Teacher>[
        Teacher(id: 'T001', name: 'Ali Yilmaz', isActive: true),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T001')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('teacher-edit-name')),
        'Ali Yilmaz Guncel',
      );
      final saveButton = find.byKey(const ValueKey('teacher-edit-save'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Öğretmen güncellendi.'), findsOneWidget);
      expect(find.text('Ali Yilmaz Guncel'), findsOneWidget);

      state.dispose();
      repository.dispose();
    });

    testWidgets('deletes teacher with confirmation and refreshes list', (
      WidgetTester tester,
    ) async {
      final repository = _ControlledTeacherRepository();
      final state = TeacherState(repository: repository);
      Teacher? deletedTeacher;

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherListScreen(
            state: state,
            onTeacherDeletedFromRoster: (teacher) {
              deletedTeacher = teacher;
              return 2;
            },
          ),
        ),
      );

      repository.emit(<Teacher>[
        Teacher(id: 'T001', name: 'Ali Yilmaz', isActive: true),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T001')));
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(const ValueKey('teacher-edit-delete'));
      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Bu öğretmen kaydı silinsin mi?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('teacher-delete-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text('Öğretmen silindi. 2 hücre temizlendi.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('teacher-list-empty')), findsOneWidget);
      expect(deletedTeacher?.id, 'T001');
      expect(deletedTeacher?.name, 'Ali Yilmaz');

      state.dispose();
      repository.dispose();
    });
  });
}

class _ControlledTeacherRepository implements TeacherRepository {
  final StreamController<List<Teacher>> _controller =
      StreamController<List<Teacher>>.broadcast();
  List<Teacher> _current = const <Teacher>[];

  void emit(List<Teacher> teachers) {
    _current = List<Teacher>.unmodifiable(teachers);
    _controller.add(_current);
  }

  @override
  Future<void> create(Teacher teacher) async {
    final list = _current.toList(growable: true)..add(teacher);
    emit(list);
  }

  @override
  Future<void> deleteById(String id) async {
    final list = _current.where((teacher) => teacher.id != id).toList();
    emit(list);
  }

  @override
  Future<Teacher?> getById(String id) async {
    for (final teacher in _current) {
      if (teacher.id == id) {
        return teacher;
      }
    }
    return null;
  }

  @override
  Future<List<Teacher>> list() async {
    return _current;
  }

  @override
  Future<void> update(Teacher teacher) async {
    final list = _current.toList(growable: true);
    final index = list.indexWhere((item) => item.id == teacher.id);
    if (index >= 0) {
      list[index] = teacher;
      emit(list);
    }
  }

  @override
  Stream<List<Teacher>> watch() {
    return _controller.stream;
  }

  void dispose() {
    _controller.close();
  }
}
