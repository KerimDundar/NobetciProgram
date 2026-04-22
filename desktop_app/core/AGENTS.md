# Core AGENTS.md

## Scope

Core business logic for roster generation.

Primary file:
- `../roster_logic.py`

## Responsibilities

- day names
- title/date parsing
- title/date formatting
- week span and weekly step
- roster rotation
- empty-slot preservation
- duplicate-location eligibility
- generated week/month/range construction
- normalization rules

## Strict Rules

- Keep `roster_logic.py` UI-free.
- Do not import Tkinter, openpyxl, or reportlab.
- Prefer pure functions.
- Inputs and outputs must be plain Python data.
- Preserve current public behavior unless change is approved.
- Add targeted tests for business rule changes.

## Forbidden

- File dialogs.
- UI state mutation.
- Excel/PDF formatting.
- Runtime persistence.
- Build or installer edits.

## File Priority

1. `../roster_logic.py`
2. business-rule tests
3. callers only after core API is stable
