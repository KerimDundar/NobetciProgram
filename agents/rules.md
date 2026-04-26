# ARCHIVED — DO NOT LOAD AS CONTEXT
# This file describes the original Python desktop app. The Flutter implementation is complete.
# Use .claude/agents/roster-logic.md for active guidance.

## ROSTER TEXT NORMALIZATION

Source:
desktop_app/roster_logic.py: normalize_text
desktop_app/roster_logic.py: normalize_name_text

Behavior:
`normalize_text(value)` converts `None` or any falsey value to `""`, collapses every run of whitespace to one ASCII space, strips leading/trailing whitespace, then applies Python `str.upper()`.

`normalize_name_text(value)` converts `None` or any falsey value to `""`, collapses every run of whitespace to one ASCII space, and strips leading/trailing whitespace. It does not uppercase.

These functions are used before duplicate-location matching, Excel/PDF name output, school/principal extraction, and title/header checks.

Edge Cases:
- Python `str.upper()` is not Turkish-locale uppercasing. Mixed-case Turkish text containing `i` may become `I`, not `İ`.
- Newlines, tabs, and repeated spaces are all collapsed by `\s+`.
- `normalize_name_text` preserves original letter case after whitespace cleanup.
- Non-string values are not converted inside these functions; callers usually convert with `str(...)` before calling.

Example:
Input:
`normalize_text("  A   B\tc  ")`

Output:
`"A B C"`

Input:
`normalize_name_text("  Ali\n  Veli  ")`

Output:
`"Ali Veli"`

Input:
`normalize_text("Nöbetçi Öğretmen Listesi")`

Output:
`"NÖBETÇI ÖĞRETMEN LISTESI"`

This does not become the exact all-uppercase suffix used by `TITLE_SUFFIX`, which contains Turkish dotted `İ` characters.

## DUPLICATE LOCATION KEY

Source:
desktop_app/roster_logic.py: duplicate_location_key
desktop_app/roster_logic.py: is_duplicate_location

Behavior:
`duplicate_location_key(value)` first runs `normalize_text(value or "")`.

If the normalized text is empty, it returns `""`.

Otherwise it removes every run of whitespace or hyphen characters using regex `[\s-]+`, then returns the result.

`is_duplicate_location(top, bottom)`:
- Computes `top_key = duplicate_location_key(top)`.
- Returns `True` only when `top_key` is non-empty and exactly equals `duplicate_location_key(bottom)`.
- Returns `False` when the top key is empty, even if the bottom key is also empty.

This rule is the shared duplicate-location test used by both Excel merge and PDF merge logic.

Edge Cases:
- Spaces and hyphens are ignored for matching.
- Case differences are ignored through `normalize_text`.
- Other punctuation is not ignored.
- Empty top values never match.
- This only compares two provided strings; it does not search non-adjacent rows.

Example:
Input:
`is_duplicate_location("Bahce-1", "bahce 1")`

Output:
`True` because both keys become `"BAHCE1"`.

Input:
`is_duplicate_location("A/B", "AB")`

Output:
`False` because `/` is preserved, so the keys are `"A/B"` and `"AB"`.

Input:
`is_duplicate_location("", "")`

Output:
`False` because the top key is empty.

## FORWARD ROSTER ROTATION

Source:
desktop_app/roster_logic.py: rotate_roster
desktop_app/ui.py: EditWindow._shift_day_column with `direction == "up"`

Behavior:
`rotate_roster(roster)` rotates teacher names independently inside each of the first five day columns.

For every column index `0..4`:
- It finds row indexes where `roster[row][column]` exists and `.strip()` is non-empty.
- It collects only those non-empty values in their current vertical order.
- It rotates that collected list forward by one: `names[1:] + names[:1]`.
- It writes the rotated values back only to the original non-empty row indexes.
- Empty slots stay empty and keep their original row positions.

The function starts with `new_roster = [row[:] for row in roster]`, so it shallow-copies rows before changing values.

Edge Cases:
- If `roster` is empty or falsey, output is `[]`.
- Exactly five columns are processed. The function expects every row to have indexes `0..4`; a short row can raise `IndexError`.
- Columns with zero non-empty values are unchanged.
- Columns with one non-empty value are effectively unchanged because rotating one item returns the same item.
- Values containing only whitespace are treated as empty for deciding which slots rotate, but the original whitespace value remains in the copied row if the slot is not selected.
- Extra columns after index `4` are copied and never rotated.
- Rotation is column-local; names do not move between weekdays.

Example:
Input roster:
```text
[
  ["A", "B", "",  "D", "E"],
  ["",  "C", "X", "",  "F"],
  ["G", "",  "Y", "H", "" ],
  ["I", "J", "",  "K", "L"]
]
```

Output from `rotate_roster`:
```text
[
  ["G", "C", "",  "H", "F"],
  ["",  "J", "Y", "",  "L"],
  ["I", "",  "X", "K", "" ],
  ["A", "B", "",  "D", "E"]
]
```

Column-by-column:
- Monday selected rows are `0,2,3`; values `A,G,I` become `G,I,A`.
- Tuesday selected rows are `0,1,3`; values `B,C,J` become `C,J,B`.
- Wednesday selected rows are `1,2`; values `X,Y` become `Y,X`.
- Thursday selected rows are `0,2,3`; values `D,H,K` become `H,K,D`.
- Friday selected rows are `0,1,3`; values `E,F,L` become `F,L,E`.

## BACKWARD ROSTER ROTATION

Source:
desktop_app/roster_logic.py: rotate_roster_back
desktop_app/ui.py: EditWindow._shift_day_column with `direction != "up"`

Behavior:
`rotate_roster_back(roster)` is the inverse of `rotate_roster`.

For every column index `0..4`:
- It finds row indexes where `roster[row][column]` exists and `.strip()` is non-empty.
- It collects only those non-empty values in their current vertical order.
- It rotates that collected list backward by one: `names[-1:] + names[:-1]`.
- It writes the rotated values back only to the original non-empty row indexes.
- Empty slots stay empty and keep their original row positions.

The function starts with `new_roster = [row[:] for row in roster]`, so it shallow-copies rows before changing values.

Edge Cases:
- If `roster` is empty or falsey, output is `[]`.
- Exactly five columns are processed. The function expects every row to have indexes `0..4`; a short row can raise `IndexError`.
- Columns with zero non-empty values are unchanged.
- Columns with one non-empty value are effectively unchanged.
- Extra columns after index `4` are copied and never rotated.
- `rotate_roster_back(rotate_roster(roster))` restores the original roster when all rows have at least five columns and no external mutation happens.

Example:
Input roster:
```text
[
  ["G", "C", "",  "H", "F"],
  ["",  "J", "Y", "",  "L"],
  ["I", "",  "X", "K", "" ],
  ["A", "B", "",  "D", "E"]
]
```

Output from `rotate_roster_back`:
```text
[
  ["A", "B", "",  "D", "E"],
  ["",  "C", "X", "",  "F"],
  ["G", "",  "Y", "H", "" ],
  ["I", "J", "",  "K", "L"]
]
```

## TITLE PARSING

Source:
desktop_app/roster_logic.py: parse_title
desktop_app/roster_io.py: _read_week_block

Behavior:
`parse_title(title, default_year)` parses a title containing the exact normalized suffix:
`HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ`.

Processing steps:
- If `title` is empty or falsey, raises `ValueError("Başlık boş.")`.
- Runs `normalize_text(title)`.
- Checks whether `normalize_text(TITLE_SUFFIX)` is contained anywhere in the normalized title.
- Finds the first date range matching:
  `(\d{1,2})\s+MONTH\s*-\s*(\d{1,2})\s+MONTH`
- Month names must be in `TURKISH_MONTHS`.
- If the title contains a year matching `\b(20\d{2})\b`, that year is used.
- If no year is found, `default_year` is used for both start and end.
- Returns `(start_date, end_date, TITLE_SUFFIX)`.

Edge Cases:
- The suffix check happens before date extraction. A title with valid dates but without the expected suffix fails.
- Mixed-case Turkish titles can fail because `normalize_text` uses Python `upper()`, not Turkish-locale uppercasing.
- Cross-year ranges are not adjusted. `29 ARALIK-2 OCAK` with `default_year=2026` returns start `2026-12-29` and end `2026-01-02`.
- Invalid calendar dates raise Python `ValueError` from `date(...)`.
- Unknown month names raise `ValueError("Başlıkta bilinmeyen Türkçe ay adı var.")`.
- A year like `1999` is ignored because only `20xx` matches.
- If more than one `20xx` year appears, the first match is used.

Example:
Input:
`parse_title("2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ", 2026)`

Output:
`(date(2026, 2, 2), date(2026, 2, 6), "HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ")`

Input:
`parse_title("2 NİSAN-6 NİSAN 2027 HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ", 2026)`

Output:
`(date(2027, 4, 2), date(2027, 4, 6), "HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ")`

Input:
`parse_title("29 ARALIK-2 OCAK HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ", 2026)`

Output:
`(date(2026, 12, 29), date(2026, 1, 2), "HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ")`

Input:
`parse_title("2 Şubat-6 Şubat Haftası Nöbetçi Öğretmen Listesi", 2026)`

Output:
Raises `ValueError("Başlık beklenen ifadeyi içermiyor.")` because Python uppercasing does not produce the exact uppercase Turkish suffix.

## TITLE BUILDING

Source:
desktop_app/roster_logic.py: build_title

Behavior:
`build_title(start, end)` builds the exact title:
`"{start.day} {START_MONTH}-{end.day} {END_MONTH} {TITLE_SUFFIX}"`

Month names come from `MONTHS_BY_NUM`, which is the reverse mapping of `TURKISH_MONTHS`.

Edge Cases:
- No year is included in generated titles.
- The function does not validate that `end` is after `start`.
- The function does not validate that the range is five days.
- If `start` or `end` is not a `date` with a valid `.month` and `.day`, normal Python errors occur.

Example:
Input:
`build_title(date(2026, 2, 2), date(2026, 2, 6))`

Output:
`"2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ"`

## WEEK DICTIONARY CONSTRUCTION

Source:
desktop_app/roster_logic.py: build_week

Behavior:
`build_week(start, end, locations, roster, school_name="", principal_name="")` returns a dictionary with these keys:
- `title`: generated by `build_title(start, end)`
- `start_date`: `start.isoformat()`
- `end_date`: `end.isoformat()`
- `school_name`: input `school_name`
- `principal_name`: input `principal_name`
- `locations`: `list(locations or [])`
- `roster`: for every item in `(roster or [])`, if the item is a list or tuple it is copied with `list(row)`, otherwise it becomes `[]`

Edge Cases:
- `locations=None` becomes `[]`.
- `roster=None` becomes `[]`.
- Non-list/non-tuple roster rows become empty rows.
- Roster row lengths are not normalized here; rows shorter or longer than five cells are preserved as-is.
- `locations` and `roster` lengths are not reconciled here.

Example:
Input:
```text
build_week(
  date(2026, 2, 2),
  date(2026, 2, 6),
  ["Bahce", "Koridor"],
  [["Ali", "Ayse"], "bad-row"],
  "Okul",
  "Mudur"
)
```

Output:
```text
{
  "title": "2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ",
  "start_date": "2026-02-02",
  "end_date": "2026-02-06",
  "school_name": "Okul",
  "principal_name": "Mudur",
  "locations": ["Bahce", "Koridor"],
  "roster": [["Ali", "Ayse"], []]
}
```

## NEXT WEEK DATE STEP

Source:
desktop_app/roster_logic.py: next_week_dates
desktop_app/roster_logic.py: build_next_week

Behavior:
`next_week_dates(start, end)` adds exactly `7` days to both dates.

`build_next_week(current_start, current_end, locations, roster, school_name="", principal_name="")`:
- Computes `(next_start, next_end)` with `next_week_dates`.
- Rotates the roster once with `rotate_roster`.
- Builds and returns a week dictionary for the next dates with the same locations, school name, and principal name.

Edge Cases:
- The date step is always seven days, independent of weekday or range length.
- If the current week range is not Monday-Friday or not five days, the same nonstandard span is preserved by adding seven days to both endpoints.
- All `rotate_roster` edge cases apply.

Example:
Input:
```text
build_next_week(
  date(2026, 2, 2),
  date(2026, 2, 6),
  ["Loc1", "Loc2"],
  [
    ["A", "B", "C", "D", "E"],
    ["F", "G", "H", "I", "J"]
  ],
  "Okul",
  "Mudur"
)
```

Output:
```text
{
  "title": "9 ŞUBAT-13 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ",
  "start_date": "2026-02-09",
  "end_date": "2026-02-13",
  "school_name": "Okul",
  "principal_name": "Mudur",
  "locations": ["Loc1", "Loc2"],
  "roster": [
    ["F", "G", "H", "I", "J"],
    ["A", "B", "C", "D", "E"]
  ]
}
```

## DATE INPUT PARSING

Source:
desktop_app/roster_logic.py: parse_date_input
desktop_app/ui.py: _parse_ui_date
desktop_app/ui.py: App._parse_range_dates

Behavior:
`parse_date_input(value, default_year)` accepts:
- `YYYY-MM-DD`
- `DD.MM`
- `DD.MM.YYYY`

For `DD.MM`, the year is `default_year`.

If `value` is empty or falsey, it returns `None`.

If the format is not accepted, it raises `ValueError("Geçersiz tarih biçimi.")`.

`ui._parse_ui_date(value)` wraps this parser using the current year and returns `None` instead of raising.

`App._parse_range_dates(start_val, end_val)`:
- Uses `self._ensure_year()` as the default year.
- Requires both parsed start and parsed end.
- Raises `ValueError("Başlangıç ve bitiş tarihi zorunlu.")` if either is missing.
- Raises `ValueError("Başlangıç tarihi bitiş tarihinden büyük olamaz.")` if start is after end.
- Returns `(start_date, end_date)`.

Edge Cases:
- `YYYY-M-D` is rejected; ISO input must be exactly two-digit month and day.
- `D.M` is accepted because the dotted format allows one or two digits.
- Invalid real dates raise Python `ValueError`.
- `ui._parse_ui_date` hides parser errors by returning `None`.
- In most UI handlers, exceptions from `_parse_range_dates` are shown as the generic `"Geçersiz tarih aralığı."`.

Example:
Input:
`parse_date_input("2026-02-02", 2025)`

Output:
`date(2026, 2, 2)`

Input:
`parse_date_input("2.2", 2026)`

Output:
`date(2026, 2, 2)`

Input:
`parse_date_input("2026/02/02", 2026)`

Output:
Raises `ValueError("Geçersiz tarih biçimi.")`.

## EXCEL WEEK TITLE ROW DISCOVERY

Source:
desktop_app/roster_io.py: _find_week_title_rows
desktop_app/roster_io.py: load_last_week
desktop_app/roster_io.py: _find_last_block_end

Behavior:
`_find_week_title_rows(ws)` scans only column A from row `1` through `ws.max_row`.

A row is a week title row when column A is a string and `normalize_text(TITLE_SUFFIX)` is contained in `normalize_text(cell_value)`.

It returns a list of `(row_number, original_cell_value)` in ascending row order.

`load_last_week(path, default_year)` loads the active worksheet and reads only the last title row found by `_find_week_title_rows`.

`_find_last_block_end(ws)` also uses the last title row to decide where a new append should start.

Edge Cases:
- Titles outside column A are ignored.
- If no title row is found, `load_last_week` raises `ValueError("A sutununda hafta blogu bulunamadi.")`.
- If multiple week blocks exist, only the last one is loaded by `load_last_week`.
- Mixed-case Turkish suffixes can fail because title matching uses `normalize_text`.
- Extra text before or after the suffix is allowed as long as the normalized suffix is contained.

Example:
Input worksheet column A:
```text
1: "School"
2: "2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ"
8: "9 ŞUBAT-13 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ"
```

Output from `_find_week_title_rows`:
```text
[
  (2, "2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ"),
  (8, "9 ŞUBAT-13 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ")
]
```

`load_last_week` reads the block starting at row `8`.

## EXCEL DAY COLUMN DETECTION

Source:
desktop_app/roster_io.py: _detect_day_columns
desktop_app/roster_io.py: _read_week_block
desktop_app/roster_io.py: _find_last_block_end

Behavior:
`_detect_day_columns(ws, header_row)` scans columns `1..max(ws.max_column, 6)` in the header row.

When a cell is a string, it is normalized with `normalize_text`. If the normalized value equals one of:
`PAZARTESİ`, `SALI`, `ÇARŞAMBA`, `PERŞEMBE`, `CUMA`, the function records that day name's column number.

If all five day names are found, it returns a dictionary from day name to column number.

If any day name is missing, it returns `None`.

Edge Cases:
- Day columns can be in any columns, not necessarily B-F.
- The location column is still read from column A even when day columns are elsewhere.
- If a day header appears more than once, the last matching column wins.
- Header text must normalize exactly to a day name. Extra words like `"PAZARTESİ GÜNÜ"` do not match.
- If day columns are missing, `_read_week_block` raises `ValueError("Gun basliklari bulunamadi veya eksik.")`.
- If day columns are missing, `_find_last_block_end` returns `header_row`.

Example:
Input header row:
```text
A: "NOBET YERI"
B: "PAZARTESİ"
C: "SALI"
D: "ÇARŞAMBA"
E: "PERŞEMBE"
F: "CUMA"
```

Output:
```text
{
  "PAZARTESİ": 2,
  "SALI": 3,
  "ÇARŞAMBA": 4,
  "PERŞEMBE": 5,
  "CUMA": 6
}
```

## EXCEL SCHOOL NAME EXTRACTION

Source:
desktop_app/roster_io.py: _extract_colon_value
desktop_app/roster_io.py: _extract_school_name_from_text
desktop_app/roster_io.py: _find_global_school_name
desktop_app/roster_io.py: _parse_school_name_from_title_row

Behavior:
`_extract_colon_value(value)` returns the substring after the first `:` if a colon exists; otherwise it returns the stripped input.

`_extract_school_name_from_text(text)`:
- Cleans text with `normalize_name_text`.
- Returns `""` for empty text.
- If normalized text starts with `"OKUL"`, returns `_extract_colon_value(clean_text)`.
- Returns `""` if the text contains the title suffix.
- Returns `""` if normalized text starts with `"MUDUR"` or `"MÜDÜR"`.
- Returns `""` if normalized text is exactly `"NOBET YERI"`.
- Returns `""` if normalized text is one of the day names.
- Otherwise returns the cleaned original text.

`_find_global_school_name(ws)`:
- Finds the first title row.
- Scans column A above that first title row.
- Returns the first value accepted by `_extract_school_name_from_text`.
- Returns `""` if none is found.

`_parse_school_name_from_title_row(ws, title_row)`:
- First checks column A of `title_row - 1`.
- If that previous row contains an accepted school name, returns it.
- Otherwise falls back to `_find_global_school_name(ws)`.

Edge Cases:
- `"OKUL: Ataturk"` becomes `"Ataturk"`.
- `"OKUL Ataturk"` has no colon, so it returns `"OKUL Ataturk"`, not `"Ataturk"`.
- Any ordinary text directly above a title row can be treated as the school name.
- In multi-week Excel output, only one school row is written before the first title. Later title rows can have the previous week's last location directly above them; `_parse_school_name_from_title_row` may treat that location as the school name when loading that later block.
- A merged school row is readable because openpyxl keeps the merged value in column A of the top-left merged cell.

Example:
Input:
`_extract_school_name_from_text("Okul : Cumhuriyet İlkokulu")`

Output:
`"Cumhuriyet İlkokulu"`

Input:
`_extract_school_name_from_text("Koridor")`

Output:
`"Koridor"`

If `"Koridor"` is the row immediately above a title, that value can become `school_name`.

## EXCEL PRINCIPAL NAME EXTRACTION

Source:
desktop_app/roster_io.py: _parse_principal_name_from_signature_row
desktop_app/roster_io.py: _write_principal_line

Behavior:
`_parse_principal_name_from_signature_row(ws, row_idx)` checks only the given row and only columns `8`, `7`, `6`, then `1`, in that order.

For the first checked cell whose value is a string and whose normalized value starts with `"MUDUR"` or `"MÜDÜR"`, it returns `_extract_colon_value(cell_value)`.

If no checked cell matches, it returns `""`.

`_write_principal_line(ws, row_idx, principal_name, font_size)` writes to column `8`:
- `"Müdür : {principal_clean}"` when the cleaned principal name is non-empty.
- `"Müdür :"` when it is empty.

Edge Cases:
- Only one row is checked: the first row after `_read_week_block` stops reading body rows.
- Principal text in another row is ignored.
- Principal text in a column other than H, G, F, or A is ignored.
- If the cell starts with `"Müdür :"`, parsing returns only the text after the first colon.
- If the cell is `"Müdür"` without a colon, parsing returns `"Müdür"`.

Example:
Input row:
```text
H10: "Müdür : Ayşe Yılmaz"
```

Output from `_parse_principal_name_from_signature_row(ws, 10)`:
`"Ayşe Yılmaz"`

Input row:
```text
H10: "Müdür :"
```

Output:
`""`

## EXCEL WEEK BLOCK READING

Source:
desktop_app/roster_io.py: _read_week_block
desktop_app/roster_io.py: load_last_week

Behavior:
`_read_week_block(ws, title_row, default_year)` reads one week block.

Steps:
- Reads title from column A at `title_row`; it must be a string.
- Treats `title_row + 1` as the header row.
- Detects day columns from that header row.
- Parses start/end dates from the title.
- Parses school name from the row above the title, with global fallback.
- Starts body reading at `header_row + 1`.
- For each body row:
  - Reads location from column A and strips it.
  - Reads teacher values for day names in `DAY_NAMES` order using detected day columns.
  - Converts empty cells to `""`; strips non-empty values after `str(...)`.
  - If location is empty and all five day values are empty, stops reading the block.
  - If location is empty but at least one day value is non-empty:
    - If no previous location was read, stops reading the block.
    - Otherwise repeats the previous location text.
  - Appends the location and five teacher values.
- After stopping, parses principal name from the current row `r`.
- Returns a dictionary:
```text
{
  "title": original_title,
  "start_date": parsed_start_date,
  "end_date": parsed_end_date,
  "school_name": parsed_school_name,
  "principal_name": parsed_principal_name,
  "locations": locations,
  "roster": roster
}
```

Edge Cases:
- The returned `start_date` and `end_date` are `date` objects, not ISO strings.
- A fully empty body row ends the block.
- A blank location with non-empty day values repeats the previous location. This is how partially merged duplicate-location rows can be reconstructed.
- A blank first body-row location stops the block even if teacher cells are filled.
- A fully merged duplicate-location bottom row has blank column A and blank merged teacher cells in openpyxl. `_read_week_block` treats that bottom row as the end of the block, so rows below it are not read.
- If the body loop reaches past `ws.max_row`, principal parsing checks `max_row + 1` and usually returns `""`.
- Only five day values are returned because reading iterates over `DAY_NAMES`.

Example:
Worksheet body after header:
```text
Row 4: A="Bahce", B="Ali", C="",    D="", E="", F=""
Row 5: A="",      B="",    C="Ayse", D="", E="", F=""
Row 6: A="",      B="",    C="",     D="", E="", F=""
```

Output body:
```text
locations = ["Bahce", "Bahce"]
roster = [
  ["Ali", "", "", "", ""],
  ["", "Ayse", "", "", ""]
]
```

Row `6` stops the block.

## EXCEL LAST BLOCK END DETECTION

Source:
desktop_app/roster_io.py: _find_last_block_end
desktop_app/roster_io.py: write_week_to_excel
desktop_app/roster_io.py: write_weeks_to_excel

Behavior:
`_find_last_block_end(ws)` finds the last existing week block so new output can be appended.

Steps:
- Finds all title rows.
- If none exist, returns `0`.
- Uses the last title row.
- Treats `last_title_row + 1` as the header row.
- Detects day columns.
- If day columns cannot be detected, returns `header_row`.
- Starts scanning at `header_row + 1`.
- A row is considered the end sentinel when:
  - column A is empty after `str(...).strip()`, and
  - every detected day column value is exactly `None` or `""`.
- Returns the previous row number, `r - 1`.

Edge Cases:
- A day cell containing only spaces is not considered empty because this function checks raw values against `(None, "")`.
- A body row with blank location but any non-empty day cell is considered part of the block.
- A fully merged duplicate-location bottom row can look empty and stop the scan early.
- If a fully merged duplicate bottom row appears before later body rows, appending can start too early because the function returns the row before the merged bottom row.

Example:
Input after header:
```text
Row 4: A="Bahce", B="Ali"
Row 5: A="",      B=None
Row 6: A="Koridor", B="Ayse"
```

Output:
`_find_last_block_end` returns `4`, because row `5` is treated as the first empty sentinel. Row `6` is ignored by this scan.

## EXCEL DUPLICATE LOCATION MERGE

Source:
desktop_app/roster_io.py: _apply_duplicate_location_pair_excel_merge
desktop_app/roster_io.py: _apply_duplicate_location_excel_merge_rules
desktop_app/roster_logic.py: is_duplicate_location

Behavior:
Excel duplicate merging is applied to adjacent body rows only.

`_apply_duplicate_location_excel_merge_rules(ws, first_row, last_row)` scans from `first_row` to `last_row - 1`.

For each current `row` and `row + 1`:
- Reads locations from column A and strips them.
- If `is_duplicate_location(top_loc, bottom_loc)` is false, advances by one row.
- If true:
  - Calls `_apply_duplicate_location_pair_excel_merge(ws, row, row + 1)`.
  - Advances by two rows, so merged pairs never overlap.

For a duplicate pair:
- Column A is always merged from top to bottom.
- The top location cell is set to `top_loc or bottom_loc`.
- The bottom location cell is set to `None`.
- For each weekday column B-F:
  - Reads top and bottom names, stripping both.
  - If both are non-empty and `normalize_text(top_name) != normalize_text(bottom_name)`, no merge is made for that teacher column and both values remain visible.
  - Otherwise chooses `top_name or bottom_name or None`.
  - Sets the top cell to the chosen value.
  - Sets the bottom cell to `None`.
  - Merges that column from top to bottom.

Edge Cases:
- Only adjacent pairs are considered.
- Three identical consecutive locations merge as rows `1-2`; row `3` is not merged with row `2` because the scan advances by two.
- If two cells differ only by normalized case/spacing, they are considered the same and merged, with the top stripped spelling kept.
- If both teacher cells are blank, the merged top cell becomes `None`.
- Teacher columns with conflicting non-empty names remain unmerged.
- Location column merges even when teacher columns conflict.

Example:
Input rows:
```text
Row 1: ["Bahce-1", "Ali", "",     "Can", "Deniz", "Ece"]
Row 2: ["bahce 1", "",    "Bora", "CAN", "Derya", ""]
```

Output values after merge:
```text
Row 1: ["Bahce-1", "Ali", "Bora", "Can", "Deniz", "Ece"]
Row 2: [None,      None,  None,   None,  "Derya", None]
```

Merged ranges:
```text
A1:A2, B1:B2, C1:C2, D1:D2, F1:F2
```

Column E is not merged because `"Deniz"` and `"Derya"` are both non-empty and different after normalization.

## EXCEL WEEK BLOCK WRITING

Source:
desktop_app/roster_io.py: append_week_block
desktop_app/roster_io.py: _apply_basic_formatting
desktop_app/roster_io.py: _write_school_line
desktop_app/roster_io.py: _write_principal_line

Behavior:
`append_week_block(...)` writes one week block starting at `start_row`.

If `include_school_row` is true:
- Cleans `school_name` with `normalize_name_text`.
- If non-empty, writes uppercase school name at column A of the current row.
- Merges that row across A-F.
- Makes it bold and centered.
- Advances the row cursor by one.

Then it writes:
- Title row: title in A, merged A-F, bold, centered.
- Header row: A=`"NOBET YERI"`, B-F=`DAY_NAMES`, bold, grey fill.
- Body rows: one row per `locations` entry.
  - Column A gets the location value as provided.
  - `row_vals = roster[idx]` when available; otherwise five empty strings.
  - Each value in `row_vals` is cleaned with `normalize_name_text(str(val or ""))` and written starting at column B.

After body rows:
- If there are at least two locations, duplicate-location Excel merge rules are applied to body rows.
- `_apply_basic_formatting(ws, uniform_font_size)` formats columns A-F for every row up to `ws.max_row`.
- If `include_signature_row` is true, writes principal line at `last_table_row + 1` in column H and returns that signature row.
- If `include_signature_row` is false, returns the last table row.

`_apply_basic_formatting`:
- Sets columns A-F width to `18`.
- Sets row height to `22` for all rows up to max row.
- Uses Calibri and the supplied uniform font size.
- Preserves existing bold state.
- Centers all cells vertically and horizontally.
- Uses wrap text only when the cell value is a string containing `\n`.
- Applies thin black border to A-F.

Edge Cases:
- Blank school name means no school row is written.
- Principal line is written as `"Müdür :"` even when principal name is empty.
- Principal line is in column H, outside the A-F formatted table range.
- Extra roster rows beyond `locations` are ignored.
- Missing roster rows become five blank teacher cells.
- If a roster row has more than five values, values beyond Friday are written into columns after F; duplicate merge and table formatting still only cover A-F.
- If `locations` is empty, title and header are still written, no body rows are written, and signature row is immediately after the header when included.

Example:
Input:
```text
start_row = 1
title = "2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ"
locations = ["Bahce"]
roster = [["Ali", "Ayse", "", "", ""]]
school_name = "Cumhuriyet"
principal_name = "Mehmet"
include_school_row = True
include_signature_row = True
```

Output layout:
```text
Row 1: A-F merged, "CUMHURİYET"
Row 2: A-F merged, title
Row 3: A="NOBET YERI", B="PAZARTESİ", C="SALI", D="ÇARŞAMBA", E="PERŞEMBE", F="CUMA"
Row 4: A="Bahce", B="Ali", C="Ayse", D="", E="", F=""
Row 5: H="Müdür : Mehmet"
```

Return value:
`5`

## EXCEL SINGLE-WEEK SAVE

Source:
desktop_app/roster_io.py: write_week_to_excel
desktop_app/ui.py: App.save_excel_as

Behavior:
`write_week_to_excel(source_path, title, locations, roster, output_path, school_name="", principal_name="")`:
- Opens `source_path` with `load_workbook` when `source_path` is truthy.
- Creates a new `Workbook()` when `source_path` is falsey.
- Uses the active worksheet.
- Computes `last_end = _find_last_block_end(ws)`.
- Uses `start_row = 1` when `last_end == 0`; otherwise `start_row = last_end + 2`.
- Appends a full week block with school row and signature row enabled.
- Saves to `output_path`.
- Closes the workbook in `finally`.

In the UI single-week path:
- `_export_weeks_snapshot()` must return exactly one week.
- `App.save_excel_as` passes `self.workbook_path` directly as `source_path`.
- School/principal values are `week["school_name"]` / `week["principal_name"]`, falling back to app-level `self.school_name` / `self.principal_name` when the week field is empty.

Edge Cases:
- If `source_path` points to an existing workbook, the new block is appended after the last detected block, not written to a new blank sheet.
- If existing duplicate-location merges make `_find_last_block_end` stop early, the new block can be appended too early.
- If `source_path` is stale or missing in the single-week UI path, `load_workbook` can fail.
- Saving can overwrite `output_path` if the chosen path already exists.

Example:
Existing workbook has no title rows.

Input:
`write_week_to_excel(None, title, ["Bahce"], [["Ali","","","",""]], "out.xlsx", "Okul", "Mudur")`

Output:
Writes the week block starting at row `1` in a new workbook and saves `out.xlsx`.

Existing workbook last block ends at row `10`.

Output:
Writes the new block starting at row `12`.

## EXCEL MULTI-WEEK SAVE

Source:
desktop_app/roster_io.py: write_weeks_to_excel
desktop_app/roster_io.py: append_week_block
desktop_app/ui.py: App.save_excel_as

Behavior:
`write_weeks_to_excel(source_path, weeks, output_path)` writes multiple week blocks.

Steps:
- Opens `source_path` when truthy; otherwise creates a new workbook.
- Filters valid weeks with:
  `str((week or {}).get("title", "") or "").strip()`
  so blank or whitespace-only titles are skipped.
- Finds append start row using `_find_last_block_end`.
- Finds `batch_school_name` as the first non-empty `school_name` among valid weeks.
- Finds `batch_principal_name` as the first non-empty `principal_name` among valid weeks.
- If `batch_school_name` exists, writes one school row before all week blocks and advances one row.
- For each valid week:
  - Writes one week block with `include_school_row=False`.
  - Writes no per-week principal signature.
  - Starts the next week block at `previous_block_end + 1`, so there is no blank row between week blocks.
- After all valid weeks, writes one principal line at the current row if at least one valid week exists.
- Saves and closes the workbook.

In the UI multi-week path:
- `_export_weeks_snapshot()` must return at least two weeks.
- `App.save_excel_as` uses `_existing_workbook_source()`, which returns the workbook path only if it still exists.
- The suggested filename is `nobet_{first_start}_{last_end}.xlsx` when both dates exist; otherwise `nobet_ciktisi.xlsx`.

Edge Cases:
- Placeholder weeks with empty titles are skipped entirely.
- Only the first non-empty school name is used for the whole batch.
- Only the first non-empty principal name is used for the whole batch.
- The final principal line is written even if the chosen principal name is empty; it becomes `"Müdür :"`.
- No blank spacer row is inserted between week tables.
- Later week blocks do not have their own school/principal rows.
- Loading a later block from this multi-week output can misread the previous week's last location as the school name because `_parse_school_name_from_title_row` checks the row above the title first.

Example:
Input weeks:
```text
[
  {"title": "T1", "school_name": "Okul A", "principal_name": "", "locations": ["L1"], "roster": [["A","","","",""]]},
  {"title": "",   "school_name": "Skip",   "principal_name": "Skip", "locations": [], "roster": []},
  {"title": "T2", "school_name": "",       "principal_name": "Mudur B", "locations": ["L2"], "roster": [["B","","","",""]]}
]
```

Output:
- Writes one top school row: `"OKUL A"`.
- Writes week `T1`.
- Skips the empty-title placeholder.
- Writes week `T2` immediately after `T1`.
- Writes one final principal line: `"Müdür : Mudur B"`.

## PDF PARAGRAPH AND HEADER/FOOTER TEXT

Source:
desktop_app/pdf_export.py: _register_turkish_font
desktop_app/pdf_export.py: _build_wrapped_paragraph
desktop_app/pdf_export.py: _build_school_line
desktop_app/pdf_export.py: _build_principal_line

Behavior:
`_register_turkish_font()` tries to register the first existing font from this order:
1. bundled `fonts/Calibri.ttf`
2. `C:\Windows\Fonts\calibri.ttf`
3. bundled `fonts/Arial.ttf`
4. `C:\Windows\Fonts\arial.ttf`
5. bundled `fonts/DejaVuSans.ttf`
6. `C:\Windows\Fonts\DejaVuSans.ttf`
7. `C:\Windows\Fonts\tahoma.ttf`

If registration fails for a candidate, it tries the next. If none work, it returns `"Helvetica"`.

`_build_wrapped_paragraph(text, style)`:
- Strips text.
- XML-escapes it.
- Converts newline characters to `<br/>`.
- Uses `&nbsp;` when the stripped text is empty.

`_build_school_line(school_name, font_name, font_size)`:
- Cleans school name with `normalize_name_text`.
- Returns `[]` when empty.
- Otherwise returns an uppercase centered paragraph at `font_size + 1`, then a `1mm` spacer.

`_build_principal_line(principal_name, font_name, font_size)`:
- Always starts with a `1mm` spacer.
- If principal name is non-empty, adds the name as a right-aligned paragraph, then a `0.3mm` spacer.
- Always adds a right-aligned `"Müdür"` role paragraph.

Edge Cases:
- PDF principal output does not use Excel's `"Müdür : name"` format.
- If principal name is empty, PDF still prints `"Müdür"`.
- If school name is empty, no school line or school spacer is returned.
- Blank table cells become non-breaking-space paragraphs, not raw empty strings.
- Font fallback can be Helvetica, which may not support every Turkish glyph.

Example:
Input:
`_build_principal_line("Ayşe Yılmaz", font, 9)`

Output elements:
```text
Spacer(1mm)
right-aligned "Ayşe Yılmaz"
Spacer(0.3mm)
right-aligned "Müdür"
```

Input:
`_build_principal_line("", font, 9)`

Output elements:
```text
Spacer(1mm)
right-aligned "Müdür"
```

## PDF DUPLICATE LOCATION MERGE

Source:
desktop_app/pdf_export.py: _apply_duplicate_location_pdf_merge_rules
desktop_app/roster_logic.py: is_duplicate_location

Behavior:
PDF duplicate merging is applied to adjacent body rows only.

Input `body_rows` is mutated in place. Each body row is expected to be:
`[location, monday, tuesday, wednesday, thursday, friday]`.

The function scans from `top_idx = 0`:
- Compares `body_rows[top_idx][0]` and `body_rows[top_idx + 1][0]` with `is_duplicate_location`.
- If not duplicate, advances by one.
- If duplicate:
  - Adds span `(0, top_idx, bottom_idx)` for the location column.
  - Sets top location to `(top_loc or bottom_loc).strip()`.
  - Sets bottom location to `""`.
  - For columns `1..5`:
    - Strips top and bottom names.
    - If both are non-empty and differ after `normalize_text`, leaves both values visible and adds no span for that column.
    - Otherwise chooses `top_name or bottom_name`.
    - Sets top cell to chosen value.
    - Sets bottom cell to `""`.
    - Adds span `(col, top_idx, bottom_idx)`.
  - Advances by two rows.

It returns the list of spans as `(column, top_body_row_idx, bottom_body_row_idx)`.

Edge Cases:
- Only adjacent pairs are considered.
- Three identical consecutive locations merge as rows `0-1`; row `2` is not merged with row `1`.
- The returned row indexes are body-row indexes, not full table indexes. `_build_week_elements` adds `2` for title and header rows when creating ReportLab spans.
- Conflicting non-empty teacher cells are not merged.
- Empty teacher cells become `""`, not `None`.
- Location column is always spanned for duplicate pairs even when teacher cells conflict.

Example:
Input body rows:
```text
[
  ["Bahce-1", "Ali", "",     "Can", "Deniz", "Ece"],
  ["bahce 1", "",    "Bora", "CAN", "Derya", ""]
]
```

Output mutated body rows:
```text
[
  ["Bahce-1", "Ali", "Bora", "Can", "Deniz", "Ece"],
  ["",        "",    "",     "",    "Derya", ""]
]
```

Returned spans:
```text
[
  (0, 0, 1),
  (1, 0, 1),
  (2, 0, 1),
  (3, 0, 1),
  (5, 0, 1)
]
```

Column `4` is not spanned because `"Deniz"` and `"Derya"` conflict.

## PDF SINGLE-WEEK TABLE BUILD

Source:
desktop_app/pdf_export.py: _build_week_elements
desktop_app/pdf_export.py: export_week_pdf
desktop_app/ui.py: App.export_pdf

Behavior:
`_build_week_elements(...)` builds the PDF flowables for one week.

Table setup:
- Page size is A4.
- Left and right margins are `36pt`.
- Total table width is A4 width minus both margins.
- The table always uses six equal column widths.
- Title row is `[title] + [""] * 5`.
- Header row is `["NOBET YERI"] + DAY_NAMES`.
- One body row is created for each `locations` entry.
- For each location index:
  - Uses `roster[idx]` if present; otherwise five empty strings.
  - Converts location with `str(location)`.
  - Cleans each teacher value with `normalize_name_text`.
- Applies PDF duplicate-location merge rules before converting cells to paragraphs.

Table style:
- Title row spans all columns.
- Grid uses black `0.5` lines.
- Header row background is light grey.
- All cells use the selected font and uniform font size.
- All cells are center-aligned and vertically middle.
- All paddings are `0.2mm`.
- Duplicate spans are applied after adding two rows of offset for title/header.

`export_week_pdf(path, ...)`:
- Registers a font.
- Creates a `SimpleDocTemplate` with A4 and `36pt` margins.
- Builds one week with school and principal lines included.

In the UI single-week path:
- `_export_weeks_snapshot()` must return exactly one week.
- Suggested filename is `nobet_ciktisi.pdf`.
- School/principal values fall back to app-level values if missing in the week.

Edge Cases:
- If `locations` is empty, the table contains only title and header rows.
- Extra roster rows beyond locations are ignored.
- Missing roster rows become five blank teacher cells.
- If a roster row has fewer than five values, the resulting body row can have fewer than six cells.
- If a roster row has more than five values, the resulting body row can have more than six cells even though column widths are defined for six columns.
- Duplicate-location merge mutates only the local `body_rows`, not the caller's roster.

Example:
Input:
```text
title = "2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ"
locations = ["Bahce"]
roster = [["Ali", "Ayse", "", "", ""]]
school_name = "Okul"
principal_name = "Mudur"
```

Output PDF structure:
```text
school line "OKUL"
table:
  row 0: title spanning all six columns
  row 1: NOBET YERI, PAZARTESİ, SALI, ÇARŞAMBA, PERŞEMBE, CUMA
  row 2: Bahce, Ali, Ayse, blank, blank, blank
principal area:
  "Mudur"
  "Müdür"
```

## PDF MULTI-WEEK EXPORT

Source:
desktop_app/pdf_export.py: _week_row_count
desktop_app/pdf_export.py: _first_non_empty_field
desktop_app/pdf_export.py: _compute_multiweek_page_layout
desktop_app/pdf_export.py: export_weeks_pdf
desktop_app/ui.py: App.export_pdf

Behavior:
`export_weeks_pdf(path, weeks)` writes multiple week tables.

Filtering:
- Uses `valid_weeks = [w for w in weeks if (w or {}).get("title")]`.
- A whitespace-only title is truthy and therefore valid in PDF export.

Pagination:
- Processes valid weeks in groups of four.
- Each group becomes one PDF page.
- Adds a `PageBreak` between groups when more valid weeks remain.

Per page:
- `page_school_name` is the first non-empty cleaned `school_name` in that four-week group.
- `page_principal_name` is the first non-empty cleaned `principal_name` in that four-week group.
- School line is included only when `page_school_name` is non-empty.
- Principal line is always included for every page group, even when principal name is empty.
- Each week table is built without its own school or principal line.
- A `3pt` spacer is inserted between week tables on the same page.

Layout calculation:
- `_week_row_count(week)` returns `2 + max(1, len(locations))`.
- Available height is A4 height minus top/bottom margins.
- `total_rows` is the sum of week row counts plus one for page school when included plus one for page principal.
- `max_row_height = int((available_height - 3pt * (week_count - 1)) / max(1, total_rows))`.
- `row_height = max(8, min(22, max_row_height))`.
- `font_size = max(5, min(9, row_height - 3))`.

In the UI multi-week path:
- `_export_weeks_snapshot()` must return at least two weeks.
- Suggested filename is `nobet_{first_start}_{last_end}.pdf` when both dates exist; otherwise `nobet_ciktisi.pdf`.

Edge Cases:
- PDF multi-week filtering differs from Excel multi-week filtering: PDF accepts whitespace-only titles; Excel strips and skips them.
- `_week_row_count` counts one body row even when `locations` is empty, but `_build_week_elements` actually builds no body rows for an empty locations list.
- Layout shrinks rows and fonts to fit up to four weekly tables on one page, but row height never goes below `8` and font size never below `5`.
- Principal role `"Müdür"` prints once per page group even if every week has empty principal name.
- School/principal values are chosen per page group, not globally for the whole file.

Example:
Input valid weeks count:
`5`

Output:
```text
Page 1: weeks 1, 2, 3, 4; one optional school line; one principal area.
Page 2: week 5; one optional school line; one principal area.
```

Input page weeks:
```text
[
  {"title": "T1", "school_name": "", "principal_name": ""},
  {"title": "T2", "school_name": "Okul B", "principal_name": "Mudur B"}
]
```

Output page-level fields:
```text
school line: "OKUL B"
principal area: "Mudur B" then "Müdür"
```

## UI EDIT WINDOW DATA RULES

Source:
desktop_app/ui.py: EditWindow.__init__
desktop_app/ui.py: EditWindow._save
desktop_app/ui.py: App.edit_week

Behavior:
The edit window owns temporary copies of `locations` and `roster`.

Date defaults in the edit window:
- Parses incoming start and end strings through `_parse_ui_date`.
- If start exists and end is missing, end becomes start + 4 days.
- If end exists and start is missing, start becomes end - 4 days.
- If start is still missing, start becomes today.
- If end is still missing, end becomes start + 4 days.

Save behavior:
- Iterates visible grid rows.
- Strips location and all five teacher values.
- Skips a row only when location is empty and all teacher values are empty.
- If any teacher value exists but location is empty, shows validation error and does not save.
- Keeps rows with a location even if all teacher values are empty.
- Passes ISO start/end dates from DatePicker, stripped school/principal, locations, and roster to the app callback.

App save callback:
- Parses start/end with `parse_date_input` using app year.
- If a date value is empty, falls back to the existing current date.
- Rejects start > end.
- Stores school/principal exactly as passed from the edit window.
- Copies locations and roster.
- If both dates exist, rebuilds title with `build_title`.
- Clears `month_generated`.
- Refreshes preview and persists state.

Edge Cases:
- DatePicker is read-only and returns ISO strings, but callback still accepts parser-supported date formats.
- Empty rows disappear on save.
- A location-only row is valid.
- A teacher-only row is invalid.
- Roster rows from the edit grid always have five teacher values.
- Saving while a separate generated preview exists clears that preview.

Example:
Input grid rows:
```text
["Bahce", "Ali", "", "", "", ""]
["",      "",    "", "", "", ""]
["",      "Ayse","", "", "", ""]
```

Output:
- First row is saved.
- Second row is skipped.
- Third row causes validation error `"Dolu bir satırda görev yeri boş olamaz."` and nothing is saved.

## UI CURRENT WEEK SETTING

Source:
desktop_app/ui.py: App._set_current_week
desktop_app/ui.py: App.apply_input_dates

Behavior:
`App._set_current_week(start_date, end_date, roster_data=None)` is the central setter for moving the current week.

It:
- Uses a copy of current roster when `roster_data is None`.
- Sets `self.current_start = start_date`.
- Sets `self.current_end = end_date`.
- Sets `self.current_title = build_title(start_date, end_date)`.
- Copies `roster_data` into `self.roster`.
- Sets `self.last_generated` to a week snapshot containing current title, dates, school, principal, locations, and roster.
- Clears `self.month_generated`.
- Updates labels, refreshes preview, and persists state.

`App.apply_input_dates(start_val, end_val)`:
- Requires roster data.
- Parses and validates the date range.
- Calls `_set_current_week(start_date, end_date, self.roster)`.

Edge Cases:
- `_set_current_week` does not alter `self.locations`, `self.school_name`, or `self.principal_name`.
- Any existing multi-week preview is cleared.
- The current title is rebuilt even if the range is not exactly five days.
- `apply_input_dates` can set a date range wider than one week; preview generation may then auto-build multiple weeks.

Example:
Current:
```text
locations = ["Bahce"]
roster = [["Ali", "", "", "", ""]]
```

Input:
`_set_current_week(date(2026, 2, 9), date(2026, 2, 13), [["Ayse", "", "", "", ""]])`

Output state:
```text
current_title = "9 ŞUBAT-13 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ"
roster = [["Ayse", "", "", "", ""]]
month_generated = []
last_generated["start_date"] = "2026-02-09"
last_generated["end_date"] = "2026-02-13"
```

## UI PREVIOUS AND NEXT WEEK GENERATION

Source:
desktop_app/ui.py: App.generate_previous
desktop_app/ui.py: App.generate_next
desktop_app/ui.py: App.generate_next_in_range
desktop_app/roster_logic.py: rotate_roster
desktop_app/roster_logic.py: rotate_roster_back
desktop_app/roster_logic.py: build_next_week

Behavior:
`App.generate_previous()`:
- Requires current dates and roster data.
- Computes `prev_roster = rotate_roster_back(self.roster)`.
- Computes `prev_start = self.current_start - 7 days`.
- Computes `prev_end = self.current_end - 7 days`.
- Calls `_set_current_week(prev_start, prev_end, prev_roster)`.

`App.generate_next()`:
- Requires current dates and roster data.
- Calls `build_next_week` with current dates, locations, roster, school, principal.
- Parses returned ISO start/end dates.
- Calls `_set_current_week(next_start, next_end, next_week["roster"])`.

`App.generate_next_in_range(start_val, end_val)`:
- Requires current dates and roster data.
- Parses the allowed date range.
- Builds the next week exactly like `generate_next`.
- If `next_start < range_start` or `next_end > range_end`, shows warning and does not update state.
- Otherwise sets current week to the next week.

Edge Cases:
- Previous/next always move by seven calendar days.
- Previous uses backward rotation, not forward rotation.
- Next uses forward rotation through `build_next_week`.
- Date range length is preserved for previous/next because both endpoints move by seven days.
- `generate_next_in_range` checks only the generated next week against the input range; it does not require the current week itself to be inside that range.
- All existing multi-week previews are cleared by `_set_current_week`.

Example:
Current:
```text
current_start = 2026-02-02
current_end = 2026-02-06
roster = [
  ["A", "", "", "", ""],
  ["B", "", "", "", ""]
]
```

After `generate_next()`:
```text
current_start = 2026-02-09
current_end = 2026-02-13
roster = [
  ["B", "", "", "", ""],
  ["A", "", "", "", ""]
]
```

After `generate_previous()` from that state:
```text
current_start = 2026-02-02
current_end = 2026-02-06
roster = [
  ["A", "", "", "", ""],
  ["B", "", "", "", ""]
]
```

## UI OUTPUT RANGE WEEK GENERATION

Source:
desktop_app/ui.py: App._build_weeks_for_output_range
desktop_app/ui.py: App.generate_range_outputs
desktop_app/ui.py: App._refresh_preview
desktop_app/roster_logic.py: WEEK_SPAN_DAYS
desktop_app/roster_logic.py: build_week
desktop_app/roster_logic.py: build_next_week

Behavior:
`App._build_weeks_for_output_range(range_start, range_end)` builds complete five-day week windows for a date range.

Steps:
- Creates the first week with:
  - start = `range_start`
  - end = `range_start + WEEK_SPAN_DAYS`
  - `WEEK_SPAN_DAYS` is `4`
  - current locations, roster, school, principal
- Loops:
  - Parses current `week["end_date"]`.
  - If `week_end > range_end`, stops.
  - Appends a copy of the week.
  - Builds the next week from the current week using `build_next_week`, which moves dates +7 days and rotates roster forward.
- Returns only the generated real weeks. No blank placeholders are added.

`App.generate_range_outputs()`:
- Refuses to run while the edit window is open.
- Requires current dates and roster data.
- Uses current start/end as the range.
- Rejects current start > current end.
- Calls `_build_weeks_for_output_range`.
- If no weeks are generated, warns that at least five days are needed.
- Stores the result in `month_generated` through `_apply_preview_weeks`.
- Does not export a file automatically.

`App._refresh_preview()`:
- If `month_generated` has valid titled weeks, previews those.
- Otherwise, if current dates, locations, and roster exist, it calls `_build_weeks_for_output_range(current_start, current_end)`.
- If that returns weeks, it previews those generated weeks.
- If not, it falls back to a single current-week preview.

Edge Cases:
- Range generation always uses a five-day span from range start to range start + 4 days, regardless of current `current_end`.
- The range start does not need to be Monday.
- A range shorter than five calendar days produces no weeks.
- A week is included only when its computed end date is `<= range_end`.
- Roster rotation accumulates week by week.
- Generated previews are stored in `month_generated`; later export uses `month_generated`.

Example:
Input:
```text
range_start = 2026-02-02
range_end = 2026-02-20
locations = ["L1", "L2"]
roster = [
  ["A", "", "", "", ""],
  ["B", "", "", "", ""]
]
```

Output weeks:
```text
Week 1: 2026-02-02 to 2026-02-06, Monday A/B
Week 2: 2026-02-09 to 2026-02-13, Monday B/A
Week 3: 2026-02-16 to 2026-02-20, Monday A/B
```

Input:
```text
range_start = 2026-02-02
range_end = 2026-02-05
```

Output:
`[]`

## UI MONTH PREVIEW GENERATION

Source:
desktop_app/ui.py: App.generate_month
desktop_app/ui.py: App._build_month_in_range
desktop_app/ui.py: App.generate_month_in_range
desktop_app/roster_logic.py: WEEK_SPAN_DAYS
desktop_app/roster_logic.py: build_week
desktop_app/roster_logic.py: build_next_week

Behavior:
`App.generate_month()`:
- Requires current dates and roster data.
- Builds exactly four real week dictionaries.
- First week starts at `self.current_start`.
- First week ends at `self.current_start + WEEK_SPAN_DAYS`, not necessarily `self.current_end`.
- Each next week is created with `build_next_week`, so dates move +7 days and roster rotates forward.
- Stores all four weeks in `month_generated`.
- Does not export automatically.

`App._build_month_in_range(start_date, end_date, table_count=4)`:
- If `table_count <= 0`, returns `[]`.
- Computes `span_days`:
  - If current start/end exist, `max(0, (current_end - current_start).days)`.
  - Otherwise `4`.
- First generated week starts at `start_date` and ends at `start_date + span_days`.
- Adds weeks while both:
  - generated count is less than `table_count`
  - current week end is `<= end_date`
- Each next week is created with `build_next_week`.
- After real weeks stop, appends blank placeholder dictionaries until length equals `table_count`.

Blank placeholder shape:
```text
{
  "title": "",
  "start_date": "",
  "end_date": "",
  "school_name": "",
  "principal_name": "",
  "locations": [],
  "roster": []
}
```

`App.generate_month_in_range(start_val, end_val)`:
- Requires roster data, but does not require current dates.
- Parses the input range.
- Calls `_build_month_in_range(..., table_count=4)`.
- If no real titled weeks exist, warns and does not apply preview.
- Otherwise stores the four-entry result, including blank placeholders.

Edge Cases:
- `generate_month()` ignores `self.current_end` for the first generated end date and always uses start + 4 days.
- `_build_month_in_range()` uses the current range length when current dates exist; this can be different from five days.
- `_build_month_in_range()` pads blanks to exactly four entries.
- Blank placeholders are shown in `month_generated` but are filtered out by export snapshot and Excel multi-week writing.
- Roster rotation only happens between real weeks built before padding.

Example:
Current:
```text
current_start = 2026-02-02
current_end = 2026-02-06
roster Monday column = ["A", "B"]
```

After `generate_month()`:
```text
Week 1: 2026-02-02 to 2026-02-06, Monday ["A", "B"]
Week 2: 2026-02-09 to 2026-02-13, Monday ["B", "A"]
Week 3: 2026-02-16 to 2026-02-20, Monday ["A", "B"]
Week 4: 2026-02-23 to 2026-02-27, Monday ["B", "A"]
```

Input to `_build_month_in_range`:
```text
start_date = 2026-02-02
end_date = 2026-02-10
table_count = 4
current span_days = 4
```

Output:
```text
Week 1: 2026-02-02 to 2026-02-06
Placeholder 2
Placeholder 3
Placeholder 4
```

The week `2026-02-09` to `2026-02-13` is not included because its end is after `2026-02-10`.

## UI EXPORT SNAPSHOT SELECTION

Source:
desktop_app/ui.py: App._export_weeks_snapshot
desktop_app/ui.py: App._preview_weeks_for_export
desktop_app/ui.py: App.export_pdf
desktop_app/ui.py: App.save_excel_as

Behavior:
`App._export_weeks_snapshot()` decides what data is exported.

Steps:
- Copies `self.month_generated`.
- Keeps only copied weeks whose `title` is non-empty after `.strip()`.
- If any such weeks exist, returns them.
- Otherwise, if `self.current_title` exists and either `self.locations` or `self.roster` exists, returns a single current-week dictionary.
- Otherwise returns `[]`.

`App._preview_weeks_for_export()` simply returns `_export_weeks_snapshot()`.

`App.export_pdf()`:
- If snapshot has at least two weeks, calls `export_weeks_pdf`.
- If snapshot has exactly one week, calls `export_week_pdf`.
- If snapshot is empty, warns the user.

`App.save_excel_as()`:
- If snapshot has at least two weeks, calls `write_weeks_to_excel`.
- If snapshot has exactly one week, calls `write_week_to_excel`.
- If snapshot is empty, warns the user.

Edge Cases:
- `month_generated` takes priority over current week.
- Blank month placeholders are removed before export.
- Preview table edits modify `self.preview_weeks`, but `_export_weeks_snapshot()` reads `self.month_generated` or current state, not `self.preview_weeks`. Therefore preview-grid edits are not exported by this function unless another path copies them back first.
- PDF multi-week export and Excel multi-week export apply different title filtering after snapshot selection: snapshot strips titles, PDF exporter itself does not strip if called directly.

Example:
State:
```text
month_generated = [
  {"title": "T1", "locations": ["L1"], "roster": [["A","","","",""]]},
  {"title": "", "locations": [], "roster": []}
]
current_title = "Current"
```

Output from `_export_weeks_snapshot()`:
```text
[
  {"title": "T1", "locations": ["L1"], "roster": [["A","","","",""]]}
]
```

The current week is ignored because at least one valid generated week exists.

## UI EXCEL LOAD DATA FLOW

Source:
desktop_app/ui.py: App.load_excel
desktop_app/roster_io.py: load_last_week

Behavior:
`App.load_excel()`:
- Opens a file picker for `.xlsx`.
- If user cancels, returns with no state change.
- Ensures app year exists.
- Calls `load_last_week(path, year)`.
- On error, shows a Turkish error message and returns with no state change.
- On success:
  - `self.workbook_path = path`
  - `self.current_title = data["title"]`
  - `self.current_start = data["start_date"]`
  - `self.current_end = data["end_date"]`
  - `self.school_name = data.get("school_name", "")`
  - `self.principal_name = data.get("principal_name", "")`
  - `self.locations` becomes a list copy of loaded locations when list/tuple, else `[]`
  - `self.roster` becomes copied loaded roster rows
  - `self.month_generated = []`
  - Refreshes labels/preview and persists state

Edge Cases:
- Loaded `start_date` and `end_date` are `date` objects from `roster_io`, not strings.
- Only the workbook's active sheet is read.
- Only the last detected week block is loaded.
- Any existing generated preview is discarded.
- Existing `last_generated` is not explicitly updated by `load_excel`.

Example:
Loaded data:
```text
{
  "title": "2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ ÖĞRETMEN LİSTESİ",
  "start_date": date(2026, 2, 2),
  "end_date": date(2026, 2, 6),
  "locations": ["Bahce"],
  "roster": [["Ali", "", "", "", ""]]
}
```

App state after load:
```text
current_title = loaded title
current_start = date(2026, 2, 2)
current_end = date(2026, 2, 6)
locations = ["Bahce"]
roster = [["Ali", "", "", "", ""]]
month_generated = []
```
