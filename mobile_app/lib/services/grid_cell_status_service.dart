import 'week_grid_projection_service.dart';
import 'text_normalizer.dart';

enum GridCellStatus { empty, filled, conflict }

class GridCellStatusService {
  const GridCellStatusService({TextNormalizer? textNormalizer})
    : _textNormalizer = textNormalizer ?? const TextNormalizer();

  final TextNormalizer _textNormalizer;

  GridCellStatus statusForCell({
    required WeekGridDay day,
    required WeekGridCell cell,
  }) {
    final canonicalTeachers = cell.teachers
        .map(_textNormalizer.canonical)
        .where((name) => name.isNotEmpty)
        .toSet();
    if (canonicalTeachers.isEmpty) {
      return GridCellStatus.empty;
    }

    final runId = cell.duplicateRunId;
    if (runId != null) {
      final distinctSignatures = day.cells
          .where((candidate) => candidate.duplicateRunId == runId)
          .map((candidate) {
            final names =
                candidate.teachers
                    .map(_textNormalizer.canonical)
                    .where((name) => name.isNotEmpty)
                    .toSet()
                    .toList(growable: false)
                  ..sort();
            if (names.isEmpty) {
              return '';
            }
            return names.join('\u0001');
          })
          .where((signature) => signature.isNotEmpty)
          .toSet();
      if (distinctSignatures.length > 1) {
        return GridCellStatus.conflict;
      }
    }
    return GridCellStatus.filled;
  }
}
