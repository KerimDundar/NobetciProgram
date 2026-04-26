import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/roster_row.dart';
import 'package:nobetci_program_mobile/models/week.dart';
import 'package:nobetci_program_mobile/services/grid_cell_status_service.dart';
import 'package:nobetci_program_mobile/services/week_grid_projection_service.dart';

void main() {
  group('WeekGridProjectionService duplicate run metadata', () {
    const service = WeekGridProjectionService();

    test('marks 3-run as 2-merged + 1-tail', () {
      final week = Week(
        title: 'T',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahce', teachersByDay: ['Ali']),
          RosterRow(location: 'Bahce', teachersByDay: ['Ali']),
          RosterRow(location: 'Bahce', teachersByDay: ['Ali']),
        ],
      );

      final monday = service.project(week).dayAt(0);
      expect(monday.cells.map((cell) => cell.duplicateRunGroup), [
        '2-merged',
        '2-merged',
        '1-tail',
      ]);
      expect(monday.cells.map((cell) => cell.duplicateRunSize), [3, 3, 3]);
    });

    test('marks 4-run as 2+2 segments', () {
      final week = Week(
        title: 'T',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Koridor', teachersByDay: ['A']),
          RosterRow(location: 'Koridor', teachersByDay: ['A']),
          RosterRow(location: 'Koridor', teachersByDay: ['A']),
          RosterRow(location: 'Koridor', teachersByDay: ['A']),
        ],
      );

      final monday = service.project(week).dayAt(0);
      expect(monday.cells.map((cell) => cell.duplicateRunGroup), [
        '2-merged-a',
        '2-merged-a',
        '2-merged-b',
        '2-merged-b',
      ]);
      expect(monday.cells.map((cell) => cell.duplicateRunSize), [4, 4, 4, 4]);
    });
  });

  group('GridCellStatusService', () {
    const projectionService = WeekGridProjectionService();
    const statusService = GridCellStatusService();

    test(
      'returns conflict when duplicate run has different non-empty names',
      () {
        final week = Week(
          title: 'T',
          startDate: DateTime(2026, 2, 2),
          endDate: DateTime(2026, 2, 6),
          rows: [
            RosterRow(location: 'Bahce', teachersByDay: ['Ali']),
            RosterRow(location: 'Bahce', teachersByDay: ['Ayse']),
          ],
        );

        final monday = projectionService.project(week).dayAt(0);
        final statuses = monday.cells
            .map((cell) => statusService.statusForCell(day: monday, cell: cell))
            .toList(growable: false);
        expect(statuses, [GridCellStatus.conflict, GridCellStatus.conflict]);
      },
    );

    test('returns empty and filled for normal rows', () {
      final week = Week(
        title: 'T',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahce', teachersByDay: ['Ali']),
          RosterRow(location: 'Koridor', teachersByDay: ['']),
        ],
      );

      final monday = projectionService.project(week).dayAt(0);
      expect(
        statusService.statusForCell(day: monday, cell: monday.cells[0]),
        GridCellStatus.filled,
      );
      expect(
        statusService.statusForCell(day: monday, cell: monday.cells[1]),
        GridCellStatus.empty,
      );
    });

    test('returns filled when same teacher is assigned twice in same day', () {
      final week = Week(
        title: 'T',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahce', teachersByDay: ['Ali Yilmaz']),
          RosterRow(location: 'Koridor', teachersByDay: ['Ali Yilmaz']),
        ],
      );

      final monday = projectionService.project(week).dayAt(0);
      final statuses = monday.cells
          .map((cell) => statusService.statusForCell(day: monday, cell: cell))
          .toList(growable: false);
      expect(statuses, [GridCellStatus.filled, GridCellStatus.filled]);
    });
  });
}
