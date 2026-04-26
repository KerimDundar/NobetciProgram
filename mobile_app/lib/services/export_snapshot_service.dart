import '../models/roster_row.dart';
import '../models/week.dart';
import 'roster_service.dart';
import 'text_normalizer.dart';

const List<String> _displayMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// Formats a date range for display in export headers.
/// Same year: "01 Nisan - 30 Nisan 2026"
/// Cross-year: "29 Aralık 2025 - 25 Ocak 2026"
String displayRange(DateTime start, DateTime end) {
  final startDay = start.day.toString().padLeft(2, '0');
  final endDay = end.day.toString().padLeft(2, '0');
  final startMonth = _displayMonths[start.month - 1];
  final endMonth = _displayMonths[end.month - 1];
  if (start.year == end.year) {
    return '$startDay $startMonth - $endDay $endMonth ${end.year}';
  }
  return '$startDay $startMonth ${start.year} - $endDay $endMonth ${end.year}';
}

class ExportSnapshot {
  ExportSnapshot._({required List<Week> weeks})
    : weeks = List<Week>.unmodifiable(weeks);

  final List<Week> weeks;

  bool get isEmpty => weeks.isEmpty;
  bool get isSingleWeek => weeks.length == 1;
  bool get isMultiWeek => weeks.length > 1;
}

class ExportSnapshotService {
  const ExportSnapshotService({
    RosterService rosterService = const RosterService(),
    TextNormalizer normalizer = const TextNormalizer(),
  }) : _rosterService = rosterService,
       _normalizer = normalizer;

  final RosterService _rosterService;
  final TextNormalizer _normalizer;

  ExportSnapshot fromCurrentWeek(Week currentWeek) {
    return fromPreviewWeeks([currentWeek]);
  }

  ExportSnapshot fromPreviewWeeks(Iterable<Week?> weeks) {
    final exportWeeks = <Week>[];

    for (final week in weeks) {
      if (!isValidWeekForExport(week)) {
        continue;
      }
      exportWeeks.add(_normalizeWeek(week!));
    }

    return ExportSnapshot._(weeks: exportWeeks);
  }

  bool isValidWeekForExport(Week? week) {
    if (week == null) {
      return false;
    }
    return _normalizer.displayClean(week.title).isNotEmpty;
  }

  Week _normalizeWeek(Week week) {
    final normalizedRows = _rosterService.prepareRowsForSave(week.rows);

    return Week(
      title: _normalizer.displayClean(week.title),
      startDate: week.startDate,
      endDate: week.endDate,
      schoolName: _normalizer.displayClean(week.schoolName),
      principalName: _normalizer.displayClean(week.principalName),
      rows: normalizedRows
          .map(
            (row) => RosterRow(
              location: row.location,
              teachersByDay: row.teachersByDay,
            ),
          )
          .toList(growable: false),
    );
  }
}
