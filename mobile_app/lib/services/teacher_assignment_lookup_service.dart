import '../models/roster_row.dart';
import '../models/week.dart';
import 'cell_teacher_codec.dart';
import 'text_normalizer.dart';

class TeacherAssignmentLookupService {
  const TeacherAssignmentLookupService({
    CellTeacherCodec? cellTeacherCodec,
    TextNormalizer? textNormalizer,
  }) : _cellTeacherCodec = cellTeacherCodec ?? const CellTeacherCodec(),
       _textNormalizer = textNormalizer ?? const TextNormalizer();

  static const String _multiTeacherLineBreakToken = r'\n';

  final CellTeacherCodec _cellTeacherCodec;
  final TextNormalizer _textNormalizer;

  List<TeacherAssignmentEntry> assignmentsFromWeek({
    required Week week,
    required String teacherName,
    int? dayIndex,
  }) {
    return assignmentsFromRows(
      rows: week.rows,
      teacherName: teacherName,
      dayIndex: dayIndex,
    );
  }

  List<TeacherAssignmentEntry> assignmentsFromRows({
    required List<RosterRow> rows,
    required String teacherName,
    int? dayIndex,
  }) {
    final target = _textNormalizer.displayClean(teacherName);
    if (target.isEmpty) {
      return const <TeacherAssignmentEntry>[];
    }

    if (dayIndex != null && (dayIndex < 0 || dayIndex >= rosterDayCount)) {
      throw FormatException('Gecersiz gun secimi.');
    }

    final results = <TeacherAssignmentEntry>[];
    for (var currentDay = 0; currentDay < rosterDayCount; currentDay++) {
      if (dayIndex != null && currentDay != dayIndex) {
        continue;
      }

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final cellValue = currentDay < row.teachersByDay.length
            ? row.teachersByDay[currentDay]
            : '';
        final teachers = _cellTeacherCodec.parse(
          cellValue.replaceAll(_multiTeacherLineBreakToken, '\n'),
        );
        final hasTeacher = teachers.any(
          (name) => _textNormalizer.canonicalEquals(name, target),
        );
        if (!hasTeacher) {
          continue;
        }
        results.add(
          TeacherAssignmentEntry(
            dayIndex: currentDay,
            dayName: rosterDayNames[currentDay],
            rowIndex: rowIndex,
            location: row.location,
          ),
        );
      }
    }

    return List<TeacherAssignmentEntry>.unmodifiable(results);
  }
}

class TeacherAssignmentEntry {
  const TeacherAssignmentEntry({
    required this.dayIndex,
    required this.dayName,
    required this.rowIndex,
    required this.location,
  });

  final int dayIndex;
  final String dayName;
  final int rowIndex;
  final String location;
}
