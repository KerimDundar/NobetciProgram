# Flutter Architecture

## Purpose

Define the required clean architecture for the Flutter rewrite.

`agents/rules.md` defines existing behavior.
`agents/rules_fixes.md` defines target improvements.

The architecture must preserve all business rules while preventing UI widgets from owning business logic.

## Layers

The Flutter app must be organized into these layers:

```text
UI
ViewModel / State
Services
Models
```

Dependencies flow downward only:

```text
UI -> ViewModel / State -> Services -> Models
```

Models may not depend on services.
Services may not depend on Flutter widgets.
ViewModels may not contain business transformations that belong in services.
UI may not contain business logic.

## UI Layer

Responsibilities:

- Render screens.
- Display roster weeks.
- Display validation messages.
- Collect user input.
- Forward user actions to ViewModels.
- Reflect loading, error, empty, and success states.

Forbidden in UI:

- roster rotation
- duplicate-location comparison
- date range generation
- title parsing/building
- Excel/PDF merge decisions
- canonical text normalization
- roster row normalization
- export snapshot selection
- validation rules beyond simple field presence needed for immediate UX

UI widgets must call ViewModel methods such as:

- `loadWorkbook`
- `saveWeek`
- `generateNextWeek`
- `generatePreviousWeek`
- `generateMonthPreview`
- `generateRangePreview`
- `exportPdf`
- `exportExcel`
- `updateRosterCell`

Widgets must not directly mutate exported domain models unless routed through ViewModel state methods.

## ViewModel / State Layer

Responsibilities:

- Own screen state.
- Coordinate services.
- Convert service errors into UI state.
- Decide which screen state is visible.
- Keep preview and export snapshots synchronized according to `rules_fixes.md`.
- Persist app state through repository/storage services.

ViewModels may:

- call services
- hold immutable snapshots
- expose derived display state
- debounce UI actions when needed

ViewModels may not:

- implement rotation logic
- implement Excel/PDF merge logic
- parse titles directly
- perform Turkish canonicalization directly
- contain hard-coded weekday counts

Required ViewModels:

- `RosterViewModel`
  - current week state
  - current locations and roster
  - generated preview weeks
  - export snapshot
  - load/edit/generate/export commands

- `EditWeekViewModel`
  - editable draft week
  - row/cell updates
  - validation before commit

- `ExportViewModel` or export state inside `RosterViewModel`
  - export target
  - export progress
  - last output metadata

## Services Layer

Services own all business logic and transformations.

Required services:

- `TextNormalizer`
  - implements Turkish-aware canonical text from `rules_fixes.md`
  - display cleanup
  - duplicate-location key generation

- `RosterService`
  - row normalization
  - forward rotation
  - backward rotation
  - roster validation

- `WeekService`
  - title building
  - title parsing
  - next/previous week calculation
  - month preview generation
  - range preview generation

- `DuplicateLocationService`
  - detects duplicate runs
  - applies target duplicate-location policy
  - provides merge plans for PDF and Excel renderers

- `ExportSnapshotService`
  - single source for preview/export week list
  - implements fix rules for preview/export synchronization
  - filters valid export weeks consistently

- `ExcelService`
  - Excel import
  - Excel export
  - merge-aware reading/writing
  - maps to Python `roster_io.py`

- `PdfService`
  - PDF export
  - shared merge plans
  - shared metadata policy
  - maps to Python `pdf_export.py`

- `AppStateRepository`
  - persisted app state
  - last opened workbook path
  - last generated weeks
  - last output metadata

Services must be independently unit-testable.

## Models Layer

Models define immutable domain objects and canonical data shapes.

Required model concepts:

- `Week`
- `Roster`
- `RosterRow`
- `DutyLocation`
- `Day`
- `DateRange`
- `ExportSnapshot`
- `MergePlan`
- `ValidationResult`

Models must not import Flutter UI libraries.

Models must enforce the canonical five-day structure described in `agents/data_model.md`.

## Data Flow

Import flow:

```text
Excel file
-> ExcelService
-> TextNormalizer / WeekService / RosterService
-> Week model
-> RosterViewModel
-> UI
```

Edit flow:

```text
UI input
-> EditWeekViewModel
-> RosterService validation/normalization
-> WeekService title/date rules
-> RosterViewModel state
-> ExportSnapshotService
```

Generation flow:

```text
UI action
-> RosterViewModel
-> WeekService
-> RosterService rotation
-> ExportSnapshotService
-> UI preview
```

Export flow:

```text
UI action
-> RosterViewModel
-> ExportSnapshotService
-> ExcelService or PdfService
-> file
```

## Business Logic Placement

Business logic must live in services.

Examples:

- `rotateRoster` belongs in `RosterService`.
- `rotateRosterBack` belongs in `RosterService`.
- `parseTitle` belongs in `WeekService`.
- `buildTitle` belongs in `WeekService`.
- duplicate-location detection belongs in `DuplicateLocationService`.
- valid-week filtering belongs in `ExportSnapshotService`.
- Excel merge behavior belongs in `ExcelService`, using `DuplicateLocationService`.
- PDF merge behavior belongs in `PdfService`, using `DuplicateLocationService`.

## Error Handling

Services return typed results or throw domain-specific exceptions.

ViewModels convert errors into user-facing messages.

UI does not inspect low-level exceptions.

Required error categories:

- invalid date input
- invalid date range
- invalid title
- missing weekday headers
- invalid roster row shape
- export failure
- import failure
- permission/file access failure
- inconsistent duplicate-location run

## Testing Architecture

Minimum test levels:

- Unit tests for models and services.
- ViewModel tests for state transitions.
- Widget tests only for rendering and interaction wiring.

Business behavior must be tested without widget tests.

Critical tests:

- Turkish text normalization
- title parsing
- cross-year date ranges
- forward/back rotation
- duplicate-location run policy
- roster row normalization
- preview/export snapshot equality
- multi-week PDF/Excel consistency
- Excel round-trip merge safety
