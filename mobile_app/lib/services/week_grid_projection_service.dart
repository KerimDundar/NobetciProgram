import '../models/roster_row.dart';
import '../models/week.dart';
import 'cell_teacher_codec.dart';

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
    required this.teachers,
    required this.isDuplicateLocation,
    required this.duplicateRunId,
    required this.duplicateRunSize,
    required this.duplicateRunGroup,
  });

  final int rowIndex;
  final int dayIndex;
  final String location;
  final String teacher;
  final List<String> teachers;
  final bool isDuplicateLocation;
  final int? duplicateRunId;
  final int duplicateRunSize;
  final String duplicateRunGroup;

  bool get isEmpty => teachers.isEmpty;
}

class WeekGridProjectionService {
  const WeekGridProjectionService({CellTeacherCodec? cellTeacherCodec})
    : _cellTeacherCodec = cellTeacherCodec ?? const CellTeacherCodec();

  static const String _multiTeacherLineBreakToken = r'\n';
  final CellTeacherCodec _cellTeacherCodec;

  WeekGridProjection project(Week week) {
    final duplicateRows = _duplicateLocationRows(week.rows);
    final duplicateRuns = _duplicateRunInfo(week.rows);
    final days = List<WeekGridDay>.generate(rosterDayCount, (dayIndex) {
      return WeekGridDay(
        dayIndex: dayIndex,
        dayName: rosterDayNames[dayIndex],
        cells: List<WeekGridCell>.unmodifiable(
          List<WeekGridCell>.generate(week.rows.length, (rowIndex) {
            final row = week.rows[rowIndex];
            final rawCellTeacher = row.teachersByDay[dayIndex].replaceAll(
              _multiTeacherLineBreakToken,
              '\n',
            );
            final parsedTeachers = _cellTeacherCodec.parse(rawCellTeacher);
            return WeekGridCell(
              rowIndex: rowIndex,
              dayIndex: dayIndex,
              location: row.location,
              teacher: parsedTeachers.join('\n'),
              teachers: List<String>.unmodifiable(parsedTeachers),
              isDuplicateLocation: duplicateRows.contains(rowIndex),
              duplicateRunId: duplicateRuns[rowIndex]?.runId,
              duplicateRunSize: duplicateRuns[rowIndex]?.runSize ?? 0,
              duplicateRunGroup:
                  duplicateRuns[rowIndex]?.groupLabel ?? 'single',
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

  Map<int, _DuplicateRunMeta> _duplicateRunInfo(List<RosterRow> rows) {
    final result = <int, _DuplicateRunMeta>{};
    var runId = 0;
    var index = 0;

    while (index < rows.length) {
      final key = rows[index].location.trim();
      if (key.isEmpty) {
        index += 1;
        continue;
      }

      var end = index + 1;
      while (end < rows.length &&
          rows[end].location.trim().toLowerCase() == key.toLowerCase()) {
        end += 1;
      }

      final runSize = end - index;
      if (runSize >= 2) {
        runId += 1;
        final groups = _groupLabels(runSize);
        for (var offset = 0; offset < runSize; offset++) {
          result[index + offset] = _DuplicateRunMeta(
            runId: runId,
            runSize: runSize,
            groupLabel: groups[offset],
          );
        }
      }
      index = end;
    }

    return result;
  }

  List<String> _groupLabels(int runSize) {
    if (runSize == 2) {
      return const ['2-merged', '2-merged'];
    }
    if (runSize == 3) {
      return const ['2-merged', '2-merged', '1-tail'];
    }
    if (runSize == 4) {
      return const ['2-merged-a', '2-merged-a', '2-merged-b', '2-merged-b'];
    }
    final labels = <String>[];
    for (var i = 0; i < runSize; i++) {
      final pairIndex = i ~/ 2;
      labels.add('pair-$pairIndex');
    }
    return labels;
  }
}

class _DuplicateRunMeta {
  const _DuplicateRunMeta({
    required this.runId,
    required this.runSize,
    required this.groupLabel,
  });

  final int runId;
  final int runSize;
  final String groupLabel;
}
