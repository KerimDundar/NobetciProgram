import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/teacher.dart';
import '../services/teacher_repository.dart';
import 'teacher_list_state.dart';

class TeacherState extends ChangeNotifier implements TeacherListStateAdapter {
  TeacherState({TeacherRepository? repository})
    : _repository = repository ?? InMemoryTeacherRepository(),
      _ownsRepository = repository == null {
    _subscription = _repository.watch().listen(
      (teachers) {
        _teachers = List<Teacher>.unmodifiable(teachers);
        _isLoading = false;
        _errorMessage = null;
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = _mapError(error);
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
        notifyListeners();
      },
    );
  }

  final TeacherRepository _repository;
  final bool _ownsRepository;
  final Completer<void> _readyCompleter = Completer<void>();
  late final StreamSubscription<List<Teacher>> _subscription;

  List<Teacher> _teachers = const <Teacher>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  List<Teacher> get teachers => _teachers;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  Future<void> get ready => _readyCompleter.future;

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

  Teacher? findById(String id) {
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

  @override
  Future<String?> createTeacher(Teacher teacher) {
    return _runAction(() => _repository.create(teacher));
  }

  @override
  Future<String?> updateTeacher(Teacher teacher) {
    return _runAction(() => _repository.update(teacher));
  }

  @override
  Future<String?> deleteTeacher(String id) {
    return _runAction(() => _repository.deleteById(id));
  }

  Future<String?> _runAction(Future<void> Function() action) async {
    try {
      _errorMessage = null;
      await action();
      return null;
    } catch (error) {
      final mapped = _mapError(error);
      _errorMessage = mapped;
      notifyListeners();
      return mapped;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    if (_ownsRepository && _repository is InMemoryTeacherRepository) {
      final inMemoryRepository = _repository;
      inMemoryRepository.dispose();
    }
    super.dispose();
  }

  static String _cleanText(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _mapError(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Teacher islemi basarisiz.';
  }
}
