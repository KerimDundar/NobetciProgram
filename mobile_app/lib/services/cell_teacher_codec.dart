import 'text_normalizer.dart';

class CellTeacherCodec {
  const CellTeacherCodec({TextNormalizer normalizer = const TextNormalizer()})
    : _normalizer = normalizer;

  final TextNormalizer _normalizer;

  List<String> parse(String cell) {
    final parts = cell.replaceAll('\r\n', '\n').split('\n');
    final uniqueByCanonical = <String>{};
    final result = <String>[];

    for (final part in parts) {
      final cleaned = _normalizer.displayClean(part);
      if (cleaned.isEmpty) {
        continue;
      }
      final canonical = _normalizer.canonical(cleaned);
      if (canonical.isEmpty || uniqueByCanonical.contains(canonical)) {
        continue;
      }
      uniqueByCanonical.add(canonical);
      result.add(cleaned);
    }

    return List<String>.unmodifiable(result);
  }

  String serialize(List<String> teachers) {
    final uniqueByCanonical = <String>{};
    final values = <String>[];

    for (final teacher in teachers) {
      final cleaned = _normalizer.displayClean(teacher);
      if (cleaned.isEmpty) {
        continue;
      }
      final canonical = _normalizer.canonical(cleaned);
      if (canonical.isEmpty || uniqueByCanonical.contains(canonical)) {
        continue;
      }
      uniqueByCanonical.add(canonical);
      values.add(cleaned);
    }

    return values.join('\n');
  }

  String addTeacher(String cell, String teacherName) {
    final name = _normalizer.displayClean(teacherName);
    if (name.isEmpty) {
      return serialize(parse(cell));
    }

    final teachers = parse(cell).toList(growable: true);
    if (containsTeacher(cell, name)) {
      return serialize(teachers);
    }
    teachers.add(name);
    return serialize(teachers);
  }

  String removeTeacher(String cell, String teacherName) {
    final target = _normalizer.displayClean(teacherName);
    if (target.isEmpty) {
      return serialize(parse(cell));
    }

    final filtered = parse(cell)
        .where((teacher) => !_normalizer.canonicalEquals(teacher, target))
        .toList(growable: false);
    return serialize(filtered);
  }

  bool containsTeacher(String cell, String teacherName) {
    final target = _normalizer.displayClean(teacherName);
    if (target.isEmpty) {
      return false;
    }

    for (final teacher in parse(cell)) {
      if (_normalizer.canonicalEquals(teacher, target)) {
        return true;
      }
    }
    return false;
  }
}
