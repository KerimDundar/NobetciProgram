# ARCHIVED — DO NOT LOAD AS CONTEXT
# Fix rules are distilled into .claude/agents/roster-logic.md and .claude/agents/export.md.
# This file remains for traceability only.

# Critical Review Fix Rules

This file does not replace `agents/rules.md`.

`agents/rules.md` describes the current desktop behavior.
This file lists inconsistencies, risks, hidden bugs, and proposed fix rules for the rewrite.

## FIX 1 - Turkish-Aware Text Comparison

Source:
- `desktop_app/roster_logic.py: normalize_text`
- `desktop_app/roster_logic.py: parse_title`
- `desktop_app/roster_io.py: _detect_day_columns`
- `desktop_app/roster_io.py: _find_week_title_rows`
- `desktop_app/roster_io.py: _extract_school_name_from_text`

Problem:
The current system uses Python `str.upper()` for business comparisons. This is not Turkish-locale uppercasing.

Examples:
- `"Nöbetçi Öğretmen Listesi"` becomes `"NÖBETÇI ÖĞRETMEN LISTESI"`, not `"NÖBETÇİ ÖĞRETMEN LİSTESİ"`.
- `"Pazartesi"` becomes `"PAZARTESI"`, not `"PAZARTESİ"`.
- `"Nisan"` becomes `"NISAN"`, not `"NİSAN"`.
- `"Ali"` becomes `"ALI"`, while `"ALİ"` remains `"ALİ"`.

Risk:
- Mixed-case Turkish titles may not load.
- Mixed-case Turkish day headers may not be detected.
- Mixed-case Turkish month names may not parse.
- Same teacher/location text can be treated as different.
- Duplicate-location merges can fail or preserve duplicate teacher cells incorrectly.

FIX rule:
All business comparisons must use one shared Turkish-aware canonical text function.

The canonical function must:
- Unicode-normalize text to NFC.
- Collapse whitespace.
- Trim edges.
- Apply deterministic Turkish casing, at minimum:
  - `i` -> `İ`
  - `ı` -> `I`
  - then uppercase remaining letters.

This canonical function must be used for:
- title suffix detection
- month-name parsing
- weekday header detection
- duplicate-location comparison
- duplicate teacher-name conflict comparison
- school/principal label detection

Display text must still preserve user-entered spelling unless a separate display rule explicitly uppercases it.

## FIX 2 - Title Parsing Must Accept Human-Cased Turkish Titles

Source:
- `desktop_app/roster_logic.py: parse_title`
- `desktop_app/roster_io.py: _read_week_block`

Problem:
Title parsing requires the normalized title to contain the exact normalized uppercase suffix. Because normalization is not Turkish-aware, common title text such as:

`2 Şubat-6 Şubat Haftası Nöbetçi Öğretmen Listesi`

fails before date parsing.

Risk:
Excel files that are visually correct but not fully uppercase Turkish cannot be imported.

FIX rule:
Title parsing must compare suffixes with the shared Turkish-aware canonical comparison from FIX 1.

The parser must accept all of these as the same suffix:
- `HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ`
- `Haftası Nöbetçi Öğretmen Listesi`
- `haftası nöbetçi öğretmen listesi`

The generated title may still use the canonical uppercase display format.

## FIX 3 - Cross-Year Week Ranges Must Be Explicitly Handled

Source:
- `desktop_app/roster_logic.py: parse_title`
- `desktop_app/roster_logic.py: build_title`

Problem:
The current parser assigns the same year to both title dates unless a single `20xx` appears in the title. A title like:

`29 ARALIK-2 OCAK HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ`

with default year `2026` becomes:
- start: `2026-12-29`
- end: `2026-01-02`

The end date is before the start date.

Risk:
- Imported cross-year weeks become invalid ranges.
- Previous/next generation preserves the invalid ordering.
- range generation rejects or misinterprets the dates.
- export filenames and preview summaries can become misleading.

FIX rule:
When parsing a title without separate explicit years:
- If `end_month < start_month`, set `end_year = start_year + 1`.
- Otherwise use the same year.

If explicit years are supported later, both dates must be parsed explicitly and validated.

## FIX 4 - Duplicate Location Keys Need Unicode Separator Rules

Source:
- `desktop_app/roster_logic.py: duplicate_location_key`
- `desktop_app/roster_logic.py: is_duplicate_location`

Problem:
Duplicate-location matching removes whitespace and the ASCII hyphen `-`, but not other dash characters. It also inherits the Turkish casing problem.

Examples that are currently risky:
- `Bahçe-1` vs `bahçe 1`
- `İdare` vs `idare`
- `Kat-1` vs `Kat–1` where the second dash is an en dash.

Risk:
Rows that look like the same duty location may not merge.

FIX rule:
Duplicate-location keys must be generated with the shared Turkish-aware canonical text function.

After canonicalization, remove:
- all Unicode whitespace
- ASCII hyphen-minus
- common Unicode dash punctuation, including non-breaking hyphen, en dash, em dash, and minus sign

Do not remove all punctuation by default. Characters such as `/`, `.`, and parentheses may distinguish real locations unless the business explicitly decides otherwise.

## FIX 5 - Duplicate Teacher Conflict Checks Must Use Canonical Name Equality

Source:
- `desktop_app/roster_io.py: _apply_duplicate_location_pair_excel_merge`
- `desktop_app/pdf_export.py: _apply_duplicate_location_pdf_merge_rules`

Problem:
For duplicate-location rows, teacher cells are merged only when both non-empty names are equal after `normalize_text`.

Because `normalize_text` is not Turkish-aware:
- `Ali` and `ALİ` can be treated as different.
- `İpek` and `ipek` can be treated as different.

Risk:
The same teacher may appear as a conflict in Excel/PDF output, causing cells not to merge even though they should.

FIX rule:
Duplicate teacher conflict detection must use the same canonical comparison as other business text.

Merge rule:
- If both cells are non-empty and canonical names are equal, merge and keep the top display spelling.
- If both cells are non-empty and canonical names differ, keep both visible and do not merge that teacher column.

## FIX 6 - Excel Duplicate Merge Must Be Round-Trip Safe

Source:
- `desktop_app/roster_io.py: _apply_duplicate_location_pair_excel_merge`
- `desktop_app/roster_io.py: _read_week_block`
- `desktop_app/roster_io.py: _find_last_block_end`

Problem:
Excel export persists duplicate-location merges by merging cells and clearing bottom cells. This is only visual in the exported workbook, but the same workbook can later be loaded again.

When reloading:
- merged child cells read as empty
- a fully merged bottom duplicate row can look like a blank row
- `_read_week_block` can stop early
- `_find_last_block_end` can detect the block end too early

Risk:
- Exported Excel files cannot reliably round-trip back into the app.
- Rows below a fully merged duplicate pair can be lost on import.
- New appended blocks can be inserted in the wrong place.

FIX rule:
Excel import and append-end detection must understand merged cells.

Required behavior:
- When reading a body row, if a cell belongs to a merged range, use the range's top-left value for logical reading.
- Do not treat a row as the empty block sentinel if it is inside a merged range that belongs to the current table body.
- `_find_last_block_end` must scan through merged body ranges before deciding where the block ends.

Alternative acceptable fix:
- Keep logical data unmerged in a hidden sheet or metadata section, and use visual merges only for presentation.

## FIX 7 - Duplicate Location Runs Must Not Be Partially Merged Silently

Source:
- `desktop_app/roster_io.py: _apply_duplicate_location_excel_merge_rules`
- `desktop_app/pdf_export.py: _apply_duplicate_location_pdf_merge_rules`

Problem:
Duplicate-location scanning merges adjacent pairs and then skips two rows. Three consecutive duplicate locations are handled as:
- rows 1-2 merged
- row 3 left unmerged

The same limitation exists in both Excel and PDF paths.

Risk:
If users enter three or more rows for the same location, output is partially merged without warning. The result can look arbitrary.

FIX rule:
The rewrite must define one explicit duplicate-run policy.

Preferred rule:
- Detect maximal consecutive runs with the same duplicate-location key.
- If the business allows multi-row same-location groups, merge the location column across the entire run and apply teacher-cell conflict rules pairwise or per column across the run.
- If the business only allows pairs, validate the data and report an error when a duplicate run has more than two rows.

Never silently merge only the first pair of a longer run.

## FIX 8 - Roster Rows Must Be Normalized To Exactly Five Day Cells

Source:
- `desktop_app/roster_logic.py: rotate_roster`
- `desktop_app/roster_logic.py: rotate_roster_back`
- `desktop_app/roster_logic.py: build_week`
- `desktop_app/ui.py: _copy_roster_rows`

Problem:
Several functions assume every roster row has indexes `0..4`, but input copying and week construction do not enforce that.

Examples:
- `rotate_roster([["Ali"]])` can raise `IndexError`.
- A state file or external caller can provide short rows.
- Extra cells after Friday can survive copying.

Risk:
- Rotation can crash.
- PDF export can crash or build malformed tables.
- Excel export can write unexpected columns beyond Friday.

FIX rule:
Every roster row must be normalized at system boundaries.

Canonical roster row shape:
`[monday, tuesday, wednesday, thursday, friday]`

Normalization:
- Convert missing rows to five empty strings.
- Pad short rows with empty strings.
- Trim extra cells after Friday.
- Convert `None` to empty string.
- Preserve cleaned display text for the five valid cells.

Apply this normalization when:
- loading state
- loading Excel
- saving edit-window data
- building a week dictionary
- generating previous/next/month/range weeks
- exporting PDF or Excel

## FIX 9 - Output Writers Must Not Use Variable-Width Roster Rows

Source:
- `desktop_app/roster_io.py: append_week_block`
- `desktop_app/pdf_export.py: _build_week_elements`
- `desktop_app/pdf_export.py: _apply_duplicate_location_pdf_merge_rules`

Problem:
Excel and PDF handle non-five-cell roster rows differently.

Excel:
- `append_week_block` writes every value in `row_vals`, so extra values can go into columns after F.
- Formatting and duplicate merge still only apply to A-F.

PDF:
- `_build_week_elements` extends body rows with every value in `row_vals`.
- Duplicate merge assumes columns `1..5` exist.
- ReportLab table widths are defined for exactly six columns.

Risk:
- Excel may contain unformatted unexpected data outside the intended table.
- PDF may fail or render malformed tables.
- Excel and PDF exports can disagree for the same week.

FIX rule:
Before writing any output, transform each roster row to exactly five day cells using FIX 8.

Output functions must never write or render roster cells beyond Friday.

## FIX 10 - Replace Magic Day/Column Counts With One Day Model

Source:
- `desktop_app/roster_logic.py: rotate_roster`
- `desktop_app/roster_logic.py: rotate_roster_back`
- `desktop_app/roster_io.py: TABLE_COLUMN_COUNT`
- `desktop_app/pdf_export.py: WEEK_TABLE_COLUMN_COUNT`
- `desktop_app/ui.py: MAIN_TABLE_DAY_COUNT`

Problem:
The current code repeats the five-day assumption in multiple forms:
- `cols = 5`
- `range(1, 6)`
- `WEEK_TABLE_COLUMN_COUNT = 6`
- `MAIN_TABLE_DAY_COUNT = 5`
- Excel B-F column loops

Risk:
If the day model changes or one constant is updated without the others, rotation, preview, PDF, and Excel can diverge.

FIX rule:
The rewrite must use a single day model:

```text
dayNames = [Pazartesi, Salı, Çarşamba, Perşembe, Cuma]
dayCount = dayNames.length
tableColumnCount = 1 + dayCount
```

All loops, exports, imports, validation, and UI grid sizes must derive from that model.

Hard-coded `5`, `6`, `B-F`, or `0..4` day assumptions are allowed only in one central definition file.

## FIX 11 - Preview Edits Must Affect Export Or Be Disabled

Source:
- `desktop_app/ui.py: _commit_preview_cell_edit`
- `desktop_app/ui.py: _sync_preview_edits`
- `desktop_app/ui.py: _export_weeks_snapshot`

Problem:
Preview table cells are editable. Edits update `self.preview_weeks`, but `_sync_preview_edits` only updates labels.

Export reads from:
- `self.month_generated`, or
- current week state

Export does not read from `self.preview_weeks`.

Risk:
Users can edit the visible preview, then export a PDF/Excel file that ignores their edits.

FIX rule:
Choose one rule and enforce it:

Preferred rule:
- Preview is the export source.
- Any preview edit must update the underlying export snapshot:
  - update `month_generated` when previewing generated weeks
  - update current locations/roster when previewing the single current week
  - persist after edit

Alternative rule:
- Preview is read-only.
- Disable preview cell editing entirely.

Do not allow editable preview data that is ignored by export.

## FIX 12 - Auto-Generated Preview Must Match Export Snapshot

Source:
- `desktop_app/ui.py: _refresh_preview`
- `desktop_app/ui.py: _build_weeks_for_output_range`
- `desktop_app/ui.py: _export_weeks_snapshot`

Problem:
When there is no `month_generated`, `_refresh_preview` may auto-generate multiple weeks from `current_start` and `current_end` for display.

But `_export_weeks_snapshot` does not return those displayed auto-generated weeks. It falls back to one current-week dictionary.

Risk:
The UI can display multiple rotated weeks while export produces only one week.

FIX rule:
There must be one shared function for "weeks currently intended for export".

Rules:
- Preview must render exactly that function's result.
- PDF export must use exactly that function's result.
- Excel export must use exactly that function's result.
- Header/output-scope labels must describe exactly that same result.

If auto-generation is displayed, it must either:
- be persisted into the export snapshot, or
- be recomputed by the export snapshot using the same inputs.

## FIX 13 - Multi-Week Validity Filtering Must Be Shared

Source:
- `desktop_app/roster_io.py: write_weeks_to_excel`
- `desktop_app/pdf_export.py: export_weeks_pdf`
- `desktop_app/ui.py: _export_weeks_snapshot`

Problem:
Different paths use different valid-week checks.

Current behavior:
- UI snapshot: title must be non-empty after `.strip()`.
- Excel multi-week: title must be non-empty after `.strip()`.
- PDF multi-week direct call: title only needs to be truthy; whitespace-only titles are accepted.

Risk:
The same input list can produce different week counts in Excel and PDF if exporters are called directly or reused later.

FIX rule:
Create one shared `isValidWeekForExport(week)` rule.

Required behavior:
- `week` must be a dictionary/object.
- `title.trim()` must be non-empty.
- `locations` and `roster` must be normalized before export.

Both Excel and PDF multi-week exporters must use this exact rule.

## FIX 14 - Multi-Week School And Principal Scope Must Be Consistent

Source:
- `desktop_app/roster_io.py: write_weeks_to_excel`
- `desktop_app/pdf_export.py: export_weeks_pdf`

Problem:
Excel and PDF choose school/principal metadata at different scopes.

Excel multi-week:
- Chooses the first non-empty school name across all valid weeks.
- Writes it once at the top of the entire batch.
- Chooses the first non-empty principal name across all valid weeks.
- Writes it once at the end of the entire batch.

PDF multi-week:
- Processes weeks in pages of four.
- Chooses first non-empty school/principal per page group.
- Writes school/principal once per page group.

Risk:
For the same generated weeks, Excel and PDF can show different school/principal information.

Example:
- Week 1 school: `Okul A`
- Week 5 school: `Okul B`

Excel shows `Okul A` once for the whole file.
PDF page 2 can show `Okul B`.

FIX rule:
Define one multi-week metadata scope.

Allowed choices:
- File scope: one school/principal for the entire export.
- Page/group scope: one school/principal per four-week group.
- Week scope: each week carries its own school/principal.

Excel and PDF must use the same scope. If PDF uses pages of four, Excel must either group similarly or explicitly use file-scope metadata in every PDF page.

## FIX 15 - Principal Display Format Must Be Unified

Source:
- `desktop_app/roster_io.py: _write_principal_line`
- `desktop_app/pdf_export.py: _build_principal_line`

Problem:
Excel and PDF format principal information differently.

Excel:
- writes one cell as `Müdür : {name}`

PDF:
- writes `{name}` on one line
- writes `Müdür` on a second line
- if name is empty, still writes `Müdür`

Risk:
The same roster output does not have the same signature semantics across formats.

FIX rule:
Define a single signature display rule.

The rule must specify:
- whether principal name appears before or after the role
- whether `Müdür :` is used
- whether an empty principal still prints `Müdür`
- whether the same rule applies to single-week and multi-week exports

Excel and PDF must render the same semantic content, even if physical layout differs.

## FIX 16 - Blank Month Placeholders Must Have An Explicit Export Policy

Source:
- `desktop_app/ui.py: _build_month_in_range`
- `desktop_app/ui.py: _export_weeks_snapshot`
- `desktop_app/roster_io.py: write_weeks_to_excel`
- `desktop_app/pdf_export.py: export_weeks_pdf`

Problem:
`_build_month_in_range` pads generated results to four entries with blank placeholder week dictionaries.

Exports then remove blank-title weeks through the UI snapshot and Excel filtering. PDF direct export has different filtering.

Risk:
The preview can conceptually contain four table slots, while exported files contain only real titled weeks.

FIX rule:
Define whether blank placeholders are exportable.

Recommended rule:
- Blank placeholders are UI-only and must never export.
- The UI must clearly exclude them from export count.
- Exporters must share the same valid-week filter from FIX 13.

If blank placeholders are required in output, they must be represented as explicit blank export tables with valid layout fields, not as empty-title weeks.

## FIX 17 - PDF Multi-Week Layout Row Count Must Match Actual Tables

Source:
- `desktop_app/pdf_export.py: _week_row_count`
- `desktop_app/pdf_export.py: _build_week_elements`
- `desktop_app/pdf_export.py: _compute_multiweek_page_layout`

Problem:
`_week_row_count` counts empty-location weeks as having one body row:

`2 + max(1, len(locations))`

But `_build_week_elements` creates body rows only by iterating actual `locations`. If `locations` is empty, the rendered table has title and header rows only.

Risk:
PDF font/row-height calculation can be based on rows that will not exist.

FIX rule:
PDF layout row counting must use the exact same normalized table model as rendering.

If empty-location weeks are valid:
- render one explicit blank body row
- count one blank body row

If empty-location weeks are invalid:
- filter them before layout
- count no rows for them

Do not count a row that rendering does not create.

## FIX 18 - Week Span Generation Must Be Consistent

Source:
- `desktop_app/ui.py: generate_month`
- `desktop_app/ui.py: _build_month_in_range`
- `desktop_app/ui.py: _build_weeks_for_output_range`
- `desktop_app/roster_logic.py: WEEK_SPAN_DAYS`

Problem:
Different generation paths use different span rules.

Current behavior:
- `generate_month` starts from `current_start` and forces first end to `current_start + 4`.
- `_build_weeks_for_output_range` also uses `range_start + 4`.
- `_build_month_in_range` uses the current state's actual date span when current dates exist.

Risk:
Two generation buttons can produce different week end dates for the same apparent date range.

FIX rule:
Define one week-span rule.

Recommended rule:
- A roster week is always five calendar days: start date through start date + 4 days.
- All month/range generation uses that rule.
- If a user-selected range is wider than five days, it is treated as an output range containing multiple five-day weeks.
- If a user truly needs non-five-day weeks, that must be an explicit separate mode and every generator/exporter must honor it.

## FIX 19 - Multi-Week Excel Import Must Not Treat Previous Location As School

Source:
- `desktop_app/roster_io.py: _parse_school_name_from_title_row`
- `desktop_app/roster_io.py: write_weeks_to_excel`

Problem:
Multi-week Excel export writes one school row before all week blocks. Later week titles are directly after the previous week's table, with no school row before them.

When loading a later title row, `_parse_school_name_from_title_row` first checks the row immediately above the title. That row can be the previous week's last location, and ordinary text is accepted as a school name.

Risk:
Loading the last block from a multi-week Excel output can assign a duty location as `school_name`.

FIX rule:
School-name import must be structural, not "any text above title".

Allowed school-name sources:
- a row explicitly marked with `OKUL`
- a row merged across the full table width and positioned as a school header
- a known workbook-level metadata field
- the first global school header before the first title

Do not treat an arbitrary row above a later title as school name unless it matches the school-row structure.

## FIX 20 - Excel Append Position Must Account For Visual Merges

Source:
- `desktop_app/roster_io.py: _find_last_block_end`
- `desktop_app/roster_io.py: write_week_to_excel`
- `desktop_app/roster_io.py: write_weeks_to_excel`

Problem:
Append position is based on `_find_last_block_end`. This function can stop at the first row that appears empty in column A and day columns.

Merged duplicate-location child rows can appear empty even though they are visually part of the table.

Risk:
New week blocks can be appended inside or immediately after an incomplete scan of the previous block.

FIX rule:
Append-end detection must be merge-aware and table-aware.

Required behavior:
- Treat rows covered by merged ranges in the current table as occupied.
- Continue scanning until after the full body and signature/footer area.
- Prefer detecting the next title row or structured table boundary over relying only on the first blank-looking row.

This rule must be applied before any Excel append operation.
