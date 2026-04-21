# -*- coding: utf-8 -*-
from __future__ import annotations

from typing import List
import os
from pathlib import Path
import re
import sys
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from roster_logic import DAY_NAMES, is_duplicate_location, normalize_name_text, normalize_text

BASE_FONT_SIZE = 9
UNIFORM_ROW_HEIGHT = 22
CELL_PADDING_PT = 0.2 * mm
PAGE_MARGIN_PT = 36
WEEK_TABLE_COLUMN_COUNT = 6
MULTI_WEEK_SPACING_PT = 3.0


def _resource_path(relative_path: str) -> Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / relative_path
    return Path(__file__).resolve().parent / relative_path


def _register_turkish_font() -> str:
    """
    Try to register a Unicode-capable font for Turkish characters.
    Returns the font name to use.
    """
    candidates = [
        ("Calibri", str(_resource_path("fonts/Calibri.ttf"))),
        ("Calibri", r"C:\Windows\Fonts\calibri.ttf"),
        ("Arial", str(_resource_path("fonts/Arial.ttf"))),
        ("Arial", r"C:\Windows\Fonts\arial.ttf"),
        ("DejaVuSans", str(_resource_path("fonts/DejaVuSans.ttf"))),
        ("DejaVuSans", r"C:\Windows\Fonts\DejaVuSans.ttf"),
        ("Tahoma", r"C:\Windows\Fonts\tahoma.ttf"),
    ]
    for font_name, path in candidates:
        if os.path.exists(path):
            try:
                pdfmetrics.registerFont(TTFont(font_name, path))
                return font_name
            except Exception:
                continue
    return "Helvetica"


def _build_wrapped_paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    clean = escape((text or "").strip()).replace("\n", "<br/>")
    if not clean:
        clean = "&nbsp;"
    return Paragraph(clean, style)


def _build_school_line(school_name: str, font_name: str, font_size: int) -> List:
    clean_school = normalize_name_text(school_name)
    if not clean_school:
        return []

    school_style = ParagraphStyle(
        "school_line",
        fontName=font_name,
        fontSize=font_size + 1,
        leading=font_size + 2,
        alignment=TA_CENTER,
    )
    return [
        _build_wrapped_paragraph(clean_school.upper(), school_style),
        Spacer(1, 1.0 * mm),
    ]


def _build_principal_line(principal_name: str, font_name: str, font_size: int) -> List:
    principal_name_style = ParagraphStyle(
        "principal_name_line",
        fontName=font_name,
        fontSize=font_size,
        leading=font_size + 1,
        alignment=TA_RIGHT,
    )
    principal_role_style = ParagraphStyle(
        "principal_role_line",
        fontName=font_name,
        fontSize=max(6, font_size - 1),
        leading=font_size + 1,
        alignment=TA_RIGHT,
    )
    principal_clean = normalize_name_text(principal_name)
    elements: List = [Spacer(1, 1.0 * mm)]
    if principal_clean:
        elements.append(_build_wrapped_paragraph(principal_clean, principal_name_style))
        elements.append(Spacer(1, 0.3 * mm))
    elements.append(_build_wrapped_paragraph("Müdür", principal_role_style))
    return elements


def _apply_duplicate_location_pdf_merge_rules(body_rows: List[List[str]]) -> List[tuple[int, int, int]]:
    """
    Apply duplicate location merge rules on adjacent body rows.
    Returns a list of (column, top_body_row_idx, bottom_body_row_idx) spans
    for body rows (without title/header offset).
    """
    if len(body_rows) < 2:
        return []

    spans: List[tuple[int, int, int]] = []
    top_idx = 0
    while top_idx < len(body_rows) - 1:
        bottom_idx = top_idx + 1
        top_loc = body_rows[top_idx][0] if body_rows[top_idx] else ""
        bottom_loc = body_rows[bottom_idx][0] if body_rows[bottom_idx] else ""
        if not is_duplicate_location(top_loc, bottom_loc):
            top_idx += 1
            continue

        spans.append((0, top_idx, bottom_idx))
        body_rows[top_idx][0] = (top_loc or bottom_loc).strip()
        body_rows[bottom_idx][0] = ""

        # Table columns: 0=location, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday
        for col in range(1, 6):
            top_name = (body_rows[top_idx][col] or "").strip()
            bottom_name = (body_rows[bottom_idx][col] or "").strip()
            if top_name and bottom_name and normalize_text(top_name) != normalize_text(bottom_name):
                # Keep both rows visible when both are filled.
                continue
            chosen = top_name or bottom_name
            body_rows[top_idx][col] = chosen
            body_rows[bottom_idx][col] = ""
            spans.append((col, top_idx, bottom_idx))
        top_idx += 2

    return spans


def _week_row_count(week: dict) -> int:
    locations = list((week or {}).get("locations", []) or [])
    return 2 + max(1, len(locations))


def _first_non_empty_field(weeks: List[dict], field_name: str) -> str:
    for week in weeks:
        value = normalize_name_text(str((week or {}).get(field_name, "") or ""))
        if value:
            return value
    return ""


def _compute_multiweek_page_layout(
    weeks_on_page: List[dict],
    *,
    include_page_school: bool,
    include_page_principal: bool,
) -> tuple[int, int, float]:
    if not weeks_on_page:
        return BASE_FONT_SIZE, UNIFORM_ROW_HEIGHT, 0.0

    # Keep up to 4 weekly tables on one page by shrinking row height/font when needed.
    spacing_pt = MULTI_WEEK_SPACING_PT
    available_height = A4[1] - PAGE_MARGIN_PT - PAGE_MARGIN_PT
    total_rows = sum(_week_row_count(w) for w in weeks_on_page)
    if include_page_school:
        total_rows += 1
    if include_page_principal:
        total_rows += 1

    max_row_height = int((available_height - spacing_pt * (len(weeks_on_page) - 1)) / max(1, total_rows))
    row_height = max(8, min(UNIFORM_ROW_HEIGHT, max_row_height))
    font_size = max(5, min(BASE_FONT_SIZE, row_height - 3))
    return font_size, row_height, spacing_pt


def _build_week_elements(
    title: str,
    locations: List[str],
    roster: List[List[str]],
    font_name: str,
    *,
    school_name: str = "",
    principal_name: str = "",
    font_size: int = BASE_FONT_SIZE,
    row_height: int = UNIFORM_ROW_HEIGHT,
    include_school_line: bool = True,
    include_principal_line: bool = True,
):
    elements = []

    table_total_width = A4[0] - PAGE_MARGIN_PT - PAGE_MARGIN_PT
    equal_col_width = table_total_width / WEEK_TABLE_COLUMN_COUNT
    col_widths = [equal_col_width] * WEEK_TABLE_COLUMN_COUNT

    uniform_font_size = font_size

    if include_school_line:
        elements.extend(_build_school_line(school_name, font_name, uniform_font_size))

    title_row = [title] + [""] * 5
    header_row = ["NOBET YERI"] + DAY_NAMES
    body_rows: List[List[str]] = []
    for idx, location in enumerate(locations):
        row_vals = roster[idx] if idx < len(roster) else ["", "", "", "", ""]
        row = [str(location)]
        row.extend(normalize_name_text("" if value is None else str(value)) for value in row_vals)
        body_rows.append(row)

    duplicate_location_spans = _apply_duplicate_location_pdf_merge_rules(body_rows)

    paragraph_style = ParagraphStyle(
        "schedule_cell",
        fontName=font_name,
        fontSize=uniform_font_size,
        leading=uniform_font_size + 1,
        alignment=TA_CENTER,
        wordWrap="CJK",
    )

    raw_data: List[List[str]] = [title_row, header_row] + body_rows
    data: List[List[Paragraph]] = [
        [_build_wrapped_paragraph(str(value), paragraph_style) for value in row]
        for row in raw_data
    ]

    row_heights = [row_height] * len(data)
    table = Table(data, repeatRows=2, colWidths=col_widths, rowHeights=row_heights)
    style_cmds = [
        ("SPAN", (0, 0), (-1, 0)),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
        ("BACKGROUND", (0, 1), (-1, 1), colors.lightgrey),
        ("FONTNAME", (0, 0), (-1, -1), font_name),
        ("FONTSIZE", (0, 0), (-1, -1), uniform_font_size),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("LEFTPADDING", (0, 0), (-1, -1), CELL_PADDING_PT),
        ("RIGHTPADDING", (0, 0), (-1, -1), CELL_PADDING_PT),
        ("TOPPADDING", (0, 0), (-1, -1), CELL_PADDING_PT),
        ("BOTTOMPADDING", (0, 0), (-1, -1), CELL_PADDING_PT),
    ]
    for col, top_body_idx, bottom_body_idx in duplicate_location_spans:
        style_cmds.append(("SPAN", (col, top_body_idx + 2), (col, bottom_body_idx + 2)))

    table.setStyle(TableStyle(style_cmds))
    elements.append(table)

    if include_principal_line:
        elements.extend(_build_principal_line(principal_name, font_name, uniform_font_size))

    return elements


def export_week_pdf(
    path: str,
    title: str,
    locations: List[str],
    roster: List[List[str]],
    school_name: str = "",
    principal_name: str = "",
):
    font_name = _register_turkish_font()
    doc = SimpleDocTemplate(
        path,
        pagesize=A4,
        leftMargin=PAGE_MARGIN_PT,
        rightMargin=PAGE_MARGIN_PT,
        topMargin=PAGE_MARGIN_PT,
        bottomMargin=PAGE_MARGIN_PT,
    )

    elements = _build_week_elements(
        title,
        locations,
        roster,
        font_name,
        school_name=school_name,
        principal_name=principal_name,
    )
    doc.build(elements)


def export_weeks_pdf(
    path: str,
    weeks: List[dict],
):
    font_name = _register_turkish_font()
    doc = SimpleDocTemplate(
        path,
        pagesize=A4,
        leftMargin=PAGE_MARGIN_PT,
        rightMargin=PAGE_MARGIN_PT,
        topMargin=PAGE_MARGIN_PT,
        bottomMargin=PAGE_MARGIN_PT,
    )

    valid_weeks = [w for w in weeks if (w or {}).get("title")]

    elements = []
    for page_start in range(0, len(valid_weeks), 4):
        page_weeks = valid_weeks[page_start : page_start + 4]
        page_school_name = _first_non_empty_field(page_weeks, "school_name")
        page_principal_name = _first_non_empty_field(page_weeks, "principal_name")

        include_page_school = bool(page_school_name)
        include_page_principal = True

        font_size, row_height, spacing_pt = _compute_multiweek_page_layout(
            page_weeks,
            include_page_school=include_page_school,
            include_page_principal=include_page_principal,
        )

        if include_page_school:
            elements.extend(_build_school_line(page_school_name, font_name, font_size))

        for i, week in enumerate(page_weeks):
            elements.extend(
                _build_week_elements(
                    week["title"],
                    week["locations"],
                    week["roster"],
                    font_name,
                    school_name="",
                    principal_name="",
                    font_size=font_size,
                    row_height=row_height,
                    include_school_line=False,
                    include_principal_line=False,
                )
            )
            if i < len(page_weeks) - 1:
                elements.append(Spacer(1, spacing_pt))

        if include_page_principal:
            elements.extend(_build_principal_line(page_principal_name, font_name, font_size))

        if page_start + 4 < len(valid_weeks):
            elements.append(PageBreak())

    doc.build(elements)
