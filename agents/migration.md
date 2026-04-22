# Migration Rules

## Purpose

Map the Python desktop implementation to Dart/Flutter without simplifying logic.

`agents/rules.md` is the required one-to-one behavior reference.
`agents/rules_fixes.md` is the required target-improvement reference.

No Flutter code should be generated from this file alone.

## Migration Principle

Every Python business function must map to an explicit Dart service/model function.

Do not merge multiple behaviors together unless the architecture file requires shared services and the original behavior remains separately testable.

Do not drop edge cases.
Do not rename concepts so much that source behavior becomes untraceable.

## Python To Dart Mapping

### roster_logic.py

Map to:

```text
TextNormalizer
RosterService
WeekService
DateInputParser
```

Required one-to-one mappings:

```text
normalize_text -> TextNormalizer.canonical
normalize_name_text -> TextNormalizer.displayClean
duplicate_location_key -> TextNormalizer.duplicateLocationKey
is_duplicate_location -> DuplicateLocationService.isDuplicateLocation
compute_uniform_font_size -> ExportLayoutService.computeUniformFontSize if needed by export
parse_title -> WeekService.parseTitle
build_title -> WeekService.buildTitle
build_week -> WeekFactory.fromLegacyParts or WeekService.buildWeek
next_week_dates -> WeekService.nextWeekDates
rotate_roster -> RosterService.rotateForward
build_next_week -> WeekService.buildNextWeek
rotate_roster_back -> RosterService.rotateBackward
parse_date_input -> DateInputParser.parse
```

Target fixes:

- Turkish-aware canonical text must replace Python `upper()`.
- Cross-year title parsing must be fixed.
- Roster rows must normalize to five day cells.
- Day count must come from the centralized day model.

### roster_io.py

Map to:

```text
ExcelService
ExcelImportService
ExcelExportService
ExcelMergeReader
DuplicateLocationService
```

Required one-to-one mappings:

```text
_find_week_title_rows -> ExcelImportService.findWeekTitleRows
_detect_day_columns -> ExcelImportService.detectDayColumns
_extract_colon_value -> ExcelImportService.extractColonValue
_extract_school_name_from_text -> ExcelImportService.extractSchoolNameFromText
_find_global_school_name -> ExcelImportService.findGlobalSchoolName
_parse_school_name_from_title_row -> ExcelImportService.parseSchoolNameForTitleRow
_parse_principal_name_from_signature_row -> ExcelImportService.parsePrincipalNameFromSignatureRow
_read_week_block -> ExcelImportService.readWeekBlock
load_last_week -> ExcelService.loadLastWeek
_find_last_block_end -> ExcelImportService.findLastBlockEnd
_apply_duplicate_location_pair_excel_merge -> ExcelExportService.applyDuplicateLocationPairMerge
_apply_duplicate_location_excel_merge_rules -> ExcelExportService.applyDuplicateLocationMergeRules
_apply_basic_formatting -> ExcelExportService.applyBasicFormatting
_write_school_line -> ExcelExportService.writeSchoolLine
_write_principal_line -> ExcelExportService.writePrincipalLine
append_week_block -> ExcelExportService.appendWeekBlock
write_week_to_excel -> ExcelService.writeWeek
write_weeks_to_excel -> ExcelService.writeWeeks
```

Target fixes:

- Excel import must be merge-aware.
- Excel append-end detection must be merge-aware.
- School-name extraction must not treat arbitrary previous-location rows as school names.
- Multi-week metadata scope must be consistent with PDF.
- Valid-week filtering must be shared with PDF.

### pdf_export.py

Map to:

```text
PdfService
PdfExportService
PdfLayoutService
DuplicateLocationService
ExportSnapshotService
```

Required one-to-one mappings:

```text
_resource_path -> AssetPathService.resourcePath if needed
_register_turkish_font -> PdfFontService.registerFont
_build_wrapped_paragraph -> PdfTextBuilder.wrappedParagraph
_build_school_line -> PdfExportService.buildSchoolLine
_build_principal_line -> PdfExportService.buildPrincipalLine
_apply_duplicate_location_pdf_merge_rules -> DuplicateLocationService.buildMergePlan
_week_row_count -> PdfLayoutService.weekRowCount
_first_non_empty_field -> ExportMetadataService.firstNonEmptyField
_compute_multiweek_page_layout -> PdfLayoutService.computeMultiweekPageLayout
_build_week_elements -> PdfExportService.buildWeekElements
export_week_pdf -> PdfService.exportWeek
export_weeks_pdf -> PdfService.exportWeeks
```

Target fixes:

- PDF must consume the same MergePlan policy as Excel.
- PDF valid-week filtering must match Excel.
- PDF row counting must match rendered rows.
- Principal/school metadata policy must match Excel.

### ui.py

Map to:

```text
Flutter UI widgets
RosterViewModel
EditWeekViewModel
ExportSnapshotService
WeekService
RosterService
AppStateRepository
```

Required one-to-one behavior mapping:

```text
_copy_roster_rows -> RosterService.normalizeRows
_copy_week -> Week.copy / WeekFactory.copy
_copy_weeks -> Week.copyList
EditWindow._save -> EditWeekViewModel.commitDraft
EditWindow._shift_day_column -> RosterService.rotateSingleDayColumn
App._set_current_week -> RosterViewModel.setCurrentWeek
App._build_month_in_range -> WeekService.buildMonthInRange
App.load_excel -> RosterViewModel.loadExcel
App.edit_week -> EditWeekViewModel open/edit/commit flow
App._build_weeks_for_output_range -> WeekService.buildWeeksForOutputRange
App._apply_preview_weeks -> RosterViewModel.applyPreviewWeeks
App._export_weeks_snapshot -> ExportSnapshotService.currentSnapshot
App.generate_range_outputs -> RosterViewModel.generateRangePreview
App.apply_input_dates -> RosterViewModel.applyInputDates
App.generate_next_in_range -> RosterViewModel.generateNextInRange
App.generate_month_in_range -> RosterViewModel.generateMonthInRange
App.generate_previous -> RosterViewModel.generatePrevious
App.generate_next -> RosterViewModel.generateNext
App.generate_month -> RosterViewModel.generateMonth
App.export_pdf -> RosterViewModel.exportPdf
App.save_excel_as -> RosterViewModel.exportExcel
```

Target fixes:

- Preview edits must update export data or preview editing must be disabled.
- Auto-generated preview must match export snapshot.
- Month/range week span generation must be consistent.

## Migration Checklist

For every migrated behavior:

1. Locate source rule in `agents/rules.md`.
2. Check whether a target fix exists in `agents/rules_fixes.md`.
3. Implement the behavior in the correct service/model layer.
4. Write unit tests for normal behavior and documented edge cases.
5. Confirm UI calls the ViewModel only.
6. Confirm export and preview use the same snapshot source.

## No Simplification Rule

These must not be simplified:

- forward roster rotation
- backward roster rotation
- duplicate-location merge behavior
- duplicate-location conflict detection
- title parsing
- title building
- date input parsing
- week generation
- Excel import
- Excel export
- PDF export
- export snapshot selection

If behavior is known-buggy, implement the target fix from `rules_fixes.md`, not a simplified approximation.

## Validation During Migration

Required parity tests:

- Python documented examples from `rules.md`
- fix examples from `rules_fixes.md`
- Turkish casing examples
- short and long roster row normalization
- adjacent duplicate locations
- duplicate runs longer than two
- conflicting teacher names
- cross-year title parsing
- range shorter than five days
- four-week month generation
- blank placeholder filtering
- preview edit then export
- Excel/PDF week count equality

## Traceability Requirement

Each service file in the Flutter implementation should include a short header comment or test reference listing:

- source Python file/function
- source rule name
- target fix rule if behavior differs

Do not include long copied text from rule files in code comments.
