import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/teacher.dart';
import 'teacher_repository.dart';
import 'turkish_text_comparator.dart';

class LocalTeacherRepository implements TeacherRepository {
  LocalTeacherRepository({
    Future<SharedPreferences>? preferencesFuture,
    List<Teacher>? seedTeachers,
    this.storageKey = _defaultStorageKey,
  }) : _preferencesFuture =
           preferencesFuture ?? SharedPreferences.getInstance(),
       _seedTeachers = seedTeachers ?? _defaultSeedTeachers;

  static const String _defaultStorageKey = 'teacher_repository_v1';

  final Future<SharedPreferences> _preferencesFuture;
  final List<Teacher> _seedTeachers;
  final String storageKey;
  final Map<String, Teacher> _items = <String, Teacher>{};
  final StreamController<List<Teacher>> _controller =
      StreamController<List<Teacher>>.broadcast();

  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  @override
  Future<List<Teacher>> list() async {
    await _ensureInitialized();
    return _snapshot();
  }

  @override
  Stream<List<Teacher>> watch() {
    return Stream<List<Teacher>>.multi((multi) {
      StreamSubscription<List<Teacher>>? subscription;
      var cancelled = false;

      multi.onCancel = () async {
        cancelled = true;
        await subscription?.cancel();
      };

      _ensureInitialized()
          .then((_) {
            if (cancelled) {
              return;
            }
            multi.add(_snapshot());
            subscription = _controller.stream.listen(
              multi.add,
              onError: multi.addError,
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (cancelled) {
              return;
            }
            multi.addError(error, stackTrace);
          });
    }, isBroadcast: true);
  }

  @override
  Future<Teacher?> getById(String id) async {
    await _ensureInitialized();
    final cleanId = _cleanText(id);
    if (cleanId.isEmpty) {
      return null;
    }
    return _items[cleanId];
  }

  @override
  Future<void> create(Teacher teacher) async {
    await _ensureInitialized();
    final cleanTeacher = _normalizeTeacher(teacher);
    if (!cleanTeacher.isValid) {
      throw const FormatException('Teacher kaydi gecersiz.');
    }
    if (_items.containsKey(cleanTeacher.id)) {
      throw StateError('Teacher zaten mevcut: ${cleanTeacher.id}');
    }
    _items[cleanTeacher.id] = cleanTeacher;
    await _saveSnapshot();
    _emitSnapshot();
  }

  @override
  Future<void> update(Teacher teacher) async {
    await _ensureInitialized();
    final cleanTeacher = _normalizeTeacher(teacher);
    if (!cleanTeacher.isValid) {
      throw const FormatException('Teacher kaydi gecersiz.');
    }
    if (!_items.containsKey(cleanTeacher.id)) {
      throw StateError('Teacher bulunamadi: ${cleanTeacher.id}');
    }
    _items[cleanTeacher.id] = cleanTeacher;
    await _saveSnapshot();
    _emitSnapshot();
  }

  @override
  Future<void> deleteById(String id) async {
    await _ensureInitialized();
    final cleanId = _cleanText(id);
    if (cleanId.isEmpty) {
      throw const FormatException('Teacher id bos olamaz.');
    }
    if (!_items.containsKey(cleanId)) {
      throw StateError('Teacher bulunamadi: $cleanId');
    }
    _items.remove(cleanId);
    await _saveSnapshot();
    _emitSnapshot();
  }

  void dispose() {
    _controller.close();
  }

  Future<void> _ensureInitialized() {
    if (_isInitialized) {
      return Future<void>.value();
    }
    final running = _initializationFuture;
    if (running != null) {
      return running;
    }

    final task = _loadFromStorage();
    _initializationFuture = task;
    return task;
  }

  Future<void> _loadFromStorage() async {
    final preferences = await _preferencesFuture;
    final rawValue = preferences.getString(storageKey);

    if (rawValue == null || rawValue.trim().isEmpty) {
      _seedInitialItems();
      await _writeToStorage(preferences);
      _isInitialized = true;
      return;
    }

    final parsed = jsonDecode(rawValue);
    if (parsed is! List) {
      throw const FormatException('Teacher deposu bozuk.');
    }

    _items.clear();
    var needsRewrite = false;
    for (final entry in parsed) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      if (_isLegacyTeacherJson(entry)) {
        needsRewrite = true;
      }
      final teacher = _teacherFromJson(entry);
      if (!teacher.isValid) {
        continue;
      }
      _items[teacher.id] = teacher;
    }
    if (needsRewrite) {
      await _writeToStorage(preferences);
    }
    _isInitialized = true;
  }

  void _seedInitialItems() {
    _items.clear();
    for (final teacher in _seedTeachers) {
      final normalized = _normalizeTeacher(teacher);
      if (!normalized.isValid) {
        continue;
      }
      _items[normalized.id] = normalized;
    }
  }

  Future<void> _saveSnapshot() async {
    final preferences = await _preferencesFuture;
    await _writeToStorage(preferences);
  }

  Future<void> _writeToStorage(SharedPreferences preferences) async {
    final values = _snapshot()
        .map<Map<String, dynamic>>(_teacherToJson)
        .toList(growable: false);
    final payload = jsonEncode(values);
    final saved = await preferences.setString(storageKey, payload);
    if (!saved) {
      throw StateError('Teacher kaydi saklanamadi.');
    }
  }

  Teacher _normalizeTeacher(Teacher teacher) {
    return teacher.copyWith(
      id: teacher.id,
      name: teacher.name,
      isActive: teacher.isActive,
    );
  }

  List<Teacher> _snapshot() {
    final values = _items.values.toList(growable: false)
      ..sort((left, right) => TurkishTextComparator.compare(left.name, right.name));
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

  static bool _isLegacyTeacherJson(Map<String, dynamic> json) {
    return json.containsKey('fullName') ||
        json.containsKey('isAvailable') ||
        json.containsKey('department') ||
        json.containsKey('weeklyAssignmentCount') ||
        json.containsKey('email') ||
        json.containsKey('phone') ||
        json.containsKey('notes') ||
        json.containsKey('createdAt') ||
        json.containsKey('updatedAt');
  }
}

Map<String, dynamic> _teacherToJson(Teacher teacher) {
  return <String, dynamic>{
    'id': teacher.id,
    'name': teacher.name,
    'isActive': teacher.isActive,
  };
}

Teacher _teacherFromJson(Map<String, dynamic> json) {
  final rawName = json['name'] ?? json['fullName'];
  final rawIsActive = json['isActive'] ?? json['isAvailable'];
  return Teacher(
    id: json['id'] as String?,
    name: rawName as String?,
    isActive: rawIsActive as bool?,
  );
}

final List<Teacher> _defaultSeedTeachers = <Teacher>[
  Teacher(id: 'T001', name: 'Ali Yilmaz', isActive: true),
  Teacher(id: 'T002', name: 'Ayse Demir', isActive: true),
  Teacher(id: 'T003', name: 'Can Aydin', isActive: false),
  Teacher(id: 'T004', name: 'Fatma Sahin', isActive: true),
  Teacher(id: 'T005', name: 'Burak Celik', isActive: true),
];
