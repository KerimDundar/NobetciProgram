# PHASE 3 - EDIT IMPROVEMENT

## Step 3.1 - Cell Trigger to Teacher Picker
What:
- Open teacher picker from selected grid cell in edit screen.
- Preserve selected cell context (rowIndex, dayIndex).

Files:
- `mobile_app/lib/ui/screens/edit_week_screen.dart`
- `mobile_app/test/widget_test.dart`

Risk:
- Picker opens with wrong target cell context.

Validation:
- Widget tests for tap -> picker open with correct cell key.

## Step 3.2 - Assignment Commit Path
What:
- Commit selected teacher to exact cell.
- Support cancel-safe flow (no commit on cancel).

Files:
- `mobile_app/lib/ui/screens/edit_week_screen.dart`
- `mobile_app/lib/state/roster_state.dart`
- `mobile_app/test/widget_test.dart`
- `mobile_app/test/core_logic_test.dart`

Risk:
- Assignment may write to wrong day column.

Validation:
- Widget and state tests for row/day exact write behavior.

## Step 3.3 - Filled vs Empty Cell Actions
What:
- Empty cell: assign flow.
- Filled cell: change/remove flow.

Files:
- `mobile_app/lib/ui/screens/edit_week_screen.dart`
- `mobile_app/test/widget_test.dart`

Risk:
- UX ambiguity between edit and remove actions.

Validation:
- Widget interaction tests for both cell states.
