# Teacher Agent

Files: lib/models/teacher.dart, lib/services/teacher_service.dart, teacher_repository.dart,
       local_teacher_repository.dart, lib/state/teacher_state.dart,
       lib/ui/screens/teacher_list_screen.dart, lib/ui/widgets/teacher_selection_panel.dart

## Model
Teacher fields: id (String), name (String), isActive (bool).
isValid = id.isNotEmpty && name.isNotEmpty.

## Repository pattern
- TeacherRepository: abstract interface
- InMemoryTeacherRepository: for tests only
- LocalTeacherRepository: production persistence via SharedPreferences
- TeacherState wraps the repository, exposes Stream

## Search
Case-insensitive. Matches id or name. Optional availableOnly filter.

## State separation
TeacherState and RosterState are independent. Neither owns the other.
RosterState.clearAssignmentsForTeacher uses TextNormalizer.canonicalEquals (Turkish-aware).

## Tests to run
```
flutter test test/teacher_state_test.dart test/teacher_repository_test.dart
flutter test test/local_teacher_repository_test.dart test/teacher_system_test.dart
flutter test test/teacher_list_screen_test.dart test/home_teacher_cleanup_integration_test.dart
flutter test test/edit_teacher_picker_integration_test.dart
flutter analyze
```
