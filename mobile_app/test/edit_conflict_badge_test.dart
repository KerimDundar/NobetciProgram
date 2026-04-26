import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/roster_row.dart';
import 'package:nobetci_program_mobile/models/week.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/edit_week_screen.dart';

void main() {
  testWidgets(
    'edit grid shows conflict badge for duplicate teacher on same day',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1080, 2200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = RosterState(
        currentWeek: Week(
          title: 'T',
          startDate: DateTime(2026, 2, 2),
          endDate: DateTime(2026, 2, 6),
          rows: [
            RosterRow(location: 'Bahce', teachersByDay: ['Ali Yilmaz']),
            RosterRow(location: 'Koridor', teachersByDay: ['Ali Yilmaz']),
          ],
        ),
      );

      await tester.pumpWidget(MaterialApp(home: EditWeekScreen(state: state)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_outlined), findsNWidgets(2));

      state.dispose();
    },
  );
}
