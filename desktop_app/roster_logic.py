# -*- coding: utf-8 -*-
from __future__ import annotations

import re
from datetime import date, timedelta
from typing import List, Optional, Tuple

DAY_NAMES = ["PAZARTES\u0130", "SALI", "\u00c7AR\u015eAMBA", "PER\u015eEMBE", "CUMA"]
TITLE_SUFFIX = "HAFTASI N\u00d6BET\u00c7\u0130 \u00d6\u011eRETMEN L\u0130STES\u0130"
WEEK_SPAN_DAYS = 4
WEEK_STEP_DAYS = 7

TURKISH_MONTHS = {
    "OCAK": 1,
    "\u015eUBAT": 2,
    "MART": 3,
    "N\u0130SAN": 4,
    "MAYIS": 5,
    "HAZ\u0130RAN": 6,
    "TEMMUZ": 7,
    "A\u011eUSTOS": 8,
    "EYL\u00dcL": 9,
    "EK\u0130M": 10,
    "KASIM": 11,
    "ARALIK": 12,
}

MONTHS_BY_NUM = {v: k for k, v in TURKISH_MONTHS.items()}


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip().upper()


def normalize_name_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip()


def duplicate_location_key(value: str) -> str:
    text = normalize_text(value or "")
    if not text:
        return ""
    return re.sub(r"[\s-]+", "", text)


def is_duplicate_location(top: str, bottom: str) -> bool:
    top_key = duplicate_location_key(top)
    return bool(top_key and top_key == duplicate_location_key(bottom))


def _estimate_text_width_units(text: str) -> float:
    """
    Rough width model (in font-size-relative units) for conservative fit checks.
    """
    total = 0.0
    for ch in text:
        if ch == " ":
            total += 0.33
        elif ch in ".,;:!|":
            total += 0.28
        elif ch in "ilI1":
            total += 0.35
        elif ch in "MWwm@%":
            total += 0.9
        else:
            total += 0.62
    return total


def compute_uniform_font_size(
    roster: List[List[str]],
    max_font_size: int = 11,
    min_font_size: int = 3,
    cell_width_pt: float = 87.2,
    cell_padding_pt: float = 1.417,
) -> int:
    """
    Compute one shared font size so full teacher names fit fixed-width cells.
    """
    names: List[str] = []
    for row in roster:
        for cell in row[:5]:
            name = normalize_name_text(str(cell or ""))
            if name:
                names.append(name)

    if not names:
        return max_font_size

    usable_width = max(cell_width_pt - (cell_padding_pt * 2), 1.0)
    for size in range(max_font_size, min_font_size - 1, -1):
        if all((_estimate_text_width_units(name) * size) <= usable_width for name in names):
            return size
    return min_font_size


def parse_title(title: str, default_year: int) -> Tuple[date, date, str]:
    """
    Parse a title like "2 \u015eUBAT-6 \u015eUBAT HAFTASI N\u00d6BET\u00c7\u0130 \u00d6\u011eRETMEN L\u0130STES\u0130".
    Returns (start_date, end_date, suffix).
    """
    if not title:
        raise ValueError("Ba\u015fl\u0131k bo\u015f.")

    norm = normalize_text(title)
    if normalize_text(TITLE_SUFFIX) not in norm:
        raise ValueError("Ba\u015fl\u0131k beklenen ifadeyi i\u00e7ermiyor.")

    m = re.search(
        r"(\d{1,2})\s+([A-Z\u00c7\u011e\u0130\u00d6\u015e\u00dc]+)\s*-\s*(\d{1,2})\s+([A-Z\u00c7\u011e\u0130\u00d6\u015e\u00dc]+)",
        norm,
    )
    if not m:
        raise ValueError("Ba\u015fl\u0131ktan tarih aral\u0131\u011f\u0131 okunamad\u0131.")

    d1, m1_name, d2, m2_name = m.groups()
    m1 = TURKISH_MONTHS.get(m1_name)
    m2 = TURKISH_MONTHS.get(m2_name)
    if not m1 or not m2:
        raise ValueError("Ba\u015fl\u0131kta bilinmeyen T\u00fcrk\u00e7e ay ad\u0131 var.")

    year_match = re.search(r"\b(20\d{2})\b", norm)
    year = int(year_match.group(1)) if year_match else int(default_year)

    start = date(year, m1, int(d1))
    end = date(year, m2, int(d2))
    return start, end, TITLE_SUFFIX


def build_title(start: date, end: date) -> str:
    m1 = MONTHS_BY_NUM[start.month]
    m2 = MONTHS_BY_NUM[end.month]
    return f"{start.day} {m1}-{end.day} {m2} {TITLE_SUFFIX}"


def build_week(
    start: date,
    end: date,
    locations: List[str],
    roster: List[List[str]],
    school_name: str = "",
    principal_name: str = "",
) -> dict:
    return {
        "title": build_title(start, end),
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "school_name": school_name,
        "principal_name": principal_name,
        "locations": list(locations or []),
        "roster": [list(row) if isinstance(row, (list, tuple)) else [] for row in (roster or [])],
    }


def next_week_dates(start: date, end: date) -> Tuple[date, date]:
    return start + timedelta(days=WEEK_STEP_DAYS), end + timedelta(days=WEEK_STEP_DAYS)


def rotate_roster(roster: List[List[str]]) -> List[List[str]]:
    """
    Rotate teacher names per day column, preserving empty slots.
    roster: list of rows, each row is a list of 5 day values.
    """
    if not roster:
        return []

    rows = len(roster)
    cols = 5
    new_roster = [row[:] for row in roster]

    for c in range(cols):
        indices = [r for r in range(rows) if (roster[r][c] or "").strip()]
        names = [roster[r][c] for r in indices]
        if not names:
            continue
        rotated = names[1:] + names[:1]
        for r, name in zip(indices, rotated):
            new_roster[r][c] = name

    return new_roster


def build_next_week(
    current_start: date,
    current_end: date,
    locations: List[str],
    roster: List[List[str]],
    school_name: str = "",
    principal_name: str = "",
) -> dict:
    next_start, next_end = next_week_dates(current_start, current_end)
    return build_week(
        next_start,
        next_end,
        locations,
        rotate_roster(roster),
        school_name,
        principal_name,
    )


def rotate_roster_back(roster: List[List[str]]) -> List[List[str]]:
    """
    Inverse of rotate_roster: move each day-column roster one step back.
    """
    if not roster:
        return []

    rows = len(roster)
    cols = 5
    new_roster = [row[:] for row in roster]

    for c in range(cols):
        indices = [r for r in range(rows) if (roster[r][c] or "").strip()]
        names = [roster[r][c] for r in indices]
        if not names:
            continue
        rotated = names[-1:] + names[:-1]
        for r, name in zip(indices, rotated):
            new_roster[r][c] = name

    return new_roster


def parse_date_input(value: str, default_year: int) -> Optional[date]:
    """
    Accepts YYYY-MM-DD or DD.MM or DD.MM.YYYY.
    """
    if not value:
        return None
    value = value.strip()
    if re.match(r"^\d{4}-\d{2}-\d{2}$", value):
        y, m, d = [int(x) for x in value.split("-")]
        return date(y, m, d)
    m = re.match(r"^(\d{1,2})\.(\d{1,2})(?:\.(\d{4}))?$", value)
    if m:
        d, mo, y = m.groups()
        y = int(y) if y else int(default_year)
        return date(y, int(mo), int(d))
    raise ValueError("Ge\u00e7ersiz tarih bi\u00e7imi.")

