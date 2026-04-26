# Nöbet Çizelgesi — Flutter App

Flutter duty-roster mobile app. Dart null safety. ChangeNotifier state.
Layers: models/ → services/ → state/ → ui/screens/ + ui/widgets/

## Behavioral rules (enforce always)
- Do not explain while working. Output results only.
- One step at a time. Stop and ask before implementing.
- Run `flutter test` and `flutter analyze` after every change.
- Report only: what changed, test result, any error. Nothing else.
- Never simplify business logic. Never skip tests.

## Step result format
```
DONE: <one sentence>
TESTS: flutter test — X passed / Y failed
ANALYZE: clean / N warnings
NEXT: <next step or "nothing">
```

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
- .claude/agents/flutter_dev.md    — post-update emulator refresh rule (clean build, reinstall, rapor formatı)
