import '../models/roster_row.dart';
import 'text_normalizer.dart';

class RosterService {
  const RosterService({TextNormalizer normalizer = const TextNormalizer()})
    : _normalizer = normalizer;

  final TextNormalizer _normalizer;

  List<RosterRow> normalizeRows(List<RosterRow> rows) {
    return List<RosterRow>.unmodifiable(
      rows.map(
        (row) => RosterRow(
          location: _normalizer.displayClean(row.location),
          teachersByDay: row.teachersByDay
              .map(_normalizer.displayClean)
              .toList(growable: false),
        ),
      ),
    );
  }

  List<RosterRow> prepareRowsForSave(List<RosterRow> rows) {
    final prepared = <RosterRow>[];

    for (final row in normalizeRows(rows)) {
      final hasLocation = row.location.trim().isNotEmpty;
      final hasTeacher = row.teachersByDay.any((teacher) {
        return teacher.trim().isNotEmpty;
      });

      if (!hasLocation && !hasTeacher) {
        continue;
      }
      if (!hasLocation && hasTeacher) {
        throw const FormatException('Dolu bir satırda görev yeri boş olamaz.');
      }
      prepared.add(row);
    }

    return List<RosterRow>.unmodifiable(prepared);
  }

  RosterRow normalizeRow({
    required String? location,
    required List<String?>? teachersByDay,
  }) {
    return RosterRow(
      location: _normalizer.displayClean(location),
      teachersByDay: teachersByDay
          ?.map(_normalizer.displayClean)
          .toList(growable: false),
    );
  }

  /// Maps roster_logic.rotate_roster.
  List<RosterRow> rotateForward(List<RosterRow> rows) {
    return _rotate(rows, forward: true);
  }

  /// Maps roster_logic.rotate_roster_back.
  List<RosterRow> rotateBackward(List<RosterRow> rows) {
    return _rotate(rows, forward: false);
  }

  List<RosterRow> _rotate(List<RosterRow> rows, {required bool forward}) {
    final sourceRows = normalizeRows(rows);
    if (sourceRows.isEmpty) {
      return const [];
    }

    final nextRows = sourceRows
        .map((row) => row.teachersByDay.toList(growable: true))
        .toList(growable: true);

    for (var column = 0; column < rosterDayCount; column++) {
      final indices = <int>[];
      final names = <String>[];

      for (var rowIndex = 0; rowIndex < sourceRows.length; rowIndex++) {
        final value = sourceRows[rowIndex].teachersByDay[column];
        if (value.trim().isNotEmpty) {
          indices.add(rowIndex);
          names.add(value);
        }
      }

      if (names.isEmpty) {
        continue;
      }

      final rotated = forward
          ? <String>[...names.skip(1), names.first]
          : <String>[names.last, ...names.take(names.length - 1)];

      for (var i = 0; i < indices.length; i++) {
        nextRows[indices[i]][column] = rotated[i];
      }
    }

    return List<RosterRow>.generate(
      sourceRows.length,
      (index) => sourceRows[index].copyWith(teachersByDay: nextRows[index]),
    );
  }
}
