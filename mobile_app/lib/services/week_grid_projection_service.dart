import '../models/roster_row.dart';
import '../models/week.dart';

class WeekGridProjection {
  const WeekGridProjection({required this.days});

  final List<WeekGridDay> days;

  WeekGridDay dayAt(int dayIndex) {
    return days.singleWhere((day) => day.dayIndex == dayIndex);
  }
}

class WeekGridDay {
  const WeekGridDay({
    required this.dayIndex,
    required this.dayName,
    required this.cells,
  });

  final int dayIndex;
  final String dayName;
  final List<WeekGridCell> cells;
}

class WeekGridCell {
  const WeekGridCell({
    required this.rowIndex,
    required this.dayIndex,
    required this.location,
    required this.teacher,
    required this.isDuplicateLocation,
  });

  final int rowIndex;
  final int dayIndex;
  final String location;
  final String teacher;
  final bool isDuplicateLocation;

  bool get isEmpty => teacher.isEmpty;
}

class WeekGridProjectionService {
  const WeekGridProjectionService();

  WeekGridProjection project(Week week) {
    final duplicateRows = _duplicateLocationRows(week.rows);
    final days = List<WeekGridDay>.generate(rosterDayCount, (dayIndex) {
      return WeekGridDay(
        dayIndex: dayIndex,
        dayName: rosterDayNames[dayIndex],
        cells: List<WeekGridCell>.unmodifiable(
          List<WeekGridCell>.generate(week.rows.length, (rowIndex) {
            final row = week.rows[rowIndex];
            return WeekGridCell(
              rowIndex: rowIndex,
              dayIndex: dayIndex,
              location: row.location,
              teacher: row.teachersByDay[dayIndex],
              isDuplicateLocation: duplicateRows.contains(rowIndex),
            );
          }),
        ),
      );
    });

    return WeekGridProjection(days: List<WeekGridDay>.unmodifiable(days));
  }

  Set<int> _duplicateLocationRows(List<RosterRow> rows) {
    final seen = <String, int>{};
    final duplicateRows = <int>{};

    for (var index = 0; index < rows.length; index++) {
      final key = rows[index].location;
      if (key.isEmpty) {
        continue;
      }
      final firstIndex = seen[key];
      if (firstIndex == null) {
        seen[key] = index;
      } else {
        duplicateRows
          ..add(firstIndex)
          ..add(index);
      }
    }

    return duplicateRows;
  }
}
