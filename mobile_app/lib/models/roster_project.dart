import 'planning_mode.dart';
import 'roster_row.dart';
import 'teacher.dart';
import 'week.dart';

class RosterProject {
  RosterProject({
    required this.id,
    required this.name,
    required this.planningMode,
    required this.currentWeek,
    required List<Teacher> teachers,
    required this.createdAt,
    required this.updatedAt,
  }) : teachers = List<Teacher>.unmodifiable(teachers);

  final String id;
  final String name;
  final PlanningMode planningMode;
  final Week currentWeek;
  final List<Teacher> teachers;
  final DateTime createdAt;
  final DateTime updatedAt;

  RosterProject copyWith({
    String? id,
    String? name,
    PlanningMode? planningMode,
    Week? currentWeek,
    List<Teacher>? teachers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RosterProject(
      id: id ?? this.id,
      name: name ?? this.name,
      planningMode: planningMode ?? this.planningMode,
      currentWeek: currentWeek ?? this.currentWeek,
      teachers: teachers ?? this.teachers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'planningMode': planningMode.name,
      'currentWeek': _weekToJson(currentWeek),
      'teachers': teachers.map(_teacherToJson).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RosterProject.fromJson(Map<String, dynamic> json) {
    return RosterProject(
      id: json['id'] as String,
      name: json['name'] as String,
      planningMode: PlanningMode.values.firstWhere(
        (m) => m.name == json['planningMode'],
        orElse: () => PlanningMode.weekly,
      ),
      currentWeek: _weekFromJson(json['currentWeek'] as Map<String, dynamic>),
      teachers: (json['teachers'] as List<dynamic>)
          .map((t) => _teacherFromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

Map<String, dynamic> _weekToJson(Week week) {
  return {
    'title': week.title,
    'startDate': week.startDate.toIso8601String(),
    'endDate': week.endDate.toIso8601String(),
    'schoolName': week.schoolName,
    'principalName': week.principalName,
    'rows': week.rows.map(_rowToJson).toList(),
  };
}

Week _weekFromJson(Map<String, dynamic> json) {
  return Week(
    title: json['title'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    schoolName: (json['schoolName'] as String?) ?? '',
    principalName: (json['principalName'] as String?) ?? '',
    rows: (json['rows'] as List<dynamic>)
        .map((r) => _rowFromJson(r as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _rowToJson(RosterRow row) {
  return {
    'location': row.location,
    'teachersByDay': row.teachersByDay.toList(),
  };
}

RosterRow _rowFromJson(Map<String, dynamic> json) {
  return RosterRow(
    location: json['location'] as String?,
    teachersByDay:
        (json['teachersByDay'] as List<dynamic>).cast<String>(),
  );
}

Map<String, dynamic> _teacherToJson(Teacher teacher) {
  return {
    'id': teacher.id,
    'name': teacher.name,
    'isActive': teacher.isActive,
  };
}

Teacher _teacherFromJson(Map<String, dynamic> json) {
  return Teacher(
    id: json['id'] as String?,
    name: json['name'] as String?,
    isActive: json['isActive'] as bool?,
  );
}
