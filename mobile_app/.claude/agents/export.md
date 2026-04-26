# Export Agent

Files: lib/services/export_file_service.dart, pdf_export_service.dart, excel_export_service.dart,
       export_table_service.dart, export_snapshot_service.dart, android_document_saver.dart,
       method_channel_android_document_saver.dart

## File save rules
- MUST use file_selector (getSaveLocation). NEVER file_picker for save dialogs.
- User cancels save dialog → return ExportResult.cancelled(). No throw, no crash.
- Auto-append .pdf or .xlsx if missing from user-provided filename.
- Atomic write: XFile.fromData + saveTo pattern. No direct writeAsBytes to destination.
- Android: Platform.isAndroid → MethodChannelAndroidDocumentSaver via SAF. Not file_selector.

## Merge logic
- ExportTableService.buildWeekTable drives both PDF and Excel merge output. Never duplicate.
- FIX 14/15: Multi-week school/principal → _firstNonEmptyField across all weeks, same scope PDF+Excel.
- FIX 6: Nobet_Data sheet in ExcelExportService = unmerged round-trip safety. Never remove this sheet.

## Error categories (Turkish user messages required)
- permission denied → Turkish permission message
- invalid path → Turkish path message
- write failure → Turkish write failure message

## Tests to run
```
flutter test test/android_saf_export_test.dart
flutter test test/core_logic_test.dart
flutter analyze
```
