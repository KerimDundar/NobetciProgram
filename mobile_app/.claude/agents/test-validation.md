# Test Validation Agent

## Commands
```
flutter test          # run all tests
flutter analyze       # always run; fix all errors before submitting
```

## Test-to-area map
| Test file | Covers |
|---|---|
| core_logic_test.dart | TextNormalizer, WeekService, RosterService, DuplicateLocationService, ExportSnapshotService, ExportTableService, ExcelExportService (bytes), PdfExportService, ExportFileService, WeekGridProjection |
| android_saf_export_test.dart | MethodChannelAndroidDocumentSaver, SAF cancel/success/error flows |
| grid_status_test.dart | GridCellStatusService: empty/filled/conflict logic |
| edit_conflict_badge_test.dart | EditWeekScreen conflict badge rendering |
| widget_test.dart | RosterHomeScreen smoke render |
| teacher_state_test.dart | TeacherState CRUD, error mapping |
| teacher_repository_test.dart | InMemoryTeacherRepository operations |
| local_teacher_repository_test.dart | LocalTeacherRepository persistence |
| teacher_system_test.dart | Full teacher create/search/delete flow |
| teacher_list_screen_test.dart | TeacherListScreen render and interaction |
| home_teacher_cleanup_integration_test.dart | clearAssignmentsForTeacher integration |
| edit_teacher_picker_integration_test.dart | Teacher picker in EditWeekScreen |

## Run scope per change type
- TextNormalizer change → core_logic_test.dart (all groups)
- Rotation or row normalization → core_logic_test.dart RosterService group
- Export change (PDF/Excel bytes) → core_logic_test.dart export groups + android_saf_export_test.dart
- Grid UI change → grid_status_test, edit_conflict_badge_test, widget_test
- Teacher system change → all teacher_* tests
- Any change → always run flutter analyze first

## Rules
- Test-skipping is FORBIDDEN. Never add skip:, markTestSkipped, or // ignore without a replacement test.
- New service behavior requires a unit test in core_logic_test.dart before implementation is complete.
- flutter analyze must be clean before any commit.
