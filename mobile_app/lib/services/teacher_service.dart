import '../models/teacher.dart';

class TeacherService {
  TeacherService({List<Teacher>? teachers})
    : _teachers = List<Teacher>.unmodifiable(
        (teachers ?? _defaultTeachers).where((teacher) => teacher.isValid),
      );

  final List<Teacher> _teachers;

  List<Teacher> all() {
    return List<Teacher>.unmodifiable(_teachers);
  }

  List<Teacher> search({String? query, bool availableOnly = false}) {
    final cleanQuery = _cleanText(query).toLowerCase();

    final filtered =
        _teachers
            .where((teacher) {
              if (availableOnly && !teacher.isActive) {
                return false;
              }
              if (cleanQuery.isEmpty) {
                return true;
              }
              final name = teacher.name.toLowerCase();
              final id = teacher.id.toLowerCase();
              return name.contains(cleanQuery) || id.contains(cleanQuery);
            })
            .toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name));

    return List<Teacher>.unmodifiable(filtered);
  }

  Teacher? findById(String? id) {
    final cleanId = _cleanText(id);
    if (cleanId.isEmpty) {
      return null;
    }
    for (final teacher in _teachers) {
      if (teacher.id == cleanId) {
        return teacher;
      }
    }
    return null;
  }

  static String _cleanText(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static final List<Teacher> _defaultTeachers = <Teacher>[
    Teacher(id: 'T001', name: 'Ali Yilmaz', isActive: true),
    Teacher(id: 'T002', name: 'Ayse Demir', isActive: true),
    Teacher(id: 'T003', name: 'Can Aydin', isActive: false),
    Teacher(id: 'T004', name: 'Fatma Sahin', isActive: true),
    Teacher(id: 'T005', name: 'Burak Celik', isActive: true),
  ];
}
