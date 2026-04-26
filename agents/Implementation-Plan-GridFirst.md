# Grid-First Implementation Plan

Status: Draft
Scope: Apply KEEP / MODIFY / REMOVE decisions safely to the current Flutter app.
Goal: Keep working system stable while moving to grid-first UX.

## Constraints
- Grid-first structure stays primary.
- Stitch assets are used only where compatible.
- UI work and logic work are separated.
- Every step is independently testable.
- No hidden behavior changes.

## Phase Files
- [Phase1-Safe-Extraction.md](./Phase1-Safe-Extraction.md)
- [Phase2-Teacher-System.md](./Phase2-Teacher-System.md)
- [Phase3-Edit-Improvement.md](./Phase3-Edit-Improvement.md)
- [Phase4-Visual-Upgrade.md](./Phase4-Visual-Upgrade.md)
- [Phase5-Dashboard.md](./Phase5-Dashboard.md)
- [Phase6-Cleanup.md](./Phase6-Cleanup.md)

## Execution Rule
Run one step at a time, validate, then move to next approved step.
