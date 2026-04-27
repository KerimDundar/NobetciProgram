import '../models/planning_mode.dart';
import '../models/roster_row.dart';
import '../models/week.dart';
import 'roster_service.dart';
import 'text_normalizer.dart';

enum WeekValidationError { tooLong, invalidRange, notFullMonth }

const int weekStepDays = 7;

const List<String> turkishMonths = [
  'OCAK',
  '\u015EUBAT',
  'MART',
  'N\u0130SAN',
  'MAYIS',
  'HAZ\u0130RAN',
  'TEMMUZ',
  'A\u011EUSTOS',
  'EYL\u00DCL',
  'EK\u0130M',
  'KASIM',
  'ARALIK',
];

const String titleSuffix =
    'HAFTASI N\u00D6BET\u00C7\u0130 \u00D6\u011ERETMEN L\u0130STES\u0130';

class WeekDateRange {
  const WeekDateRange({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;
}

class ParsedWeekTitle {
  const ParsedWeekTitle({
    required this.startDate,
    required this.endDate,
    required this.suffix,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String suffix;
}

class WeekService {
  WeekService({
    RosterService? rosterService,
    TextNormalizer normalizer = const TextNormalizer(),
  }) : _rosterService = rosterService ?? RosterService(normalizer: normalizer),
       _normalizer = normalizer;

  final RosterService _rosterService;
  final TextNormalizer _normalizer;

  /// Maps roster_logic.build_week.
  Week buildWeek({
    required DateTime startDate,
    required DateTime endDate,
    required List<RosterRow> rows,
    String schoolName = '',
    String principalName = '',
  }) {
    return Week(
      title: buildTitle(startDate, endDate),
      startDate: startDate,
      endDate: endDate,
      schoolName: _normalizer.displayClean(schoolName),
      principalName: _normalizer.displayClean(principalName),
      rows: _rosterService.normalizeRows(rows),
    );
  }

  /// Maps roster_logic.build_next_week.
  Week buildNextWeek(Week current) {
    final range = nextWeekDates(current.startDate, current.endDate);
    return buildWeek(
      startDate: range.startDate,
      endDate: range.endDate,
      rows: _rosterService.rotateForward(current.rows),
      schoolName: current.schoolName,
      principalName: current.principalName,
    );
  }

  Week nextWeek(Week current) {
    return buildNextWeek(current);
  }

  List<Week> generateMonthlyFromWeek(Week current) {
    final weeks = <Week>[current];
    for (var i = 0; i < 3; i++) {
      weeks.add(buildNextWeek(weeks.last));
    }
    return List.unmodifiable(weeks);
  }

  DateTime monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime monthEnd(DateTime date) => DateTime(date.year, date.month + 1, 0);

  WeekDateRange currentMonthRange(DateTime now) =>
      WeekDateRange(startDate: monthStart(now), endDate: monthEnd(now));

  WeekValidationError? validateDateRange(
    DateTime startDate,
    DateTime endDate,
    PlanningMode mode,
  ) {
    if (endDate.isBefore(startDate)) return WeekValidationError.invalidRange;
    return switch (mode) {
      PlanningMode.weekly =>
        endDate.difference(startDate).inDays >= 7
            ? WeekValidationError.tooLong
            : null,
      PlanningMode.monthly => _validateMonthly(startDate, endDate),
    };
  }

  WeekValidationError? _validateMonthly(DateTime startDate, DateTime endDate) {
    if (startDate != monthStart(startDate) || endDate != monthEnd(startDate)) {
      return WeekValidationError.notFullMonth;
    }
    return null;
  }

  Week previousWeek(Week current) {
    return buildWeek(
      startDate: current.startDate.subtract(const Duration(days: weekStepDays)),
      endDate: current.endDate.subtract(const Duration(days: weekStepDays)),
      rows: _rosterService.rotateBackward(current.rows),
      schoolName: current.schoolName,
      principalName: current.principalName,
    );
  }

  /// Maps roster_logic.next_week_dates.
  WeekDateRange nextWeekDates(DateTime startDate, DateTime endDate) {
    return WeekDateRange(
      startDate: startDate.add(const Duration(days: weekStepDays)),
      endDate: endDate.add(const Duration(days: weekStepDays)),
    );
  }

  /// Maps roster_logic.parse_title with FIX 2 and FIX 3.
  ParsedWeekTitle parseTitle(String title, int defaultYear) {
    if (defaultYear < 1 || defaultYear > 9999) {
      throw const FormatException('Ge\u00E7ersiz y\u0131l.');
    }

    final cleanedTitle = _normalizer.displayClean(title);
    if (cleanedTitle.isEmpty) {
      throw const FormatException('Ba\u015Fl\u0131k bo\u015F.');
    }

    final canonicalTitle = _normalizer.canonical(cleanedTitle);
    if (!canonicalTitle.contains(_normalizer.canonical(titleSuffix))) {
      throw const FormatException(
        'Ba\u015Fl\u0131k beklenen ifadeyi i\u00E7ermiyor.',
      );
    }

    final match = RegExp(
      '(\\d{1,2})\\s+([A-Z\\u00C7\\u011E\\u0130\\u00D6\\u015E\\u00DC]+)'
      '\\s*-\\s*'
      '(\\d{1,2})\\s+([A-Z\\u00C7\\u011E\\u0130\\u00D6\\u015E\\u00DC]+)',
      unicode: true,
    ).firstMatch(canonicalTitle);
    if (match == null) {
      throw const FormatException(
        'Ba\u015Fl\u0131ktan tarih aral\u0131\u011F\u0131 okunamad\u0131.',
      );
    }

    final startDay = _parsePositiveInt(match.group(1)!);
    final startMonthName = match.group(2)!;
    final endDay = _parsePositiveInt(match.group(3)!);
    final endMonthName = match.group(4)!;
    final startMonth = _monthNumberByCanonicalName[startMonthName];
    final endMonth = _monthNumberByCanonicalName[endMonthName];
    if (startMonth == null || endMonth == null) {
      throw const FormatException(
        'Ba\u015Fl\u0131kta bilinmeyen T\u00FCrk\u00E7e ay ad\u0131 var.',
      );
    }

    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(canonicalTitle);
    final startYear = yearMatch == null
        ? defaultYear
        : _parsePositiveInt(yearMatch.group(1)!);
    final endYear = endMonth < startMonth ? startYear + 1 : startYear;

    return ParsedWeekTitle(
      startDate: _strictDate(startYear, startMonth, startDay),
      endDate: _strictDate(endYear, endMonth, endDay),
      suffix: titleSuffix,
    );
  }

  /// Maps roster_logic.build_title.
  String buildTitle(DateTime startDate, DateTime endDate) {
    final startMonth = turkishMonths[startDate.month - 1];
    final endMonth = turkishMonths[endDate.month - 1];
    return '${startDate.day} $startMonth-${endDate.day} $endMonth $titleSuffix';
  }

  DateTime _strictDate(int year, int month, int day) {
    if (year < 1 || year > 9999) {
      throw const FormatException('Ge\u00E7ersiz tarih.');
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Ge\u00E7ersiz tarih.');
    }
    return parsed;
  }

  int _parsePositiveInt(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) {
      throw const FormatException('Ge\u00E7ersiz tarih.');
    }
    return parsed;
  }

  late final Map<String, int> _monthNumberByCanonicalName = {
    for (var i = 0; i < turkishMonths.length; i++)
      _normalizer.canonical(turkishMonths[i]): i + 1,
  };
}
