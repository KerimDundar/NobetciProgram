# Roster Logic Agent

Files: lib/services/roster_service.dart, week_service.dart, duplicate_location_service.dart,
       text_normalizer.dart, export_snapshot_service.dart, lib/models/roster_row.dart

## Rotation rule
rotateForward/rotateBackward: per column, skip empty cells, rotate non-empty values cyclically.
Never simplify to naive array shift. Sparse rosters must rotate correctly.

## Day model
rosterDayCount = 5 in roster_row.dart. Single source of truth. No hard-coded 5 or 6 elsewhere.
Week span: startDate to startDate + 4 days. Previous/next week shifts by 7 days.

## Critical fixes (full rules in agents/rules_fixes.md)
- FIX 1: Turkish comparison → TextNormalizer.canonical() only, never String.toUpperCase()
- FIX 3: Cross-year title parse → if endMonth < startMonth, set endYear = startYear + 1
- FIX 4: Duplicate location key → after canonical(), remove unicode whitespace and all dash variants
- FIX 7: Duplicate run detection → consecutive rows sharing same canonical location form a run
- FIX 8: Roster row normalization → always exactly 5 cells; pad/trim/null-to-empty at every boundary
- FIX 10: Day count source → only rosterDayCount from roster_row.dart, no magic numbers
- FIX 13: ExportSnapshot.isValidWeekForExport → title non-empty after displayClean (shared PDF+Excel)

## Tests to run
```
flutter test test/core_logic_test.dart
flutter analyze
```
