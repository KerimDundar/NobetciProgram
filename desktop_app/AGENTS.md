# Project AGENTS.md

## Project

Python Tkinter desktop app for teacher duty roster generation.

## Architecture

- `main.py`: entry point only.
- `ui.py`: mixed UI/controller layer; fragile, edit locally.
- `roster_logic.py`: core business rules; source of truth.
- `roster_io.py`: Excel read/write adapter.
- `pdf_export.py`: PDF export adapter.
- `app_state.json`: runtime state snapshot.
- `build/`, `dist/`: generated artifacts; do not edit.

## Core Rule

All business rules must live in or defer to `roster_logic.py`.

Business rules include:
- day names
- title/date parsing and formatting
- week span and weekly step
- roster rotation
- empty-slot preservation
- duplicate-location eligibility
- generated week/month/range construction

## State Model

- Current roster is authoritative for active editing.
- Generated month/range data is an export candidate only.
- Preview data is UI buffer only.
- Persisted state is startup restore only.
- Preview must not mutate current or generated state.
- Generated data must not replace current state without explicit confirmation.
- Export must read from an isolated snapshot.

## Workflow

Operate in controlled steps when requested:

1. Analyze.
2. Plan.
3. Explain intended change.
4. Wait for approval.
5. Edit.
6. Validate.
7. Report.

After each approved step:
- stop
- report changed files
- report validation
- provide commit-ready message if stable

## File Priorities

For business behavior:
1. `roster_logic.py`
2. tests
3. callers in `ui.py`, `roster_io.py`, `pdf_export.py`

For UI behavior:
1. smallest affected method in `ui.py`
2. state copy/isolation helpers
3. no broad UI rewrite

For export behavior:
1. preserve data contract
2. preserve Excel/PDF formatting
3. keep adapter logic out of core unless it is business logic

## Forbidden

- Editing `build/` or `dist/` manually.
- Moving business logic into `ui.py`.
- Letting preview references mutate current state.
- Rewriting full files unnecessarily.
- Changing export format without approval.
- Running expensive full builds unless needed.
