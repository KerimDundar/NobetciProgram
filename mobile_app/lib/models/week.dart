import 'roster_row.dart';

class Week {
  Week({
    required this.title,
    required this.startDate,
    required this.endDate,
    required List<RosterRow> rows,
    this.schoolName = '',
    this.principalName = '',
  }) : rows = List<RosterRow>.unmodifiable(rows);

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String schoolName;
  final String principalName;
  final List<RosterRow> rows;

  List<String> get locations => rows.map((row) => row.location).toList();

  List<List<String>> get roster =>
      rows.map((row) => row.teachersByDay.toList()).toList();

  Week copyWith({
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? schoolName,
    String? principalName,
    List<RosterRow>? rows,
  }) {
    return Week(
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      schoolName: schoolName ?? this.schoolName,
      principalName: principalName ?? this.principalName,
      rows: rows ?? this.rows,
    );
  }
}
