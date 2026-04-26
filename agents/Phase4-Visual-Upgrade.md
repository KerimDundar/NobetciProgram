# PHASE 4 - VISUAL UPGRADE

## Step 4.1 - Cell Visual Status Model
What:
- Add status projection for empty, filled, and conflict states.
- Keep logic in service layer, not in widgets.

Files:
- `mobile_app/lib/services/grid_cell_status_service.dart` (new)
- `mobile_app/test/core_logic_test.dart`

Risk:
- Conflict status can be computed incorrectly for duplicate runs.

Validation:
- Unit tests for empty/filled/conflict scenarios.

## Step 4.2 - Badge and Color Application
What:
- Apply status color system and badge language to home/edit grid.
- Add duplicate visual markers.

Files:
- `mobile_app/lib/ui/screens/roster_home_screen.dart`
- `mobile_app/lib/ui/screens/edit_week_screen.dart`
- `mobile_app/lib/ui/theme/app_theme.dart`
- `mobile_app/test/widget_test.dart`

Risk:
- Reduced accessibility under large text or low contrast.

Validation:
- Widget tests for label visibility and overlap.

## Step 4.3 - Duplicate Run Group Visuals
What:
- Apply run-based grouping visuals:
- 2 -> merged group
- 3 -> 2+1
- 4 -> 2+2

Files:
- `mobile_app/lib/services/week_grid_projection_service.dart`
- `mobile_app/lib/ui/screens/roster_home_screen.dart`
- `mobile_app/test/core_logic_test.dart`
- `mobile_app/test/widget_test.dart`

Risk:
- Visual grouping may hide logical row identity.

Validation:
- Projection and widget tests for row identity and grouping correctness.
