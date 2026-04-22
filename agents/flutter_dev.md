# Flutter Development Rules

## Purpose

Define implementation rules for the Flutter rewrite.

Do not generate Flutter code unless the user explicitly asks for implementation.

## Framework Rules

- Use Flutter stable.
- Use Dart null safety.
- Prefer Material components unless a specific design system is requested.
- Keep widgets small and composable.
- Keep domain logic out of widgets.

## State Management

Use one of:

- Provider
- Riverpod

Default recommendation:

- Use Riverpod for new Flutter code unless the existing app already uses Provider.

Rules:

- ViewModels/notifiers own screen state.
- Services are injected into ViewModels.
- UI watches state and calls ViewModel methods.
- UI must not instantiate business services directly.
- Avoid global mutable singletons.

## Package Rules

Do not add unnecessary packages.

Allowed package categories only when required:

- state management: Provider or Riverpod
- file picker / save location
- local persistence
- Excel read/write
- PDF generation
- path utilities
- unit/widget testing

Before adding a package:

- Check whether Flutter/Dart SDK already solves it.
- Prefer well-maintained packages.
- Keep package count low.
- Do not add packages for simple formatting, collection helpers, or trivial utilities.

## Project Structure

Recommended structure:

```text
lib/
  app/
  core/
    constants/
    errors/
    result/
  models/
  services/
    roster/
    week/
    text/
    export/
    excel/
    pdf/
  state/
  ui/
    screens/
    widgets/
test/
```

Business services must live under `lib/services`.
Models must live under `lib/models`.
UI widgets must live under `lib/ui`.

## Performance Rules

- Avoid rebuilding entire screens for single-cell edits.
- Use immutable state with targeted updates.
- Use list item keys for editable roster cards.
- Avoid expensive normalization in widget build methods.
- Cache derived preview/export snapshots in state when appropriate.
- Run export work asynchronously.
- Keep PDF/Excel generation off hot UI paths.
- Avoid storing large binary exports in widget state.

## Testing Rules

Business logic must have unit tests.

Required unit test areas:

- Turkish-aware normalization
- date parsing
- title parsing/building
- cross-year date ranges
- roster normalization
- forward/backward rotation
- duplicate-location key comparison
- duplicate-location run handling
- merge plan creation
- week generation
- export snapshot selection
- multi-week metadata policy

Widget tests should cover:

- screen renders current week
- edit row/cell interaction calls ViewModel
- preview state displays exported weeks
- validation messages appear

Do not rely on widget tests for business correctness.

## Error Handling

Use typed domain failures for service errors.

Examples:

- `InvalidDateInputFailure`
- `InvalidDateRangeFailure`
- `InvalidTitleFailure`
- `MissingWeekdayHeadersFailure`
- `InvalidRosterFailure`
- `ExportFailure`
- `ImportFailure`
- `FilePermissionFailure`

ViewModels convert failures into localized UI messages.

## Code Quality

- Keep functions short but do not split logic in ways that hide rule traceability.
- Prefer explicit names over clever abstractions.
- Avoid dynamic maps for domain data after import boundaries.
- Use immutable models and copy methods.
- Avoid business logic in extension methods unless clearly domain-scoped.
- Do not silently swallow errors except where a rule explicitly requires fallback behavior.

## Generated Output

When the user asks for implementation:

- Provide complete working Flutter/Dart code.
- Include imports.
- Include model/service/state changes needed for compilation.
- Include tests when behavior is nontrivial.
- Do not provide partial snippets unless the user explicitly asks for a snippet.

## Localization

The roster domain is Turkish.

Rules:

- Turkish business comparisons must use the canonical text service.
- Display text and user-entered names must preserve user spelling unless a rule requires uppercase.
- Do not use English weekday labels in user-facing roster output unless requested.

## Files And Persistence

- Keep import/export logic in services.
- Keep file picking in UI/ViewModel coordination code.
- Do not make services depend on widget context.
- Persist app state through a repository abstraction.

## No Feature Creep

Do not add:

- authentication
- cloud sync
- analytics
- new scheduling algorithms
- AI suggestions
- calendar integrations
- unrelated themes

unless the user explicitly requests them.
## FILE EXPORT / SAVE SYSTEM RULES (CRITICAL)

File save/export operations are considered critical production features.

The agent MUST enforce the following:

### Plugin Selection

* MUST use `file_selector` for desktop save dialogs
* MUST NOT use `file_picker` for save operations
* Must use `getSaveLocation`

### Cancellation Safety

* If user cancels save dialog → operation MUST exit safely
* No exception or crash allowed

### File Extension Enforcement

* Output files MUST always have correct extension
* If missing → auto-append extension
* PDF → .pdf
* Excel → .xlsx

### Overwrite Policy

* If file already exists:

  * MUST either confirm overwrite OR safely overwrite intentionally
  * MUST NOT silently corrupt or fail

### Write Safety

* File writing MUST be atomic (no partial writes)
* Prefer XFile.fromData().saveTo()

### Error Handling

Must handle:

* permission denied
* invalid path
* write failure

Must map errors to user-readable messages

### Architecture Constraint

* File logic MUST remain in service layer
* UI must not directly handle file writing

### Edge Case Enforcement

Agent MUST explicitly handle:

* null path
* empty bytes
* invalid filename
* unsupported extension

If any of these are missing → implementation is INVALID

