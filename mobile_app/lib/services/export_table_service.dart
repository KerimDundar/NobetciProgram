import '../models/roster_row.dart';
import '../models/week.dart';
import 'duplicate_location_service.dart';
import 'text_normalizer.dart';

class ExportCellSpan {
  const ExportCellSpan({
    required this.column,
    required this.startRow,
    required this.endRow,
  });

  final int column;
  final int startRow;
  final int endRow;
}

class ExportWeekTable {
  const ExportWeekTable({required this.bodyRows, required this.spans});

  final List<List<String>> bodyRows;
  final List<ExportCellSpan> spans;
}

class ExportTableService {
  const ExportTableService({
    DuplicateLocationService duplicateLocationService =
        const DuplicateLocationService(),
    TextNormalizer normalizer = const TextNormalizer(),
  }) : _duplicateLocationService = duplicateLocationService,
       _normalizer = normalizer;

  final DuplicateLocationService _duplicateLocationService;
  final TextNormalizer _normalizer;

  ExportWeekTable buildWeekTable(Week week) {
    final bodyRows = week.rows
        .map((row) {
          return <String>[
            _normalizer.displayClean(row.location),
            for (var day = 0; day < rosterDayCount; day++)
              _normalizer.displayClean(row.teachersByDay[day]),
          ];
        })
        .toList(growable: true);

    if (bodyRows.isEmpty) {
      bodyRows.add(List<String>.filled(1 + rosterDayCount, ''));
    }

    final spans = <ExportCellSpan>[];
    _applyDuplicateLocationPairs(bodyRows, spans);

    return ExportWeekTable(
      bodyRows: List<List<String>>.unmodifiable(
        bodyRows.map((row) => List<String>.unmodifiable(row)),
      ),
      spans: List<ExportCellSpan>.unmodifiable(spans),
    );
  }

  /// Maps desktop duplicate-location export merge pair scanning.
  void _applyDuplicateLocationPairs(
    List<List<String>> rows,
    List<ExportCellSpan> spans,
  ) {
    var topRow = 0;
    while (topRow < rows.length - 1) {
      final bottomRow = topRow + 1;
      if (_duplicateLocationService.isDuplicateLocation(
        rows[topRow][0],
        rows[bottomRow][0],
      )) {
        _mergeDuplicatePair(rows, spans, topRow, bottomRow);
        topRow += 2;
      } else {
        topRow += 1;
      }
    }
  }

  void _mergeDuplicatePair(
    List<List<String>> rows,
    List<ExportCellSpan> spans,
    int topRow,
    int bottomRow,
  ) {
    final topLocation = _normalizer.displayClean(rows[topRow][0]);
    final bottomLocation = _normalizer.displayClean(rows[bottomRow][0]);
    rows[topRow][0] = topLocation.isNotEmpty ? topLocation : bottomLocation;
    rows[bottomRow][0] = '';
    spans.add(ExportCellSpan(column: 0, startRow: topRow, endRow: bottomRow));

    for (var column = 1; column <= rosterDayCount; column++) {
      _mergeTeacherColumnInPair(rows, spans, topRow, bottomRow, column);
    }
  }

  void _mergeTeacherColumnInPair(
    List<List<String>> rows,
    List<ExportCellSpan> spans,
    int topRow,
    int bottomRow,
    int column,
  ) {
    final topName = _normalizer.displayClean(rows[topRow][column]);
    final bottomName = _normalizer.displayClean(rows[bottomRow][column]);
    rows[topRow][column] = topName;
    rows[bottomRow][column] = bottomName;
    if (topName.isNotEmpty &&
        bottomName.isNotEmpty &&
        !_normalizer.canonicalEquals(topName, bottomName)) {
      return;
    }

    rows[topRow][column] = topName.isNotEmpty ? topName : bottomName;
    rows[bottomRow][column] = '';
    spans.add(
      ExportCellSpan(column: column, startRow: topRow, endRow: bottomRow),
    );
  }
}
