# Grid UI Agent

Files: lib/services/week_grid_projection_service.dart, grid_cell_status_service.dart,
       lib/ui/screens/roster_home_screen.dart, edit_week_screen.dart, lib/ui/theme/app_theme.dart

## WeekGridProjection
Read-only adapter over Week.rows. Not a second source of truth.
Cell identity: (rowIndex, dayIndex).
WeekGridCell fields: rowIndex, dayIndex, location, teachers (List), isDuplicateLocation,
duplicateRunId, duplicateRunSize, duplicateRunGroup.

## GridCellStatus
- empty: no teachers assigned
- filled: teachers assigned
- conflict: same duplicateRunId, different canonical teacher sets in the same day column

## EditWeekScreen draft
_RosterRowDraft owns one TextEditingController per cell per RosterRow.
Saving calls RosterState.saveWeekDraft() → RosterService.prepareRowsForSave().

## Grid layout rules
- Day selection is primary navigation. Location rows are data rows, not navigation.
- Minimum 48px touch targets.
- Color alone must not signal state (accessibility).

## Step tracker
Before proposing grid changes, check agents/Rules3.md for the current active step.
Never skip steps. One step per user approval.

## Tests to run
```
flutter test test/grid_status_test.dart test/edit_conflict_badge_test.dart test/widget_test.dart
flutter analyze
```
