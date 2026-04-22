# Mobile UI/UX Rules

## Purpose

Convert the desktop table workflow into a mobile-first Flutter experience.

The app must preserve roster behavior from `agents/rules.md` and apply target improvements from `agents/rules_fixes.md`.

Do not copy the desktop table UI directly.

## Core Principle

Mobile UI must be card/list based.

No desktop-style wide spreadsheet table as the primary mobile interface.

Use progressive detail:

- week summary
- location cards
- day cells inside cards
- edit sheet or detail screen for focused editing

## Main Screens

Recommended screens:

```text
Home / Current Week
Edit Week
Generated Preview
Export
Settings / Import
```

Alternative navigation is allowed only if the same workflows remain clear.

## Current Week Screen

Must show:

- school name
- week date range
- title
- locations
- teacher assignments by day
- actions for previous week
- actions for next week
- actions for range/month preview
- export actions

Mobile layout:

- Use a vertical list of location cards.
- Each location card shows duty location as the card title.
- Inside each card, show five weekday rows or chips.
- Each weekday row shows day label and assigned teacher.

Do not require horizontal scrolling for normal use.

## Edit Week Screen

Editable structure:

- Date range picker.
- School field.
- Principal field.
- Reorderable/editable list of location cards.
- Each location card contains five editable teacher fields.

Actions:

- add location row
- delete location row
- edit location name
- edit teacher per day
- rotate one day column forward/backward
- save draft
- cancel

Validation:

- A teacher-filled card cannot have an empty location.
- Roster rows normalize to exactly five day cells.
- Invalid date range blocks save.

## Generated Preview Screen

Preview must display exactly the export snapshot.

Rules:

- If preview is editable, edits must update export data.
- If edits do not update export data, preview must be read-only.
- Do not display auto-generated weeks that export will ignore.

Layout:

- Use week cards.
- Each week card shows date range and title.
- Inside each week, use collapsible location cards or compact rows.
- Show export count clearly.

## Export Screen / Actions

Export UI must show:

- number of weeks to export
- first start date
- last end date
- target format: PDF or Excel
- selected output path when available
- validation errors before export

PDF and Excel should export the same week snapshot.

## Import Workflow

Import flow:

- Select Excel file.
- Show detected last week summary.
- Show school/principal/date range.
- Show roster preview.
- Confirm import.

If import detects structural risks:

- missing title
- missing weekday headers
- invalid dates
- unsafe merged cells

show a clear error and do not guess silently.

## Mobile Card Design

Location card content:

```text
Location name
Pazartesi: Teacher
Salı: Teacher
Çarşamba: Teacher
Perşembe: Teacher
Cuma: Teacher
```

Use compact input controls for teacher fields.

Avoid:

- dense desktop grid
- tiny spreadsheet cells
- horizontal-only workflows
- hidden export data different from preview

## Editing Interactions

Supported mobile editing patterns:

- tap card to edit
- inline text fields for teacher names
- bottom sheet for one location row
- drag handle for reordering locations if needed
- menu for rotate day forward/backward

Do not require drag-and-drop between tiny cells as the only editing method.

## Duplicate Locations In UI

Duplicate-location behavior must be visible and predictable.

If duplicate runs are allowed:

- group same-location consecutive cards visually
- show conflicts clearly
- do not hide logical rows before export

If only duplicate pairs are allowed:

- validate longer duplicate runs
- show user-facing error before export

## Empty States

Required empty states:

- no workbook loaded
- no current week
- no roster rows
- no generated preview
- no exportable weeks

Each empty state should offer the next action:

- import Excel
- create week
- add location
- generate preview

## Error States

Error messages must be short and actionable.

Examples:

- invalid date range
- empty location with teacher values
- no exportable week
- unsupported Excel structure
- export permission denied

Do not show raw stack traces to users.

## Accessibility

- Touch targets must be at least 48 logical pixels.
- Text fields must have labels.
- Cards must have clear headings.
- Color must not be the only indicator of validation state.
- Support large text without overlapping controls.

## Responsive Behavior

Mobile:

- card/list layout
- no wide table
- bottom sheets acceptable

Tablet:

- two-pane layout allowed
- week list and detail pane allowed

Desktop/web:

- table-like layouts are allowed only as an adaptive enhancement
- mobile card/list model remains the canonical interaction model

## Visual Consistency

- Keep the app utilitarian and work-focused.
- Use restrained color.
- Prioritize readability and repeated editing.
- Avoid decorative screens that delay the roster workflow.

## Non-Goals

Do not build:

- marketing landing pages
- dashboards unrelated to roster generation
- complex animations
- gamified UI
- AI-generated schedule suggestions

unless explicitly requested.
