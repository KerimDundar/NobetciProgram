# Project Agent Instructions

## Authority

This project is migrating the desktop Python duty-roster application to Flutter.

The agent system is mandatory for all future work:

1. `agents/rules.md` is the source of truth for existing desktop behavior.
2. `agents/rules_fixes.md` is the source of truth for target improvements and bug fixes.
3. `agents/architecture.md` defines the Flutter architecture.
4. `agents/data_model.md` defines canonical models and validation.
5. `agents/migration.md` defines Python-to-Dart mapping rules.
6. `agents/flutter_dev.md` defines Flutter implementation rules.
7. `agents/ui_ux.md` defines mobile UI/UX rules.

When instructions conflict:

1. User request for the current turn.
2. `agents/rules_fixes.md`.
3. `agents/rules.md`.
4. Other files in `agents/`.
5. Existing implementation style.

Do not ignore `rules.md` to simplify behavior.
Do not ignore `rules_fixes.md` to preserve known bugs.

## Global Behavior

- Prefer action over discussion.
- Be concise.
- Do not restate the prompt.
- Do not add motivational filler.
- Ask only when a wrong assumption can damage work.
- Never fabricate validation results.
- Never modify unrelated files.
- Never refactor unrelated code.
- Preserve existing names and behavior unless a fix rule requires a change.
- Do not generate Flutter code unless the user explicitly asks for implementation.

## Coding Requirements

When asked to implement code:

- Always return full working code, not pseudocode.
- Keep changes complete and runnable.
- Do not leave TODO placeholders for required behavior.
- Do not move business logic into UI widgets.
- Do not simplify roster, Excel, PDF, date, merge, or week-generation logic.
- Implement target fixes from `agents/rules_fixes.md`.
- Validate with focused commands and report real results only.

## Architecture Requirements

- Flutter must use clean architecture.
- UI layer must contain rendering and user interaction only.
- ViewModel / State layer owns screen state and user actions.
- Services layer owns business logic and transformations.
- Models layer owns canonical data shapes and validation.
- Business logic must be testable without Flutter widgets.

- Prefer official Flutter plugins over community packages
- Always enforce edge-case handling
- Never assume user input is valid
- Always implement cancellation-safe logic
- Always enforce file extension correctness

## Migration Requirements

- Python behavior must map to Dart one-to-one.
- Every migrated function must cite its source rule from `agents/rules.md`.
- Every intentional behavior change must cite its fix rule from `agents/rules_fixes.md`.
- No logic simplification is allowed.
- No feature invention is allowed unless the user explicitly requests it.
- Never produce minimal implementations for IO operations
- IO code must be production-grade, not demo-level

## Output Format

When work is complete:

Done.

Changed:
- `<file>`: `<short description>`

Validated:
- `<command/method>`
- `<result>`

Notes:
- Use only if necessary.
