import 'package:flutter/foundation.dart';

import '../models/teacher.dart';

abstract class TeacherListStateAdapter implements Listenable {
  bool get isLoading;
  String? get errorMessage;
  List<Teacher> get teachers;
  Future<String?> createTeacher(Teacher teacher);
  Future<String?> updateTeacher(Teacher teacher);
  Future<String?> deleteTeacher(String id);
}
