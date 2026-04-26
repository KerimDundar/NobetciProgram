# Plan: Token-Efficient Claude Agent Architecture — Nöbet Çizelgesi

## Context
The Flutter duty-roster app's migration from a Python desktop app is substantially complete. The existing `agents/` directory contains 3,952+ lines of instruction files originally written to guide the migration. These files are now loaded as context for every task — including trivial UI changes — causing severe token waste. This plan redesigns the instruction architecture around scoped subagents and a minimal root CLAUDE.md to reduce context from ~4,000 lines to ~37–382 lines depending on task scope.

---

## CLAUDE PROJECT ANALYSIS COMPLETE

### 1. Current Structure Summary

**lib/ layers (29 files):**
- `lib/models/` — teacher.dart, week.dart, roster_row.dart
- `lib/services/` — 18 service files covering: text normalization, roster/week logic, duplicate location, grid projection, cell status, teacher CRUD, export (PDF/Excel/table/snapshot/file/Android SAF)
- `lib/state/` — roster_state.dart, teacher_state.dart
- `lib/ui/screens/` — roster_home_screen.dart, edit_week_screen.dart, teacher_list_screen.dart
- `lib/ui/widgets/` — teacher_selection_panel.dart
- `lib/ui/theme/` — app_theme.dart
- `lib/main.dart`

**test/ (12 files):**
core_logic_test, android_saf_export_test, grid_status_test, edit_conflict_badge_test, widget_test, teacher_state_test, teacher_repository_test, local_teacher_repository_test, teacher_system_test, teacher_list_screen_test, home_teacher_cleanup_integration_test, edit_teacher_picker_integration_test

**State management:** ChangeNotifier (not Riverpod). Services injected via constructors. No Riverpod, no BLoC.

---

### 2. Existing Rules/Agents Inventory

| File | Lines | Status |
|---|---|---|
| `agents/rules.md` | 1,676 | ARCHIVE — Python desktop spec, implementation is now in Dart |
| `agents/rules_fixes.md` | 618 | ARCHIVE header + distill key rules into subagents |
| `agents/architecture.md` | 291 | KEEP as reference only |
| `agents/migration.md` | 241 | KEEP as reference only |
| `agents/data_model.md` | 240 | KEEP as reference only |
| `agents/ui_ux.md` | 260 | KEEP as reference only |
| `agents/flutter_dev.md` | 253 | KEEP as reference only |
| `agents/Rules3.md` | 379 | ACTIVE — 11-step grid refactor, keep as step tracker |
| `.claude/settings.local.json` | 32 | KEEP unchanged |
| **Total active context** | **3,958** | **Problem** |

No `CLAUDE.md` exists at `mobile_app/` root today.

---

### 3. Problems Causing Token Waste

1. No `CLAUDE.md` → Claude reads everything it can find in `agents/`
2. `rules.md` (1,676 lines) describes a Python app that no longer exists; loaded for every task
3. No task scoping — a teacher-picker tweak loads the same context as an export bug fix
4. Files instruct Claude to explain, consider, analyze during work — producing verbose output
5. No test-map → Claude re-derives which tests cover what each time
6. `agents/Rules3.md` step-tracker has no gating mechanism — steps can be skipped

---

### 4. Recommended Claude Agent Architecture

**5 scoped subagent files in `.claude/agents/` (new directory):**

| Agent file | Scope trigger | Max lines |
|---|---|---|
| `roster-logic.md` | rotation, week generation, title parsing, DuplicateLocationService, RosterService, WeekService | 75 |
| `export.md` | PDF, Excel, SAF, file_selector, ExportFileService, ExportTableService | 75 |
| `teacher.md` | Teacher CRUD, TeacherRepository, TeacherState, teacher picker UI | 60 |
| `grid-ui.md` | WeekGridProjection, GridCellStatus, EditWeekScreen, home grid layout | 70 |
| `test-validation.md` | which tests to run for which change, test commands, test-skip prevention | 65 |

**Root `CLAUDE.md` (37 lines):** Project identity + behavioral rules + layer constraints + Turkish text rule + protected files list + subagent pointer table.

**Context budget per task type:**
- Trivial UI tweak: CLAUDE.md only → 37 lines
- Single-service bug: CLAUDE.md + 1 agent → ~112 lines
- Multi-service feature: CLAUDE.md + 2 agents → ~187 lines
- Full system task: CLAUDE.md + all 5 agents → ~382 lines
- Current state: 3,958 lines for every task

---

### 5. Token Reduction Rules

- Trivial UI change (label, color, padding): load CLAUDE.md only
- Teacher CRUD only: load `teacher.md` only, not roster-logic or export
- Export bug: load `export.md` only, skip teacher and grid agents
- Rotation/week logic: load `roster-logic.md` only
- Grid layout: load `grid-ui.md` only
- Test-only update: no agent files, just run tests and report
- `flutter analyze` lint fix: no agent files

**Step result format (enforce in CLAUDE.md):**
```
DONE: <one sentence>
TESTS: flutter test — X passed / Y failed
ANALYZE: clean / N warnings
NEXT: <next step or "nothing">
```
No explanatory paragraphs. No "I noticed...", "Let me consider...", "As you can see...".

---

### 6. Proposed CLAUDE.md Draft

```markdown
# Nöbet Çizelgesi — Flutter App

Flutter duty-roster mobile app. Dart null safety. ChangeNotifier state.
Layers: models/ → services/ → state/ → ui/screens/ + ui/widgets/

## Behavioral rules (enforce always)
- Do not explain while working. Output results only.
- One step at a time. Stop and ask before implementing.
- Run `flutter test` and `flutter analyze` after every change.
- Report only: what changed, test result, any error. Nothing else.
- Never simplify business logic. Never skip tests.

## Layer rules
- UI calls state only. State calls services only. Services call models only.
- Business logic belongs in services/. Never in widgets or state.
- Models are immutable. Use copyWith for changes.

## Turkish text rule
All business comparisons use TextNormalizer.canonical(). Never String.toUpperCase().

## Protected files (do not modify without explicit instruction)
- lib/services/text_normalizer.dart
- lib/services/export_file_service.dart
- lib/services/export_table_service.dart
- lib/services/roster_service.dart
- lib/services/week_service.dart
- lib/models/roster_row.dart

## Subagent files (load only when relevant)
- .claude/agents/roster-logic.md   — rotation, week generation, fix rules 1-10
- .claude/agents/export.md         — PDF, Excel, Android SAF, file_selector
- .claude/agents/teacher.md        — Teacher model, TeacherRepository, TeacherState, picker UI
- .claude/agents/grid-ui.md        — WeekGridProjection, GridCellStatus, EditWeekScreen
- .claude/agents/test-validation.md — test coverage map, test commands
```

---

### 7. Proposed `.claude/agents/` Drafts

#### `roster-logic.md`
```markdown
# Roster Logic Agent

Files: lib/services/roster_service.dart, week_service.dart, duplicate_location_service.dart,
       text_normalizer.dart, export_snapshot_service.dart, lib/models/roster_row.dart

## Rotation rule
rotateForward/rotateBackward: per column, skip empty cells, rotate non-empty values cyclically.
Never simplify to naive array shift. Sparse rosters must rotate correctly.

## Day model
rosterDayCount = 5 in roster_row.dart. Single source. No hard-coded 5 or 6 elsewhere.
Week span: startDate to startDate + 4 days. Previous/next shifts by 7.

## Critical fixes (FIX numbers reference agents/rules_fixes.md)
- FIX 1: Turkish comparison → TextNormalizer.canonical() only, never String.toUpperCase()
- FIX 3: Cross-year title parse → if endMonth < startMonth, set endYear = startYear + 1
- FIX 4: Duplicate location key → after canonical(), remove unicode whitespace and all dash variants
- FIX 7: Duplicate run detection → consecutive rows sharing same canonical location form a run
- FIX 8: Roster row normalization → always exactly 5 cells; pad/trim/null-to-empty at every boundary
- FIX 10: Day count source → only rosterDayCount from roster_row.dart, no magic numbers
- FIX 13: ExportSnapshot.isValidWeekForExport → title non-empty after displayClean (shared PDF+Excel)

## Tests to run
flutter test test/core_logic_test.dart
flutter analyze
```

#### `export.md`
```markdown
# Export Agent

Files: lib/services/export_file_service.dart, pdf_export_service.dart, excel_export_service.dart,
       export_table_service.dart, export_snapshot_service.dart, android_document_saver.dart,
       method_channel_android_document_saver.dart

## File save rules
- MUST use file_selector (getSaveLocation). NEVER file_picker for save.
- User cancels → return ExportResult.cancelled(). No throw, no crash.
- Auto-append .pdf or .xlsx if missing.
- Atomic write: write to XFile.fromData + saveTo. No partial writes.
- Android: Platform.isAndroid → MethodChannelAndroidDocumentSaver via SAF. Not file_selector.

## Merge logic
- ExportTableService.buildWeekTable drives both PDF and Excel merge output.
- Never duplicate merge logic in either exporter.
- FIX 14/15: Multi-week school/principal → _firstNonEmptyField across all weeks, same scope PDF+Excel.
- FIX 6: Nobet_Data sheet in Excel = unmerged round-trip safety. Never remove this sheet.

## Error categories (Turkish user messages)
permission denied, invalid path, write failure — each has a mapped Turkish message.

## Tests to run
flutter test test/android_saf_export_test.dart
flutter test test/core_logic_test.dart
flutter analyze
```

#### `teacher.md`
```markdown
# Teacher Agent

Files: lib/models/teacher.dart, lib/services/teacher_service.dart, teacher_repository.dart,
       local_teacher_repository.dart, lib/state/teacher_state.dart,
       lib/ui/screens/teacher_list_screen.dart, lib/ui/widgets/teacher_selection_panel.dart

## Model
Teacher fields: id (String), name (String), isActive (bool).
isValid = id.isNotEmpty && name.isNotEmpty.

## Repository pattern
TeacherRepository: abstract interface.
InMemoryTeacherRepository: for tests only.
LocalTeacherRepository: production persistence (SharedPreferences).
TeacherState wraps repository, exposes Stream.

## Search
Case-insensitive. Matches id or name. Optional availableOnly filter.

## State separation
TeacherState and RosterState are independent. Neither owns the other.
RosterState.clearAssignmentsForTeacher uses TextNormalizer.canonicalEquals (Turkish-aware).

## Tests to run
flutter test test/teacher_state_test.dart test/teacher_repository_test.dart
flutter test test/local_teacher_repository_test.dart test/teacher_system_test.dart
flutter test test/teacher_list_screen_test.dart test/home_teacher_cleanup_integration_test.dart
flutter test test/edit_teacher_picker_integration_test.dart
flutter analyze
```

#### `grid-ui.md`
```markdown
# Grid UI Agent

Files: lib/services/week_grid_projection_service.dart, grid_cell_status_service.dart,
       lib/ui/screens/roster_home_screen.dart, edit_week_screen.dart, lib/ui/theme/app_theme.dart

## WeekGridProjection
Read-only adapter over Week.rows. Not a second source of truth.
Cell identity: (rowIndex, dayIndex). WeekGridCell fields: rowIndex, dayIndex, location,
teachers (List), isDuplicateLocation, duplicateRunId, duplicateRunSize, duplicateRunGroup.

## GridCellStatus
empty = no teachers. filled. conflict = same duplicateRunId, different canonical teacher sets in day column.

## EditWeekScreen draft
_RosterRowDraft owns one TextEditingController per cell per RosterRow.
Saving calls RosterState.saveWeekDraft() → RosterService.prepareRowsForSave().

## Grid layout rules
Day selection is primary navigation. Location rows are data rows, not navigation.
Minimum 48px touch targets. Color alone must not signal state.

## Step tracker
Before proposing grid changes, check agents/Rules3.md for the current active step.
Never skip steps. One step per user approval.

## Tests to run
flutter test test/grid_status_test.dart test/edit_conflict_badge_test.dart test/widget_test.dart
flutter analyze
```

#### `test-validation.md`
```markdown
# Test Validation Agent

## Commands
flutter test          — run all tests
flutter analyze       — always run; fix all errors before submitting

## Test-to-area map
| Test file | Covers |
|---|---|
| core_logic_test.dart | TextNormalizer, WeekService, RosterService, DuplicateLocationService, ExportSnapshotService, ExportTableService, ExcelExportService (bytes), PdfExportService, ExportFileService, WeekGridProjection |
| android_saf_export_test.dart | MethodChannelAndroidDocumentSaver, SAF flows |
| grid_status_test.dart | GridCellStatusService: empty/filled/conflict |
| edit_conflict_badge_test.dart | EditWeekScreen conflict badge render |
| widget_test.dart | RosterHomeScreen smoke render |
| teacher_state_test.dart | TeacherState CRUD, error mapping |
| teacher_repository_test.dart | InMemoryTeacherRepository |
| local_teacher_repository_test.dart | LocalTeacherRepository persistence |
| teacher_system_test.dart | Full teacher create/search/delete flow |
| teacher_list_screen_test.dart | TeacherListScreen render + interaction |
| home_teacher_cleanup_integration_test.dart | clearAssignmentsForTeacher |
| edit_teacher_picker_integration_test.dart | Teacher picker in EditWeekScreen |

## Run scope per change type
- TextNormalizer → core_logic_test.dart (all groups)
- Rotation/row normalization → core_logic_test.dart RosterService group
- Export (PDF/Excel bytes) → core_logic_test.dart export groups + android_saf_export_test.dart
- Grid UI → grid_status_test, edit_conflict_badge_test, widget_test
- Teacher system → all teacher_* tests

## Rules
- Test-skipping is FORBIDDEN. Never add skip:, markTestSkipped, or // ignore without a replacement test.
- New service behavior requires a unit test in core_logic_test.dart before implementation is complete.
- flutter analyze must be clean before any PR/commit.
```

---

### 8. Risk Analysis

**Highest risk — `export.md` misuse:**
- `_atomicXFileWriter` simplified → partial writes possible
- Android SAF method channel name/args changed → silent failure on device
- `ExportTableService` bypassed in one exporter → PDF/Excel output diverges

**High risk — `roster-logic.md` misuse:**
- Rotation "simplified" to array shift → fails sparse rosters (passes simple tests)
- Cross-year FIX 3 removed → corrupts all imported workbooks
- `rosterDayCount` hard-coded → breaks on day-model change

**Medium risk — `grid-ui.md` misuse:**
- Rules3.md steps skipped → app loses editing path mid-refactor

**Protected files (never modify without explicit instruction):**
`text_normalizer.dart`, `export_file_service.dart`, `export_table_service.dart`,
`roster_service.dart`, `week_service.dart`, `lib/models/roster_row.dart`

**Test-skip prevention:**
Two layers: CLAUDE.md global rule + test-validation.md explicit rule. Mechanical: add `grep -r "skip:" test/ && exit 1` to CI to catch quiet additions.

---

### 9. Migration Step Plan

**STEP A — Inventory** ✓ (this document)
Confirm: no CLAUDE.md exists. agents/ directory has 3,958 active lines. .claude/agents/ does not exist.

**STEP B — Archive headers**
Add `# ARCHIVED — DO NOT LOAD AS CONTEXT` to top of:
- `mobile_app/agents/rules.md`
- `mobile_app/agents/rules_fixes.md`
(Files remain on disk for traceability.)

**STEP C — Create CLAUDE.md**
File: `mobile_app/CLAUDE.md`
Content: the 37-line draft in Section 6.
Verify: Claude Code picks it up as the root instruction file.

**STEP D — Create .claude/agents/ subagent files**
Create directory `mobile_app/.claude/agents/` (it doesn't exist yet).
Files to create in order:
1. `test-validation.md` (no dependencies)
2. `roster-logic.md`
3. `export.md`
4. `teacher.md`
5. `grid-ui.md`

**STEP E — Validation**
Run a test task with only CLAUDE.md active (e.g., rename a widget label).
Verify: Claude does not load agents/rules.md. Output is ≤5 lines. Tests pass.
Run a second test task scoped to export (e.g., "trace what happens when user cancels save").
Verify: Claude loads export.md but not roster-logic.md. Output matches step format.

**STEP F — First real task**
Use the new architecture for the next actual feature or bug fix.
If token consumption is still high, inspect which files Claude auto-loaded and tighten scope rules in the relevant subagent.

---

## Critical Files for Implementation

| File | Action |
|---|---|
| `mobile_app/CLAUDE.md` | CREATE — 37 lines |
| `mobile_app/.claude/agents/test-validation.md` | CREATE |
| `mobile_app/.claude/agents/roster-logic.md` | CREATE |
| `mobile_app/.claude/agents/export.md` | CREATE |
| `mobile_app/.claude/agents/teacher.md` | CREATE |
| `mobile_app/.claude/agents/grid-ui.md` | CREATE |
| `mobile_app/agents/rules.md` | ADD archive header |
| `mobile_app/agents/rules_fixes.md` | ADD archive header |

## Verification

After STEP D:
```
flutter test        → all 12 test files pass (no code changed, just config)
flutter analyze     → clean
```
After STEP E (validation task):
- Claude context lines loaded < 200 for a trivial task
- Step output matches: DONE / TESTS / ANALYZE / NEXT format
