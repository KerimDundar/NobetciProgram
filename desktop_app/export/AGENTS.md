# Export AGENTS.md

## Scope

Excel and PDF import/export adapters.

Primary files:
- `../roster_io.py`
- `../pdf_export.py`

## Responsibilities

- Excel loading
- Excel writing
- PDF generation
- adapter-specific formatting
- font/resource handling

## Strict Rules

- Preserve data contract from UI/core.
- Do not define business rules here.
- Use `roster_logic.py` for shared rules.
- Keep Excel and PDF duplicate-location behavior consistent.
- Preserve Turkish text/font support.
- Validate with targeted export checks when changed.

## Forbidden

- UI dialogs.
- Runtime state ownership.
- Roster generation logic.
- Date/title business rules.
- Manual edits to `build/` or `dist/`.

## File Priority

1. `../roster_io.py`
2. `../pdf_export.py`
3. `../roster_logic.py` only for shared rule extraction
