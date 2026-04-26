# PHASE 2 - TEACHER SYSTEM

## Step 2.1 - Teacher Domain Model
What:
- Add teacher model with canonical fields (id, name, department, availability).
- Add normalization and validation rules.

Files:
- `mobile_app/lib/models/teacher.dart` (new)
- `mobile_app/test/core_logic_test.dart`

Risk:
- Model mismatch with current state shape.

Validation:
- Unit tests for null/empty/invalid values and normalization.

## Step 2.2 - Teacher Service
What:
- Add teacher list provider service with search and filters.
- Keep service independent from UI widgets.

Files:
- `mobile_app/lib/services/teacher_service.dart` (new)
- `mobile_app/test/core_logic_test.dart`

Risk:
- Slow filtering on larger teacher lists.

Validation:
- Unit tests for query, filter combinations, and edge cases.

## Step 2.3 - State Integration
What:
- Add teacher assignment API to state layer.
- Keep export snapshot consistency after assignment changes.

Files:
- `mobile_app/lib/state/roster_state.dart`
- `mobile_app/test/core_logic_test.dart`

Risk:
- Wrong row/day mutation can corrupt roster data.

Validation:
- State transition tests for assign/change/remove flows.
