# UI Extraction Map (Stitch -> Grid-First App)

## KEEP
- Top header hierarchy (title + date + quick actions)
- Search bar pattern (teacher/location lookup)
- Filter chips pattern
- Status badge language (active/standby equivalent)
- Clear CTA button style
- Bottom sheet selection pattern
- Bottom navigation structure (if still used in app shell)

## MODIFY
- Teacher cards -> teacher picker list/cards with weekly duty context
- Location cards -> secondary drill-down only
- Weekly mini strip -> summary support, not main planner
- Assignment edit panel -> cell-targeted weekly grid edit
- List views -> support browsing/filtering only, not primary planning
- Floating action -> map to explicit grid-safe action

## REMOVE
- Timeline interaction model
- Hour/time-slot based roster logic in UI
- Card-first primary planning surface
- Single-assignment-first core flow
