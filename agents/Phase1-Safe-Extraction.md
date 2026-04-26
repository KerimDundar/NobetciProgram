# PHASE 1 - SAFE EXTRACTION

## Step 1.1 - Extraction Map
What:
- Convert KEEP / MODIFY / REMOVE decisions into component-level extraction map.
- Define allowed use and banned use for each extracted UI piece.

Files:
- `agents/Stitch-UI-Assessment.md`
- `agents/Stitch-Final-Prompt.md`
- `agents/Rules3.md`
- `agents/ui_extraction_map.md` (new)

Risk:
- Wrong mapping can reintroduce card-first flow.

Validation:
- Checklist review: grid-first guard, no timeline, no slot-based planning.

## Step 1.2 - UI Token Isolation
What:
- Isolate typography, badge, button, spacing, and color tokens.
- Keep behavior unchanged.

Files:
- `mobile_app/lib/ui/theme/app_theme.dart` (new)
- `mobile_app/lib/main.dart`

Risk:
- Style update can reduce readability or contrast.

Validation:
- `flutter analyze`
- Widget smoke checks for text overflow and visibility.
