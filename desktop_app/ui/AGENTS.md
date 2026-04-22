# UI AGENTS.md

## Scope

Tkinter UI and application controller behavior.

Primary file:
- `../ui.py`

## Responsibilities

- windows and widgets
- user actions
- dialog validation
- state orchestration
- preview display
- calling core/export adapters

## Strict Rules

- Treat `ui.py` as fragile.
- Edit the smallest affected method.
- Do not add business rules here.
- Use `roster_logic.py` for roster/date generation rules.
- Keep preview data isolated from current/generated state.
- Export only copied snapshots.

## Forbidden

- Broad UI rewrites.
- Moving core logic into UI.
- Mutating current state from preview edits without explicit confirmation.
- Editing generated artifacts.
- Changing visual layout unless requested.

## File Priority

1. affected method in `../ui.py`
2. state copy helpers in `../ui.py`
3. core helper calls in `../roster_logic.py`
