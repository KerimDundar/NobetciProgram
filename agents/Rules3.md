# Rules3.md - Mobile UI Refactor Plan
## FIX
Grid UI must not be rendered without projection data binding.
If projection exists, minimal binding must be included in the same step.
Do not change business logic
Mapping between grid and original row/day indexes must be explicitly tested in each step.

## Authority

This file defines the incremental plan for refactoring the mobile roster UI from a location-centered card flow to a day-centered weekly grid flow.

Priority order:

1. Current user request.
2. `agents/rules_fixes.md`.
3. `agents/rules.md`.
4. `agents/rules2.md`.
5. This file.
6. Existing implementation style.

## Current System Analysis

UI structure:

- `RosterHomeScreen` shows week metadata, previous/next actions, export actions, then a vertical list of location cards.
- Each location card shows one duty location and five day rows.
- `EditWeekScreen` edits the same model as location cards, with one location field and five teacher fields per card.

Data flow:

- `RosterState.currentWeek` is rendered directly by home UI.
- Edit UI creates local row drafts from `Week.rows`.
- Save converts drafts back to `RosterRow` and calls `RosterState.saveWeekDraft`.
- Export uses `RosterState.exportSnapshot`.

Weak points:

- The primary mental model is duty-location first, not day first.
- Users must scan every location card to understand one day.
- Empty cells, uneven distribution, duplicate locations, and day density are not visible at a glance.
- Long rosters create long vertical pages and increase comparison errors.
- The edit screen repeats five text fields per location, making day-level checking slow.

## Mandatory Workflow

Use a strict incremental workflow.

STEP PLAN:

1. Baseline UI behavior and tests.
2. Read-only weekly grid projection.
3. Home dashboard summary.
4. Read-only day-centered grid on Home.
5. Day and cell selection interactions.
6. Edit screen grid data binding.
7. Grid-based editing controls.
8. Visual refinement and accessibility.
9. Export/preview consistency check.
10. Legacy location-card removal.
11. Final validation.

After presenting or executing one step, stop.

## Approval Rules

- Do exactly one step at a time.
- Do not continue without explicit approval: `devam`, `continue`, or `ok`.
- After each step, output exactly one sentence.
- Do not explain unless the user asks.
- Do not do two steps in one turn.
- Do not mix UI refactor and business logic changes in the same step.

Required step output format:

```text
STEP X COMPLETE: <one short sentence>
```

## Incremental Development Rules

- Each step must leave the app runnable.
- Each step must be independently testable.
- Risky changes must be isolated.
- Existing export, roster, date, merge, and rotation logic must not be simplified.
- Business logic must stay out of widgets.
- UI projection helpers may be added only as read-only adapters unless the step explicitly covers editing.
- Keep the old UI available until the new grid flow is validated.
- No hidden refactors.
- No unrelated file changes.

## UI Transformation Phases

### Step 1 - Baseline UI Behavior and Tests

Goal:

- Capture current Home and Edit behavior before refactor.

Allowed changes:

- Add focused widget tests for current week rendering, edit navigation, empty state, and export actions.

Validation:

- `flutter test`
- `flutter analyze`

Stop after this step.

### Step 2 - Read-Only Weekly Grid Projection

Goal:

- Add a read-only projection that converts `Week.rows` into day-centered grid data.

Rules:

- Do not mutate `Week`, `RosterRow`, or `RosterState`.
- Keep business logic unchanged.
- Projection must preserve row index, day index, location, teacher, empty state, and duplicate-location visibility.

Validation:

- Unit tests for 0, 1, many locations.
- Unit tests for empty teacher cells.
- Unit tests for duplicate locations.

Stop after this step.

### Step 3 - Home Dashboard Summary

Goal:

- Add a compact weekly dashboard above the roster.

Required UI:

- Week title and date range.
- Total locations.
- Filled cell count.
- Empty cell count.
- Day density indicators.

Rules:

- Dashboard is read-only.
- Existing cards stay visible.

Validation:

- Widget test summary values.
- Large text smoke check.

Stop after this step.

### Step 4 - Read-Only Day-Centered Grid on Home

Goal:

- Add a day-centered weekly grid view while keeping existing location cards below it.

Required UI:

- Day tabs or segmented control.
- Selected day list showing all duty locations and assigned teachers.
- Compact weekly heat map showing filled/empty density.

Rules:

- No horizontal-only primary workflow.
- No editing in this step.
- Existing location-card UI remains.

Validation:

- Widget test for switching days.
- Widget test for filled and empty cells.

Stop after this step.

### Step 5 - Day and Cell Selection Interactions

Goal:

- Make grid cells selectable.

Required behavior:

- Tap a day cell to show location, day, teacher, and row position.
- Empty cells must be selectable.
- Duplicate locations must remain distinguishable.

Rules:

- Selection must not mutate data.
- Use bottom sheet or inline detail panel.

Validation:

- Widget test cell tap.
- Widget test duplicate row selection.

Stop after this step.

### Step 6 - Edit Screen Grid Data Binding

Goal:

- Bind edit drafts to a day-centered grid representation.

Rules:

- Keep `_RosterRowDraft` or an equivalent draft model separate from widgets.
- Do not change save validation.
- Do not change roster rotation logic.
- UI and data binding only; no visual polish in this step.

Validation:

- Editing one grid cell updates the correct draft row/day.
- Saving produces the same `RosterRow` shape as before.

Stop after this step.

### Step 7 - Grid-Based Editing Controls

Goal:

- Replace location-card editing with day-centered editing controls.

Required UI:

- Day selector.
- Location rows for selected day.
- Teacher input for selected day.
- Location edit action.
- Add/delete location actions.
- Rotation actions preserved.

Rules:

- Do not remove old edit UI until tests pass.
- No export changes.

Validation:

- Add location.
- Delete location.
- Edit teacher by day.
- Edit location name.
- Save.
- Cancel/discard.

Stop after this step.

### Step 8 - Visual Refinement and Accessibility

Goal:

- Make the grid understandable at first glance.

Required UI:

- Clear selected day state.
- Filled/empty indicators.
- Duplicate-location grouping indicator.
- Error state placement near affected cells.
- 48 logical pixel minimum touch targets.
- No text overlap with large text.

Rules:

- Do not change data behavior.

Validation:

- Widget tests for labels and error visibility.
- Manual mobile viewport check.

Stop after this step.

### Step 9 - Export and Preview Consistency Check

Goal:

- Confirm the new UI still exports the same snapshot.

Rules:

- No export logic changes unless a bug is found.
- If export bug is found, create a separate step plan for export.

Validation:

- Existing export tests.
- Snapshot equality before and after UI edit.

Stop after this step.

### Step 10 - Legacy Location-Card Removal

Goal:

- Remove old Home/Edit location-card UI after grid flow is validated.

Rules:

- Remove only unused UI widgets.
- Keep reusable non-UI models/services.
- Do not remove tests that still describe required behavior.

Validation:

- `flutter test`
- `flutter analyze`

Stop after this step.

### Step 11 - Final Validation

Goal:

- Validate the full UI refactor.

Required checks:

- Home first glance: week, day density, selected day, assignments.
- Edit flow: add, delete, edit, save, cancel.
- Duplicate locations.
- Empty rows.
- Invalid date range.
- Export PDF and Excel snapshot consistency.

Validation:

- `flutter test`
- `flutter analyze`

Stop after this step.

## Grid Transition Rules

- Home moves from location-card primary view to day-centered grid primary view.
- Edit moves from location-card fields to selected-day grid editing.
- Location rows remain the canonical data rows.
- Grid is a presentation and editing projection only.
- Do not store grid data as a second source of truth.

## Data Binding Rules

- `Week.rows[index].teachersByDay[dayIndex]` is the only source for teacher assignment.
- Grid cell identity must include `rowIndex` and `dayIndex`.
- Editing a cell must update exactly one draft teacher field.
- Editing a location must update exactly one draft location field.
- Save must still call existing validation and normalization.

## Interaction Rules

- Day selection must be explicit.
- Cell selection must show day, location, and teacher.
- Empty cells must be editable.
- Duplicate locations must show row identity or grouping.
- Drag and drop is optional and must not be the only editing path.

## Visual Rules

- The first screen must explain the week without scrolling through every location.
- Prefer compact dashboard, day tabs, and grid/heat map.
- Use restrained colors.
- Color must not be the only status indicator.
- Avoid dense desktop spreadsheet UI as the primary mobile interface.

## Legacy UI Removal Rules

- Remove old cards only after grid Home and grid Edit are tested.
- Remove dead widgets in a separate step.
- Do not remove business logic, models, export services, or validation.
- Keep migration behavior traceable to `agents/rules.md` and `agents/rules_fixes.md`.
