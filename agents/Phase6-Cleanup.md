# PHASE 6 - CLEANUP

## Step 6.1 - Remove Non-Primary Legacy UI
What:
- Remove obsolete card/list-first primary flows.
- Keep helper cards/lists only as secondary drill-down.

Files:
- `mobile_app/lib/ui/screens/roster_home_screen.dart`
- `mobile_app/lib/ui/screens/edit_week_screen.dart`
- `mobile_app/test/widget_test.dart`

Risk:
- Removing legacy widgets can break existing interaction paths.

Validation:
- Regression widget tests for home/edit main flows.

## Step 6.2 - Final Regression and Rule Check
What:
- Verify behavior and visual rules after cleanup.
- Confirm export/preview consistency and grid-first acceptance criteria.

Files:
- `mobile_app/test/widget_test.dart`
- `mobile_app/test/core_logic_test.dart`
- `agents/Rules3.md` (status update only if needed)

Risk:
- Hidden regressions in preview/export synchronization.

Validation:
- `flutter test`
- `flutter analyze`
- Manual smoke: home grid, edit flow, duplicate handling, export triggers.
