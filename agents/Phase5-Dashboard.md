# PHASE 5 - DASHBOARD

## Step 5.1 - Collapsible Summary Component
What:
- Extract a minimal collapsible dashboard component.
- Include total locations, filled count, empty count, day density.

Files:
- `mobile_app/lib/ui/widgets/weekly_dashboard.dart` (new)
- `mobile_app/lib/ui/screens/roster_home_screen.dart`
- `mobile_app/test/widget_test.dart`

Risk:
- Dashboard may become primary visual focus and push grid down.

Validation:
- Widget tests for default collapsed state and summary values.

## Step 5.2 - Grid-First Guard
What:
- Ensure grid remains primary in first viewport.
- Dashboard must not reduce initial grid visibility below acceptance threshold.

Files:
- `mobile_app/lib/ui/screens/roster_home_screen.dart`
- `mobile_app/test/widget_test.dart`

Risk:
- First viewport can fail 3-4 row visibility requirement.

Validation:
- Viewport ratio and visible-row widget tests.
