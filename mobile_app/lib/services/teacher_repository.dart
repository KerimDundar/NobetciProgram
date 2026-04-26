import 'dart:async';

import '../models/teacher.dart';

abstract class TeacherRepository {
  Future<List<Teacher>> list();
  Stream<List<Teacher>> watch();
  Future<Teacher?> getById(String id);
  Future<void> create(Teacher teacher);
  Future<void> update(Teacher teacher);
  Future<void> deleteById(String id);
}

class InMemoryTeacherRepository implements TeacherRepository {
  InMemoryTeacherRepository({List<Teacher>? initialTeachers}) {
    final source = initialTeachers ?? _defaultTeachers;
    for (final teacher in source) {
      if (!teacher.isValid) {
        continue;
      }
      _items[teacher.id] = teacher;
    }
  }

  final Map<String, Teacher> _items = <String, Teacher>{};
  final StreamController<List<Teacher>> _controller =
      StreamController<List<Teacher>>.broadcast();

  @override
  Future<List<Teacher>> list() async {
    return _snapshot();
  }

  @override
  Stream<List<Teacher>> watch() {
    return Stream<List<Teacher>>.multi((multi) {
      multi.add(_snapshot());
      final subscription = _controller.stream.listen(
        multi.add,
        onError: multi.addError,
      );
      multi.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  @override
  Future<Teacher?> getById(String id) async {
    final cleanId = _cleanText(id);
    if (cleanId.isEmpty) {
      return null;
    }
    return _items[cleanId];
  }

  @override
  Future<void> create(Teacher teacher) async {
    final cleanTeacher = teacher.copyWith(
      id: teacher.id,
      name: teacher.name,
      isActive: teacher.isActive,
    );
    if (!cleanTeacher.isValid) {
      throw const FormatException('Teacher kaydi gecersiz.');
    }
    if (_items.containsKey(cleanTeacher.id)) {
      throw StateError('Teacher zaten mevcut: ${cleanTeacher.id}');
    }
    _items[cleanTeacher.id] = cleanTeacher;
    _emitSnapshot();
  }

  @override
  Future<void> update(Teacher teacher) async {
    final cleanTeacher = teacher.copyWith(
      id: teacher.id,
      name: teacher.name,
      isActive: teacher.isActive,
    );
    if (!cleanTeacher.isValid) {
      throw const FormatException('Teacher kaydi gecersiz.');
    }
    if (!_items.containsKey(cleanTeacher.id)) {
      throw StateError('Teacher bulunamadi: ${cleanTeacher.id}');
    }
    _items[cleanTeacher.id] = cleanTeacher;
    _emitSnapshot();
  }

  @override
  Future<void> deleteById(String id) async {
    final cleanId = _cleanText(id);
    if (cleanId.isEmpty) {
      throw const FormatException('Teacher id bos olamaz.');
    }
    if (!_items.containsKey(cleanId)) {
      throw StateError('Teacher bulunamadi: $cleanId');
    }
    _items.remove(cleanId);
    _emitSnapshot();
  }

  void dispose() {
    _controller.close();
  }

  List<Teacher> _snapshot() {
    final values = _items.values.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    return List<Teacher>.unmodifiable(values);
  }

  void _emitSnapshot() {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(_snapshot());
  }

  static String _cleanText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

final List<Teacher> _defaultTeachers = <Teacher>[
  Teacher(id: 'T001', name: 'Ali Yilmaz', isActive: true),
  Teacher(id: 'T002', name: 'Ayse Demir', isActive: true),
  Teacher(id: 'T003', name: 'Can Aydin', isActive: false),
  Teacher(id: 'T004', name: 'Fatma Sahin', isActive: true),
  Teacher(id: 'T005', name: 'Burak Celik', isActive: true),
];
