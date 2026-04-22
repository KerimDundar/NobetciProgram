const int rosterDayCount = 5;

const List<String> rosterDayNames = [
  'PAZARTESİ',
  'SALI',
  'ÇARŞAMBA',
  'PERŞEMBE',
  'CUMA',
];

class RosterRow {
  RosterRow({required String? location, required List<String?>? teachersByDay})
    : location = _cleanText(location),
      teachersByDay = _normalizeTeachers(teachersByDay ?? const []);

  final String location;
  final List<String> teachersByDay;

  RosterRow copyWith({String? location, List<String?>? teachersByDay}) {
    return RosterRow(
      location: location ?? this.location,
      teachersByDay: teachersByDay ?? this.teachersByDay,
    );
  }

  static List<String> _normalizeTeachers(List<String?> values) {
    final normalized = List<String>.generate(rosterDayCount, (index) {
      if (index >= values.length) {
        return '';
      }
      return _cleanText(values[index]);
    });
    return List<String>.unmodifiable(normalized);
  }

  static String _cleanText(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
