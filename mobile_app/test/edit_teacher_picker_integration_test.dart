import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/teacher_repository.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/state/teacher_state.dart';
import 'package:nobetci_program_mobile/ui/screens/edit_week_screen.dart';

void main() {
  testWidgets(
    'edit picker flow supports multi-teacher chips without manual input',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1080, 2200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final rosterState = RosterState.initial();
      final repository = InMemoryTeacherRepository(
        initialTeachers: <Teacher>[
          Teacher(id: 'T900', name: 'Yeni Ogretmen', isActive: true),
          Teacher(id: 'T901', name: 'Ikinci Ogretmen', isActive: true),
        ],
      );
      final teacherState = TeacherState(repository: repository);
      await teacherState.ready;

      await tester.pumpWidget(
        MaterialApp(
          home: EditWeekScreen(state: rosterState, teacherState: teacherState),
        ),
      );

      expect(
        find.byKey(const ValueKey('edit-grid-teacher-input-0-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-0-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-grid-teacher-empty-0-2')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('edit-grid-pick-teacher-0-2')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('teacher-picker-info-T900')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T900')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
        findsOneWidget,
      );
      expect(find.text('Yeni Ogretmen'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('edit-grid-pick-teacher-0-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('teacher-picker-info-T900')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('teacher-assignment-sheet-T900')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('teacher-assignment-item-T900-0')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('teacher-assignment-close-T900')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T901')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('edit-grid-pick-teacher-0-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T901')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-1')),
        findsOneWidget,
      );

      final firstChip = tester.widget<InputChip>(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
      );
      firstChip.onDeleted?.call();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
        findsOneWidget,
      );
      expect(find.text('Ikinci Ogretmen'), findsOneWidget);

      final lastChip = tester.widget<InputChip>(
        find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
      );
      lastChip.onDeleted?.call();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('edit-grid-teacher-empty-0-2')),
        findsOneWidget,
      );

      teacherState.dispose();
      repository.dispose();
      rosterState.dispose();
    },
  );
}
