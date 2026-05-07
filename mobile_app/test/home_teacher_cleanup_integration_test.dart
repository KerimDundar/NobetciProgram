import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/teacher_repository.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/state/teacher_state.dart';
import 'package:nobetci_program_mobile/ui/screens/roster_home_screen.dart';

void main() {
  testWidgets('teacher delete clears assigned roster cells from home flow', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rosterState = RosterState.initial();
    final teacherState = TeacherState(
      repository: InMemoryTeacherRepository(
        initialTeachers: <Teacher>[
          Teacher(id: 'T001', name: 'Ali Yılmaz', isActive: true),
        ],
      ),
    );
    await teacherState.ready;

    expect(rosterState.currentWeek.rows[0].teachersByDay[0], 'Ali Yılmaz');

    await tester.pumpWidget(
      MaterialApp(
        home: RosterHomeScreen(state: rosterState, teacherState: teacherState),
      ),
    );

    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-item-teachers')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T001')));
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const ValueKey('teacher-edit-delete'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('teacher-delete-confirm')));
    await tester.pumpAndSettle();

    expect(rosterState.currentWeek.rows[0].teachersByDay[0], '');
    expect(find.text('Öğretmen silindi. 1 hücre temizlendi.'), findsOneWidget);

    teacherState.dispose();
    rosterState.dispose();
  });
}
