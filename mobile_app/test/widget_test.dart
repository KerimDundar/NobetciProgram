import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nobetci_program_mobile/main.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/roster_home_screen.dart';

void main() {
  testWidgets('shows current roster state on home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Bahçe'), 120);
    expect(find.text('Bahçe'), findsOneWidget);
  });

  testWidgets(
    'edit screen hides manual teacher input and keeps picker action',
    (WidgetTester tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text('Hafta Düzenle'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-grid-teacher-input-0-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('edit-grid-pick-teacher-0-0')),
        findsOneWidget,
      );
    },
  );

  testWidgets('picker adds teacher to cell and save persists roster', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final state = RosterState.initial();
    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('edit-grid-teacher-empty-0-2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-grid-pick-teacher-0-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T002')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
      findsOneWidget,
    );
    expect(find.text('Ayse Demir'), findsWidgets);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(state.currentWeek.rows[2].teachersByDay[0], 'Ayse Demir');
  });

  testWidgets(
    'same teacher on same day across locations does not block edit save',
    (WidgetTester tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(
        MaterialApp(home: RosterHomeScreen(state: state)),
      );

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('edit-grid-pick-teacher-0-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T001')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
      expect(find.text('Hafta kaydedildi.'), findsOneWidget);
      expect(state.currentWeek.rows[1].teachersByDay[0], isNotEmpty);
    },
  );
}

void _useTallTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
