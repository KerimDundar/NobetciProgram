# -*- coding: utf-8 -*-
from __future__ import annotations

import calendar
import json
import os
from datetime import date, timedelta
from pathlib import Path
from typing import List, Optional

import tkinter as tk
import tkinter.font as tkfont
from tkinter import filedialog, messagebox, simpledialog, ttk

from pdf_export import export_week_pdf, export_weeks_pdf
from roster_io import load_last_week, write_week_to_excel, write_weeks_to_excel
from roster_logic import (
    DAY_NAMES,
    WEEK_SPAN_DAYS,
    WEEK_STEP_DAYS,
    build_next_week,
    build_title,
    build_week,
    next_week_dates,
    parse_date_input,
    rotate_roster,
    rotate_roster_back,
)

APP_NAME = "NobetCizelgesi"
STATE_DIR = Path(os.getenv("LOCALAPPDATA", str(Path.home()))) / APP_NAME
STATE_FILE = STATE_DIR / "app_state.json"

BG_COLOR = "#0f172a"
CARD_COLOR = "#1e293b"
PRIMARY_COLOR = "#3b82f6"
HOVER_COLOR = "#2563eb"
TEXT_COLOR = "#e2e8f0"
MUTED_TEXT = "#94a3b8"
BORDER_COLOR = "#334155"

FONT_FAMILY = "Segoe UI"
FONT_SIZE = 10
FONT_NORMAL = (FONT_FAMILY, FONT_SIZE)
FONT_BOLD = (FONT_FAMILY, FONT_SIZE, "bold")
FONT_TITLE = (FONT_FAMILY, 14, "bold")

ENTRY_BG = "#020617"
WHITE_TEXT = "#ffffff"

APP_BG = BG_COLOR
SURFACE_BG = CARD_COLOR
SURFACE_ALT_BG = CARD_COLOR
SURFACE_MUTED_BG = BORDER_COLOR
CARD_BORDER = BORDER_COLOR
STATUS_CARD_BORDER = BORDER_COLOR
MUTED_TEXT_COLOR = MUTED_TEXT
STATUS_CAPTION_COLOR = MUTED_TEXT
BTN_BG = PRIMARY_COLOR
BTN_HOVER_BG = HOVER_COLOR
ACCENT_BG = PRIMARY_COLOR
ACCENT_HOVER_BG = HOVER_COLOR
ACCENT_ACTIVE_BG = HOVER_COLOR
SECONDARY_BG = PRIMARY_COLOR
SECONDARY_HOVER_BG = HOVER_COLOR
NEUTRAL_BG = PRIMARY_COLOR
NEUTRAL_HOVER_BG = HOVER_COLOR
DANGER_BG = PRIMARY_COLOR
DANGER_HOVER_BG = HOVER_COLOR
DANGER_TEXT = WHITE_TEXT
TREE_BG = CARD_COLOR
TREE_ALT_ROW_BG = BG_COLOR
TREE_HEADER_BG = BORDER_COLOR
TREE_SELECTED_BG = PRIMARY_COLOR
WEEK_HEADER_BG = BORDER_COLOR
GRID_ENTRY_BG = ENTRY_BG
GRID_ENTRY_BORDER = BORDER_COLOR
GRID_ENTRY_FOCUS_BORDER = PRIMARY_COLOR
DRAG_SOURCE_BG = PRIMARY_COLOR
DRAG_SOURCE_BORDER = PRIMARY_COLOR
DRAG_TARGET_BG = HOVER_COLOR
DRAG_TARGET_BORDER = PRIMARY_COLOR
DRAG_FLASH_BG = BORDER_COLOR
DRAG_FLASH_BORDER = PRIMARY_COLOR

SPACE_1 = 4
SPACE_2 = 8
SPACE_3 = 12
SPACE_4 = 16
SPACE_5 = 20
SPACE_6 = 24

MAIN_TREE_LOCATION_WIDTH = 300
MAIN_TREE_DAY_WIDTH = 155
MAIN_TABLE_DAY_COUNT = 5
PREVIEW_MIN_VISIBLE_ROWS = 6
PREVIEW_MAX_VISIBLE_ROWS = 14

EDIT_GRID_LOCATION_MINSIZE = 250
EDIT_GRID_DAY_MINSIZE = 165
EDIT_GRID_ACTION_MINSIZE = 72
EDIT_GRID_MIN_ROWS = 5

CALENDAR_COL_MINSIZE = 46
CALENDAR_DAY_BTN_WIDTH = 4

PDF_FILE_TYPES = [("PDF Dosyasi", "*.pdf")]
EXCEL_FILE_TYPES = [("Excel Dosyasi", "*.xlsx")]
DEFAULT_PDF_FILENAME = "nobet_ciktisi.pdf"
DEFAULT_EXCEL_FILENAME = "nobet_ciktisi.xlsx"


def _pick_font_family(root: tk.Misc) -> str:
    preferred = [
        "Segoe UI",
        "Segoe UI Variable Text",
        "Segoe UI Variable Display",
        "Calibri",
        "Arial",
    ]
    try:
        available = set(tkfont.families(root))
    except Exception:
        available = set()
    for name in preferred:
        if name in available:
            return name
    return "Segoe UI"


def _today_year() -> int:
    return date.today().year


def load_state() -> dict:
    if Path(STATE_FILE).exists():
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def _state_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


def _state_str(state: dict, key: str, default: str = "") -> str:
    value = state.get(key, default)
    return value if isinstance(value, str) else default


def _state_list(state: dict, key: str) -> list:
    value = state.get(key, [])
    return list(value) if isinstance(value, list) else []


def _state_roster(state: dict) -> list:
    value = state.get("roster", [])
    if not isinstance(value, list):
        return []
    return [list(row) if isinstance(row, list) else [] for row in value]


def save_state(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def _turkish_error_message(exc: Exception, generic_message: str) -> str:
    if isinstance(exc, FileNotFoundError):
        return "Dosya bulunamadi."
    if isinstance(exc, PermissionError):
        return "Dosyaya erisim izni yok."
    if isinstance(exc, ValueError):
        text = str(exc).strip()
        if text:
            return text
    return generic_message


def _parse_ui_date(value: str) -> Optional[date]:
    text = (value or "").strip()
    if not text:
        return None
    try:
        return parse_date_input(text, _today_year())
    except Exception:
        return None


def _format_iso_date(value: str) -> str:
    text = (value or "").strip()
    if not text:
        return ""
    try:
        return date.fromisoformat(text).strftime("%d.%m.%Y")
    except Exception:
        return text


def _ellipsize_middle(value: str, max_len: int) -> str:
    text = (value or "").strip()
    if max_len <= 3 or len(text) <= max_len:
        return text
    head = (max_len - 3) // 2
    tail = max_len - 3 - head
    return f"{text[:head]}...{text[-tail:]}"


def _empty_day_row() -> List[str]:
    return [""] * MAIN_TABLE_DAY_COUNT


def _copy_roster_rows(roster) -> List[List[str]]:
    copied: List[List[str]] = []
    for row in roster or []:
        if isinstance(row, (list, tuple)):
            copied.append(list(row))
        else:
            copied.append([])
    return copied


def _copy_week(week) -> dict:
    if not isinstance(week, dict):
        return {}
    locations = week.get("locations", []) or []
    return {
        "title": week.get("title", ""),
        "start_date": week.get("start_date", ""),
        "end_date": week.get("end_date", ""),
        "school_name": week.get("school_name", ""),
        "principal_name": week.get("principal_name", ""),
        "locations": list(locations) if isinstance(locations, (list, tuple)) else [],
        "roster": _copy_roster_rows(week.get("roster", []) or []),
    }


def _copy_weeks(weeks) -> List[dict]:
    return [_copy_week(week) for week in weeks or [] if isinstance(week, dict)]


MONTH_NAMES_TR = [
    "OCAK",
    "SUBAT",
    "MART",
    "NISAN",
    "MAYIS",
    "HAZIRAN",
    "TEMMUZ",
    "AGUSTOS",
    "EYLUL",
    "EKIM",
    "KASIM",
    "ARALIK",
]
WEEKDAY_SHORT_TR = ["Pzt", "Sal", "Car", "Per", "Cum", "Cmt", "Paz"]


class CalendarPopup(tk.Toplevel):
    def __init__(self, master, selected_date: date, on_select):
        super().__init__(master)
        self.title("Tarih Sec")
        self.resizable(False, False)
        self.configure(bg=SURFACE_BG)
        self.transient(master.winfo_toplevel())
        self.on_select = on_select
        self.selected_date = selected_date
        self.visible_year = selected_date.year
        self.visible_month = selected_date.month
        self._calendar = calendar.Calendar(firstweekday=0)
        self._day_buttons = []

        container = ttk.Frame(self, style="App.TFrame", padding=(10, 10, 10, 10))
        container.grid(row=0, column=0, sticky="nsew")
        container.columnconfigure(0, weight=1)

        header = ttk.Frame(container, style="App.TFrame")
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(1, weight=1)
        ttk.Button(header, text="<", width=3, style="Mini.TButton", command=self._prev_month).grid(
            row=0, column=0, padx=(0, 6)
        )
        self.title_var = tk.StringVar(value="")
        ttk.Label(header, textvariable=self.title_var, style="CalendarTitle.TLabel").grid(
            row=0, column=1, sticky="n", pady=(2, 0)
        )
        ttk.Button(header, text=">", width=3, style="Mini.TButton", command=self._next_month).grid(
            row=0, column=2, padx=(6, 0)
        )

        self.calendar_grid = ttk.Frame(container, style="App.TFrame")
        self.calendar_grid.grid(row=1, column=0, sticky="nsew", pady=(8, 0))
        for col in range(7):
            self.calendar_grid.columnconfigure(col, minsize=CALENDAR_COL_MINSIZE, weight=1)
        for col, day_name in enumerate(WEEKDAY_SHORT_TR):
            ttk.Label(
                self.calendar_grid,
                text=day_name,
                style="CalendarWeek.TLabel",
                width=4,
                anchor="center",
            ).grid(row=0, column=col, padx=1, pady=(0, 2), sticky="ew")

        self.days_grid = ttk.Frame(self.calendar_grid, style="App.TFrame")
        self.days_grid.grid(row=1, column=0, columnspan=7, sticky="nsew")
        for col in range(7):
            self.days_grid.columnconfigure(col, minsize=CALENDAR_COL_MINSIZE, weight=1)
        for row in range(6):
            self.days_grid.rowconfigure(row, weight=1)

        footer = ttk.Frame(container, style="App.TFrame")
        footer.grid(row=2, column=0, sticky="ew", pady=(8, 0))
        ttk.Button(footer, text="Bugun", style="Mini.TButton", command=self._jump_today).pack(side="left")
        ttk.Button(footer, text="Kapat", style="Mini.TButton", command=self.destroy).pack(side="right")

        self.bind("<Escape>", lambda _e: self.destroy())
        self._render_days()

    def _month_title(self) -> str:
        return f"{MONTH_NAMES_TR[self.visible_month - 1]} {self.visible_year}"

    def _prev_month(self):
        if self.visible_month == 1:
            self.visible_month = 12
            self.visible_year -= 1
        else:
            self.visible_month -= 1
        self._render_days()

    def _next_month(self):
        if self.visible_month == 12:
            self.visible_month = 1
            self.visible_year += 1
        else:
            self.visible_month += 1
        self._render_days()

    def _jump_today(self):
        today = date.today()
        self.visible_year = today.year
        self.visible_month = today.month
        self.selected_date = today
        self._render_days()

    def _select_day(self, day_num: int):
        chosen = date(self.visible_year, self.visible_month, day_num)
        self.selected_date = chosen
        if callable(self.on_select):
            self.on_select(chosen)
        self.destroy()

    def _render_days(self):
        self.title_var.set(self._month_title())
        for child in self.days_grid.winfo_children():
            child.destroy()
        self._day_buttons = []

        weeks = self._calendar.monthdayscalendar(self.visible_year, self.visible_month)
        for row_idx, week in enumerate(weeks):
            for col_idx, day_num in enumerate(week):
                if day_num == 0:
                    ttk.Label(self.days_grid, text=" ", style="CalendarWeek.TLabel", width=4).grid(
                        row=row_idx, column=col_idx, padx=1, pady=1, sticky="ew"
                    )
                    continue
                btn_style = "MiniAccent.TButton" if (
                    self.selected_date.year == self.visible_year
                    and self.selected_date.month == self.visible_month
                    and self.selected_date.day == day_num
                ) else "Mini.TButton"
                btn = ttk.Button(
                    self.days_grid,
                    text=f"{day_num:02d}",
                    width=CALENDAR_DAY_BTN_WIDTH,
                    style=btn_style,
                    command=lambda d=day_num: self._select_day(d),
                )
                btn.grid(row=row_idx, column=col_idx, padx=1, pady=1, sticky="ew")
                self._day_buttons.append(btn)


class DatePicker(ttk.Frame):
    def __init__(self, master, initial_date: Optional[date] = None):
        super().__init__(master)
        self._date = initial_date or date.today()
        self._popup = None
        self.value_var = tk.StringVar(value=self._format_date(self._date))

        self.value_entry = ttk.Entry(
            self,
            textvariable=self.value_var,
            width=12,
            state="readonly",
            justify="center",
        )
        self.value_entry.grid(row=0, column=0, sticky="w")
        self.value_entry.configure(cursor="hand2")
        self.value_entry.bind("<Button-1>", lambda _e: self._open_popup(), add="+")

    def _format_date(self, value: date) -> str:
        return value.strftime("%d.%m.%Y")

    def _open_popup(self):
        if self._popup and self._popup.winfo_exists():
            self._popup.lift()
            self._popup.focus_force()
            return
        self._popup = CalendarPopup(self, self._date, self._on_date_selected)
        self._popup.update_idletasks()
        x = self.winfo_rootx()
        y = self.winfo_rooty() + self.winfo_height() + 4
        self._popup.geometry(f"+{x}+{y}")
        self._popup.grab_set()
        self._popup.focus_force()
        self._popup.bind("<Destroy>", self._on_popup_destroy, add="+")

    def _on_popup_destroy(self, _event=None):
        if _event is None or _event.widget is self._popup:
            self._popup = None

    def _on_date_selected(self, selected: date):
        self.set_date(selected)

    def set_date(self, value: date):
        self._date = value
        self.value_var.set(self._format_date(value))

    def get_date(self) -> date:
        return self._date

    def get_iso(self) -> str:
        return self.get_date().isoformat()


class EditWindow(tk.Toplevel):
    def __init__(
        self,
        master,
        locations,
        roster,
        start_date_str,
        end_date_str,
        school_name_str,
        principal_name_str,
        on_save,
    ):
        super().__init__(master)
        self.title("Yeni / Hafta Duzenle")
        self.configure(bg=APP_BG)
        self.on_save = on_save

        self.locations = list(locations or [])
        self.roster = _copy_roster_rows(roster)

        start_date = _parse_ui_date(start_date_str)
        end_date = _parse_ui_date(end_date_str)
        if start_date and not end_date:
            end_date = start_date + timedelta(days=4)
        if end_date and not start_date:
            start_date = end_date - timedelta(days=4)
        if not start_date:
            start_date = date.today()
        if not end_date:
            end_date = start_date + timedelta(days=4)

        self.school_var = tk.StringVar(value=school_name_str)
        self.principal_var = tk.StringVar(value=principal_name_str)

        self.geometry("1280x760")
        self.minsize(1060, 640)
        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)
        self._entry_font = FONT_NORMAL

        shell = ttk.Frame(self, style="App.TFrame", padding=(SPACE_5, SPACE_4, SPACE_5, SPACE_4))
        shell.grid(row=0, column=0, sticky="nsew")
        shell.columnconfigure(0, weight=1)
        shell.rowconfigure(2, weight=1)

        header = ttk.Frame(shell, style="Hero.TFrame", padding=(SPACE_5, SPACE_4, SPACE_5, SPACE_4))
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(0, weight=1)
        header.columnconfigure(1, weight=0)
        ttk.Label(header, text="Yeni / Hafta Duzenle", style="DialogTitle.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            header,
            text="Tarihleri takvimden secin, tabloyu surukle-birak veya manuel duzenleyin.",
            style="DialogSub.TLabel",
        ).grid(row=1, column=0, sticky="w", pady=(SPACE_1, 0))
        today_text = f"Bugun: {date.today().strftime('%d.%m.%Y')}"
        ttk.Label(header, text=today_text, style="DialogNow.TLabel").grid(row=0, column=1, rowspan=2, sticky="e")
        ttk.Separator(header, orient="horizontal").grid(row=2, column=0, columnspan=2, sticky="ew", pady=(SPACE_3, 0))

        info_card = ttk.Frame(shell, style="EditCard.TFrame", padding=(SPACE_4, SPACE_3, SPACE_4, SPACE_3))
        info_card.grid(row=1, column=0, sticky="ew", pady=(SPACE_3, SPACE_3))
        for col in range(4):
            info_card.columnconfigure(col, weight=1)
        ttk.Label(info_card, text="Hafta Bilgileri", style="EditCardTitle.TLabel").grid(row=0, column=0, columnspan=4, sticky="w")
        ttk.Separator(info_card, orient="horizontal").grid(row=1, column=0, columnspan=4, sticky="ew", pady=(SPACE_2, SPACE_3))

        ttk.Label(info_card, text="Baslangic", style="DialogField.TLabel").grid(row=2, column=0, sticky="w")
        self.start_picker = DatePicker(info_card, initial_date=start_date)
        self.start_picker.grid(row=2, column=1, sticky="w", padx=(SPACE_2, SPACE_5))
        ttk.Label(info_card, text="Bitis", style="DialogField.TLabel").grid(row=2, column=2, sticky="w")
        self.end_picker = DatePicker(info_card, initial_date=end_date)
        self.end_picker.grid(row=2, column=3, sticky="w", padx=(SPACE_2, 0))

        ttk.Label(info_card, text="Okul", style="DialogField.TLabel").grid(row=3, column=0, sticky="w", pady=(SPACE_3, 0))
        ttk.Entry(info_card, textvariable=self.school_var, width=42).grid(
            row=3, column=1, sticky="ew", padx=(SPACE_2, SPACE_5), pady=(SPACE_3, 0)
        )
        ttk.Label(info_card, text="Mudur", style="DialogField.TLabel").grid(row=3, column=2, sticky="w", pady=(SPACE_3, 0))
        ttk.Entry(info_card, textvariable=self.principal_var, width=42).grid(
            row=3, column=3, sticky="ew", padx=(SPACE_2, 0), pady=(SPACE_3, 0)
        )

        table_card = ttk.Frame(shell, style="EditCard.TFrame", padding=(SPACE_3, SPACE_3, SPACE_3, SPACE_3))
        table_card.grid(row=2, column=0, sticky="nsew")
        table_card.columnconfigure(0, weight=1)
        table_card.rowconfigure(2, weight=1)
        ttk.Label(table_card, text="Nobet Dagilimi", style="EditCardTitle.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Separator(table_card, orient="horizontal").grid(row=1, column=0, sticky="ew", pady=(SPACE_2, SPACE_2))

        self.grid_frame = ttk.Frame(table_card, style="TableCard.TFrame")
        self.grid_frame.grid(row=2, column=0, sticky="nsew")

        self.entries = []
        self.teacher_entries = set()
        self._drag_source_entry = None
        self._drag_hover_entry = None
        self._drag_start_xy = None
        self._drag_active = False
        self._drag_passthrough = False
        self._edit_active_entry = None
        self._drag_threshold = 6
        self._default_drag_status = "Surukle-birak: Sol tikla, basili tut, diger ogretmen kutusuna birak."
        self.drag_status_var = tk.StringVar(value=self._default_drag_status)

        self._history = []
        self._history_index = -1
        self._history_suspended = False
        self._build_grid()
        self._record_history()

        status = ttk.Label(shell, textvariable=self.drag_status_var, style="EditStatus.TLabel")
        status.grid(row=3, column=0, sticky="ew", pady=(SPACE_3, SPACE_2))

        btns = ttk.Frame(shell, style="App.TFrame")
        btns.grid(row=4, column=0, sticky="ew", pady=(SPACE_1, 0))
        btns.columnconfigure(0, weight=1)
        actions = ttk.Frame(btns, style="App.TFrame")
        actions.grid(row=0, column=1, sticky="e")
        ttk.Button(actions, text="Satir Ekle", style="Secondary.TButton", command=self._add_row).grid(row=0, column=0, padx=(0, SPACE_2))
        ttk.Button(actions, text="Kaydet", style="Accent.TButton", command=self._save).grid(row=0, column=1, padx=(0, SPACE_2))
        ttk.Button(actions, text="Vazgec", style="Secondary.TButton", command=self.destroy).grid(row=0, column=2)

        self.bind("<Control-z>", self._undo, add="+")
        self.bind("<Control-Z>", self._undo, add="+")
        self.bind("<Control-y>", self._redo, add="+")
        self.bind("<Control-Y>", self._redo, add="+")
        self.bind("<Control-Shift-Z>", self._redo, add="+")
        self.bind("<Button-1>", self._on_background_click, add="+")

    def _create_grid_entry(self, width: int, teacher_cell: bool = False, base_bg: str = GRID_ENTRY_BG):
        entry = tk.Entry(
            self.grid_frame,
            width=width,
            relief="flat",
            borderwidth=0,
            highlightthickness=1,
            bg=base_bg,
            fg=TEXT_COLOR,
            insertbackground=TEXT_COLOR,
            highlightbackground=GRID_ENTRY_BORDER,
            highlightcolor=GRID_ENTRY_FOCUS_BORDER,
            font=self._entry_font,
        )
        entry._base_bg = base_bg
        entry._base_border = GRID_ENTRY_BORDER
        if teacher_cell:
            entry.configure(cursor="hand2")
        return entry

    def _set_teacher_entry_visual(self, entry, state: str = "normal"):
        base_bg = getattr(entry, "_base_bg", GRID_ENTRY_BG)
        base_border = getattr(entry, "_base_border", GRID_ENTRY_BORDER)
        palette = {
            "normal": (base_bg, base_border),
            "source": (DRAG_SOURCE_BG, DRAG_SOURCE_BORDER),
            "target": (DRAG_TARGET_BG, DRAG_TARGET_BORDER),
            "flash": (DRAG_FLASH_BG, DRAG_FLASH_BORDER),
        }
        bg, border = palette.get(state, palette["normal"])
        entry.configure(bg=bg, highlightbackground=border, highlightcolor=border)

    def _flash_swapped_entries(self, first, second):
        for entry in (first, second):
            if entry in self.teacher_entries:
                self._set_teacher_entry_visual(entry, "flash")

        def _restore():
            for entry in (first, second):
                if entry in self.teacher_entries and entry.winfo_exists():
                    self._set_teacher_entry_visual(entry, "normal")

        self.after(180, _restore)

    def _bind_cell_shortcuts(self, entry):
        entry.bind("<Control-z>", self._undo, add="+")
        entry.bind("<Control-Z>", self._undo, add="+")
        entry.bind("<Control-y>", self._redo, add="+")
        entry.bind("<Control-Y>", self._redo, add="+")
        entry.bind("<Control-Shift-Z>", self._redo, add="+")
        entry.bind("<KeyRelease>", self._on_cell_key_release, add="+")

    def _on_cell_key_release(self, event=None):
        if self._history_suspended:
            return
        keysym = (getattr(event, "keysym", "") or "").lower()
        if keysym in {"control_l", "control_r", "shift_l", "shift_r", "alt_l", "alt_r"}:
            return
        if (getattr(event, "state", 0) & 0x4) and keysym in {"z", "y"}:
            return
        self._record_history()

    def _capture_snapshot(self) -> dict:
        if self.entries:
            locations = []
            roster = []
            for row in self.entries:
                locations.append(row[0].get())
                roster.append([entry.get() for entry in row[1:]])
            return {"locations": locations, "roster": roster}
        return {
            "locations": [str(v) for v in self.locations],
            "roster": [[str(cell) for cell in row[:MAIN_TABLE_DAY_COUNT]] for row in self.roster],
        }

    def _record_history(self):
        if self._history_suspended:
            return
        snapshot = self._capture_snapshot()
        if self._history_index >= 0 and snapshot == self._history[self._history_index]:
            return
        self._history = self._history[: self._history_index + 1]
        self._history.append(snapshot)
        if len(self._history) > 200:
            overflow = len(self._history) - 200
            self._history = self._history[overflow:]
            self._history_index = max(-1, self._history_index - overflow)
        self._history_index = len(self._history) - 1

    def _restore_snapshot(self, snapshot: dict):
        self._history_suspended = True
        try:
            self.locations = [str(v) for v in (snapshot.get("locations", []) or [])]
            restored_roster = []
            for row in (snapshot.get("roster", []) or []):
                vals = [str(v) for v in (row or [])[:MAIN_TABLE_DAY_COUNT]]
                while len(vals) < MAIN_TABLE_DAY_COUNT:
                    vals.append("")
                restored_roster.append(vals)
            self.roster = restored_roster
            self._build_grid()
        finally:
            self._history_suspended = False

    def _undo(self, event=None):
        if self._history_index <= 0:
            return "break"
        self._history_index -= 1
        self._restore_snapshot(self._history[self._history_index])
        self.drag_status_var.set("Geri alindi (Ctrl+Z).")
        return "break"

    def _redo(self, event=None):
        if self._history_index >= len(self._history) - 1:
            return "break"
        self._history_index += 1
        self._restore_snapshot(self._history[self._history_index])
        self.drag_status_var.set("Yinele uygulandi (Ctrl+Y).")
        return "break"

    def _build_grid(self):
        for child in self.grid_frame.winfo_children():
            child.destroy()

        self.configure(cursor="")
        self._drag_source_entry = None
        self._drag_hover_entry = None
        self._drag_start_xy = None
        self._drag_active = False
        self._drag_passthrough = False
        self._edit_active_entry = None
        self.drag_status_var.set(self._default_drag_status)
        self.grid_frame.columnconfigure(0, weight=2, minsize=EDIT_GRID_LOCATION_MINSIZE)
        for col in range(1, MAIN_TABLE_DAY_COUNT + 1):
            self.grid_frame.columnconfigure(col, weight=1, minsize=EDIT_GRID_DAY_MINSIZE)
        self.grid_frame.columnconfigure(MAIN_TABLE_DAY_COUNT + 1, weight=0, minsize=EDIT_GRID_ACTION_MINSIZE)

        ttk.Label(self.grid_frame, text="Gorev Yeri", style="GridHead.TLabel").grid(row=0, column=0, padx=2, pady=(2, 1), sticky="ew")
        for i, day in enumerate(DAY_NAMES, start=1):
            ttk.Label(self.grid_frame, text=day.title(), style="GridHead.TLabel").grid(row=0, column=i, padx=2, pady=(2, 1), sticky="ew")
            controls = ttk.Frame(self.grid_frame, style="EditCard.TFrame")
            controls.grid(row=1, column=i, padx=2, pady=(0, SPACE_2))
            ttk.Button(
                controls,
                text="▲",
                style="Mini.TButton",
                width=3,
                command=lambda col=i - 1: self._shift_day_column(col, "up"),
            ).pack(side="left")
            ttk.Button(
                controls,
                text="▼",
                style="Mini.TButton",
                width=3,
                command=lambda col=i - 1: self._shift_day_column(col, "down"),
            ).pack(side="left", padx=(2, 0))

        ttk.Label(self.grid_frame, text="Islem", style="GridHead.TLabel").grid(
            row=0, column=MAIN_TABLE_DAY_COUNT + 1, padx=2, pady=(2, 1), sticky="ew"
        )
        ttk.Label(self.grid_frame, text="").grid(row=1, column=0, padx=2, pady=2)
        ttk.Label(self.grid_frame, text="").grid(row=1, column=MAIN_TABLE_DAY_COUNT + 1, padx=2, pady=2)

        self.entries = []
        self.teacher_entries = set()
        row_count = max(EDIT_GRID_MIN_ROWS, len(self.locations))
        for r in range(row_count):
            loc = self.locations[r] if r < len(self.locations) else ""
            row_bg = GRID_ENTRY_BG
            loc_entry = self._create_grid_entry(width=28, base_bg=row_bg)
            loc_entry.insert(0, loc)
            loc_entry.grid(row=r + 2, column=0, padx=2, pady=2, sticky="ew")
            self._bind_cell_shortcuts(loc_entry)

            row_entries = [loc_entry]
            for c in range(MAIN_TABLE_DAY_COUNT):
                val = ""
                if r < len(self.roster) and c < len(self.roster[r]):
                    val = self.roster[r][c]
                e = self._create_grid_entry(width=19, teacher_cell=True, base_bg=row_bg)
                e.insert(0, val)
                e.grid(row=r + 2, column=c + 1, padx=2, pady=2, sticky="ew")
                self.teacher_entries.add(e)
                self._set_teacher_entry_visual(e, "normal")
                self._bind_cell_shortcuts(e)
                e.bind("<ButtonPress-1>", self._on_teacher_press, add="+")
                e.bind("<B1-Motion>", self._on_teacher_drag, add="+")
                e.bind("<ButtonRelease-1>", self._on_teacher_release, add="+")
                e.bind("<FocusOut>", self._on_teacher_focus_out, add="+")
                row_entries.append(e)
            del_btn = ttk.Button(self.grid_frame, text="Sil", width=6, style="MiniSecondary.TButton", command=lambda i=r: self._delete_row_at(i))
            del_btn.grid(row=r + 2, column=MAIN_TABLE_DAY_COUNT + 1, padx=2, pady=2)
            self.entries.append(row_entries)

    def _on_teacher_press(self, event):
        widget = event.widget
        if widget not in self.teacher_entries:
            return None

        if self._edit_active_entry is widget:
            self._drag_passthrough = True
            return None

        self._drag_passthrough = False
        self._edit_active_entry = None

        if self._drag_hover_entry and self._drag_hover_entry in self.teacher_entries:
            self._set_teacher_entry_visual(self._drag_hover_entry, "normal")
        if self._drag_source_entry and self._drag_source_entry in self.teacher_entries:
            self._set_teacher_entry_visual(self._drag_source_entry, "normal")

        self._drag_source_entry = widget
        self._drag_hover_entry = None
        self._drag_start_xy = (event.x_root, event.y_root)
        self._drag_active = False
        self._set_teacher_entry_visual(widget, "source")
        self.drag_status_var.set("Kaynak secildi. Basili tutup baska ogretmen kutusuna birak.")
        return "break"

    def _on_teacher_drag(self, event):
        if self._drag_passthrough:
            return None
        if not self._drag_source_entry or not self._drag_start_xy:
            return "break"
        if not self._drag_active:
            start_x, start_y = self._drag_start_xy
            if abs(event.x_root - start_x) >= self._drag_threshold or abs(event.y_root - start_y) >= self._drag_threshold:
                self._drag_active = True
                self.configure(cursor="fleur")
                self.drag_status_var.set("Hedef kutunun ustune gel ve birak.")

        if not self._drag_active:
            return "break"

        target = self.winfo_containing(event.x_root, event.y_root)
        if target not in self.teacher_entries or target is self._drag_source_entry:
            target = None

        if target is self._drag_hover_entry:
            return "break"

        if self._drag_hover_entry and self._drag_hover_entry in self.teacher_entries:
            self._set_teacher_entry_visual(self._drag_hover_entry, "normal")

        self._drag_hover_entry = target
        if target:
            self._set_teacher_entry_visual(target, "target")
            self.drag_status_var.set("Birakinca iki ogretmen kutusu yer degistirecek.")
        else:
            self.drag_status_var.set("Gecerli hedef icin baska bir ogretmen kutusunun ustune gel.")
        return "break"

    def _on_teacher_focus_out(self, event):
        if event.widget is self._edit_active_entry:
            self._edit_active_entry = None

    def _on_background_click(self, event):
        widget = event.widget
        if isinstance(widget, (tk.Entry, ttk.Entry)):
            return None
        if isinstance(widget, (tk.Button, ttk.Button, ttk.Combobox)):
            return None
        self._edit_active_entry = None
        self._drag_passthrough = False
        self.focus_set()
        return None

    def _on_teacher_release(self, event):
        if self._drag_passthrough:
            self._drag_passthrough = False
            return None

        source = self._drag_source_entry
        is_drag = self._drag_active
        target = self.winfo_containing(event.x_root, event.y_root)
        if target not in self.teacher_entries or target is source:
            target = None

        self.configure(cursor="")
        if source and source in self.teacher_entries:
            self._set_teacher_entry_visual(source, "normal")
        if self._drag_hover_entry and self._drag_hover_entry in self.teacher_entries:
            self._set_teacher_entry_visual(self._drag_hover_entry, "normal")

        self._drag_source_entry = None
        self._drag_hover_entry = None
        self._drag_start_xy = None
        self._drag_active = False

        if not source or not is_drag:
            if source and source in self.teacher_entries:
                self._edit_active_entry = source
                source.focus_set()
                source.icursor(tk.END)
                self.drag_status_var.set("Duzenleme modu acildi. Yazabilir veya tekrar tiklayip secim yapabilirsin.")
            else:
                self.drag_status_var.set("Duzenleme hazir. Yazabilir veya surukle-birak yapabilirsin.")
            return "break"

        if not target:
            self.drag_status_var.set("Yer degistirme iptal: gecerli hedef secilmedi.")
            return "break"

        source_val = source.get()
        target_val = target.get()
        source.delete(0, tk.END)
        source.insert(0, target_val)
        target.delete(0, tk.END)
        target.insert(0, source_val)
        self._edit_active_entry = None
        self._record_history()
        self._flash_swapped_entries(source, target)
        self.drag_status_var.set("Yer degistirildi.")
        return "break"

    def _shift_day_column(self, day_col: int, direction: str):
        if day_col < 0 or day_col > 4:
            return

        indices = []
        values = []
        for row_idx, row in enumerate(self.entries):
            value = row[day_col + 1].get()
            if value.strip():
                indices.append(row_idx)
                values.append(value)

        if len(values) <= 1:
            return

        if direction == "up":
            rotated = values[1:] + values[:1]
        else:
            rotated = values[-1:] + values[:-1]

        for row_idx, new_val in zip(indices, rotated):
            entry = self.entries[row_idx][day_col + 1]
            entry.delete(0, tk.END)
            entry.insert(0, new_val)
        self._record_history()

    def _sync_grid_to_model(self):
        if not self.entries:
            return
        self.locations = []
        self.roster = []
        for row in self.entries:
            loc = row[0].get().strip()
            values = [entry.get().strip() for entry in row[1:]]
            self.locations.append(loc)
            self.roster.append(values)

    def _add_row(self):
        self._sync_grid_to_model()
        self.locations.append("")
        self.roster.append(_empty_day_row())
        self._build_grid()
        self._record_history()

    def _delete_row_at(self, index: int):
        self._sync_grid_to_model()
        if 0 <= index < len(self.locations):
            self.locations.pop(index)
        if 0 <= index < len(self.roster):
            self.roster.pop(index)
        self._build_grid()
        self._record_history()

    def _save(self):
        locations = []
        roster = []
        for row in self.entries:
            loc = row[0].get().strip()
            values = [e.get().strip() for e in row[1:]]
            if not loc and all(v == "" for v in values):
                continue
            if not loc:
                messagebox.showerror("Dogrulama", "Dolu bir satirda gorev yeri bos olamaz.")
                return
            locations.append(loc)
            roster.append(values)

        self.on_save(
            self.start_picker.get_iso(),
            self.end_picker.get_iso(),
            self.school_var.get().strip(),
            self.principal_var.get().strip(),
            locations,
            roster,
        )
        self.destroy()


class RangeGenerateWindow(tk.Toplevel):
    def __init__(self, master, start_date_str, end_date_str, on_apply, on_month, on_next):
        super().__init__(master)
        self.title("Tarih Araliginda Olustur")
        self.configure(bg=APP_BG)
        self.on_apply = on_apply
        self.on_month = on_month
        self.on_next = on_next

        start_date = _parse_ui_date(start_date_str)
        end_date = _parse_ui_date(end_date_str)
        if start_date and not end_date:
            end_date = start_date + timedelta(days=4)
        if end_date and not start_date:
            start_date = end_date - timedelta(days=4)
        if not start_date:
            start_date = date.today()
        if not end_date:
            end_date = start_date + timedelta(days=4)

        frame = ttk.Frame(self, padding=10)
        frame.grid(row=0, column=0, sticky="nsew")

        ttk.Label(frame, text="Baslangic tarihi:").grid(row=0, column=0, sticky="w")
        self.start_picker = DatePicker(frame, initial_date=start_date)
        self.start_picker.grid(row=0, column=1, sticky="w", padx=5)
        ttk.Label(frame, text="Bitis tarihi:").grid(row=1, column=0, sticky="w")
        self.end_picker = DatePicker(frame, initial_date=end_date)
        self.end_picker.grid(row=1, column=1, sticky="w", padx=5)

        btns = ttk.Frame(frame, padding=(0, 10, 0, 0))
        btns.grid(row=2, column=0, columnspan=2, sticky="w")
        ttk.Button(btns, text="Girilen Tarihi Olustur", style="Accent.TButton", command=self._apply).grid(row=0, column=0, padx=(0, 5))
        ttk.Button(btns, text="Aylik Olustur", style="Accent.TButton", command=self._month).grid(row=0, column=1, padx=(0, 5))
        ttk.Button(btns, text="Sonraki Haftayi Olustur", style="Accent.TButton", command=self._next).grid(row=0, column=2, padx=(0, 5))
        ttk.Button(btns, text="Kapat", style="Accent.TButton", command=self.destroy).grid(row=0, column=3)

    def _get_values(self):
        return self.start_picker.get_iso(), self.end_picker.get_iso()

    def _apply(self):
        start_val, end_val = self._get_values()
        self.on_apply(start_val, end_val)

    def _month(self):
        start_val, end_val = self._get_values()
        self.on_month(start_val, end_val)

    def _next(self):
        start_val, end_val = self._get_values()
        self.on_next(start_val, end_val)


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Nobet Cizelgesi")
        self.geometry("1220x760")
        self.minsize(1080, 680)
        self.configure(bg=APP_BG)
        self.option_add("*TButton.takeFocus", 0)
        self._font_family = FONT_FAMILY
        self._setup_styles()

        self.state = _state_dict(load_state())
        self.workbook_path = self.state.get("workbook_path")
        if self.workbook_path and not Path(self.workbook_path).exists():
            self.workbook_path = None
        self.year = self.state.get("year") or _today_year()

        self.current_title = _state_str(self.state, "current_title")
        self.current_start = self._parse_date(_state_str(self.state, "current_start_date"))
        self.current_end = self._parse_date(_state_str(self.state, "current_end_date"))
        self.school_name = _state_str(self.state, "school_name")
        self.principal_name = _state_str(self.state, "principal_name")
        self.locations = _state_list(self.state, "locations")
        self.roster = _copy_roster_rows(_state_roster(self.state))
        state_last_generated = self.state.get("last_generated")
        self.last_generated = _copy_week(state_last_generated) if state_last_generated else None
        state_last_output = self.state.get("last_output")
        self.last_output = dict(state_last_output) if isinstance(state_last_output, dict) else state_last_output
        self.month_generated = _copy_weeks(self.state.get("month_generated", []))
        self.edit_window = None
        self.preview_visible_var = tk.BooleanVar(value=True)
        self.preview_weeks = []
        self._preview_item_map = {}
        self._preview_editor = None
        self._preview_scroll_rows = PREVIEW_MIN_VISIBLE_ROWS

        self._build_ui()
        self._refresh_preview()

    def _parse_date(self, s: Optional[str]) -> Optional[date]:
        if not s:
            return None
        try:
            return date.fromisoformat(s)
        except Exception:
            return None

    def _ensure_year(self) -> int:
        if self.year:
            return self.year
        y = simpledialog.askinteger("Yil", "Yili girin (orn. 2026):", initialvalue=_today_year())
        self.year = y if y else _today_year()
        return self.year

    def _setup_styles(self):
        style = ttk.Style(self)
        themes = style.theme_names()
        if "clam" in themes:
            style.theme_use("clam")
        elif "vista" in themes:
            style.theme_use("vista")

        font_family = FONT_FAMILY
        base_font = FONT_NORMAL
        caption_font = (font_family, 9)
        heading_font = FONT_BOLD
        section_font = FONT_TITLE
        title_font = FONT_TITLE
        subtitle_font = (font_family, 9)
        button_font = FONT_BOLD

        style.configure(".", font=base_font)
        style.configure("TFrame", background=APP_BG)
        style.configure("App.TFrame", background=APP_BG)
        style.configure("TLabel", background=APP_BG, foreground=TEXT_COLOR, font=base_font)
        style.configure("Info.TLabel", background=APP_BG, foreground=MUTED_TEXT_COLOR, font=caption_font)
        style.configure("TSeparator", background=CARD_BORDER)

        style.configure("Hero.TFrame", background=SURFACE_BG, relief="flat", borderwidth=0)
        style.configure("HeroTitle.TLabel", background=SURFACE_BG, foreground=TEXT_COLOR, font=title_font)
        style.configure("HeroSub.TLabel", background=SURFACE_BG, foreground=STATUS_CAPTION_COLOR, font=subtitle_font)
        style.configure(
            "HeaderDate.TLabel",
            background=SURFACE_MUTED_BG,
            foreground=MUTED_TEXT_COLOR,
            font=FONT_BOLD,
            padding=(SPACE_3, SPACE_2 - 1),
        )
        style.configure("InfoStrip.TFrame", background=SURFACE_MUTED_BG, relief="flat")
        style.configure("StatusCard.TFrame", background=SURFACE_BG, relief="flat", borderwidth=0)
        style.configure(
            "InfoMeta.TLabel",
            background=SURFACE_BG,
            foreground=STATUS_CAPTION_COLOR,
            font=caption_font,
        )
        style.configure(
            "InfoValue.TLabel",
            background=SURFACE_BG,
            foreground=TEXT_COLOR,
            font=FONT_NORMAL,
        )
        style.configure("ActionCard.TFrame", background=SURFACE_ALT_BG, relief="flat", borderwidth=0)
        style.configure("ActionTitle.TLabel", background=SURFACE_ALT_BG, foreground=TEXT_COLOR, font=FONT_BOLD)
        style.configure("ActionSub.TLabel", background=SURFACE_ALT_BG, foreground=MUTED_TEXT_COLOR, font=caption_font)

        style.configure("Card.TLabelframe", background=SURFACE_BG, relief="flat", borderwidth=0)
        style.configure(
            "Card.TLabelframe.Label",
            background=SURFACE_BG,
            foreground=MUTED_TEXT_COLOR,
            font=caption_font,
        )
        style.configure("TableCard.TFrame", background=SURFACE_BG, relief="flat", borderwidth=0)
        style.configure("SectionTitle.TLabel", background=SURFACE_BG, foreground=TEXT_COLOR, font=section_font)
        style.configure("TableMeta.TLabel", background=SURFACE_BG, foreground=MUTED_TEXT_COLOR, font=caption_font)
        style.configure("DialogTitle.TLabel", background=SURFACE_BG, foreground=TEXT_COLOR, font=FONT_TITLE)
        style.configure("DialogSub.TLabel", background=SURFACE_BG, foreground=MUTED_TEXT_COLOR, font=subtitle_font)
        style.configure("DialogField.TLabel", background=SURFACE_BG, foreground=TEXT_COLOR, font=FONT_BOLD)
        style.configure(
            "DialogNow.TLabel",
            background=SURFACE_MUTED_BG,
            foreground=TEXT_COLOR,
            font=FONT_BOLD,
            padding=(SPACE_3, SPACE_2),
        )
        style.configure("EditCard.TFrame", background=SURFACE_BG, relief="flat", borderwidth=0)
        style.configure("EditCardTitle.TLabel", background=SURFACE_BG, foreground=TEXT_COLOR, font=FONT_TITLE)
        style.configure("EditStatus.TLabel", background=SURFACE_MUTED_BG, foreground=MUTED_TEXT_COLOR, font=caption_font, padding=(SPACE_3, SPACE_2))
        style.configure("GridHead.TLabel", background=TREE_HEADER_BG, foreground=TEXT_COLOR, font=heading_font, padding=(10, 8))
        style.configure("CalendarTitle.TLabel", background=APP_BG, foreground=TEXT_COLOR, font=heading_font)
        style.configure("CalendarWeek.TLabel", background=APP_BG, foreground=MUTED_TEXT_COLOR, font=caption_font)

        style.configure(
            "TButton",
            background=NEUTRAL_BG,
            foreground=TEXT_COLOR,
            borderwidth=0,
            relief="flat",
            padding=(13, 9),
            font=button_font,
            focusthickness=0,
            focuscolor=NEUTRAL_BG,
        )
        style.map(
            "TButton",
            background=[("active", NEUTRAL_HOVER_BG), ("pressed", BTN_HOVER_BG)],
            foreground=[("disabled", MUTED_TEXT_COLOR), ("!disabled", WHITE_TEXT)],
        )

        style.configure(
            "Accent.TButton",
            background=ACCENT_BG,
            foreground=WHITE_TEXT,
            borderwidth=0,
            relief="flat",
            padding=(13, 9),
            font=button_font,
            focusthickness=0,
            focuscolor=ACCENT_BG,
        )
        style.map(
            "Accent.TButton",
            background=[("active", ACCENT_HOVER_BG), ("pressed", ACCENT_ACTIVE_BG)],
            foreground=[("disabled", MUTED_TEXT_COLOR), ("!disabled", WHITE_TEXT)],
        )

        style.configure(
            "Secondary.TButton",
            background=SECONDARY_BG,
            foreground=WHITE_TEXT,
            borderwidth=0,
            relief="flat",
            padding=(13, 9),
            font=button_font,
            focusthickness=0,
            focuscolor=SECONDARY_BG,
        )
        style.map(
            "Secondary.TButton",
            background=[("active", SECONDARY_HOVER_BG), ("pressed", SECONDARY_HOVER_BG)],
            foreground=[("disabled", MUTED_TEXT_COLOR), ("!disabled", WHITE_TEXT)],
        )
        style.configure(
            "Exit.TButton",
            background=DANGER_BG,
            foreground=DANGER_TEXT,
            borderwidth=0,
            relief="flat",
            padding=(13, 9),
            font=button_font,
            focusthickness=0,
            focuscolor=DANGER_BG,
        )
        style.map(
            "Exit.TButton",
            background=[("active", DANGER_HOVER_BG), ("pressed", DANGER_HOVER_BG)],
            foreground=[("disabled", STATUS_CAPTION_COLOR), ("!disabled", WHITE_TEXT)],
        )
        style.configure(
            "Mini.TButton",
            background=BTN_BG,
            foreground=WHITE_TEXT,
            borderwidth=0,
            relief="flat",
            padding=(6, 3),
            font=button_font,
            focusthickness=0,
            focuscolor=BTN_BG,
        )
        style.map(
            "Mini.TButton",
            background=[("active", BTN_HOVER_BG), ("pressed", BTN_HOVER_BG)],
            foreground=[("disabled", MUTED_TEXT_COLOR), ("!disabled", WHITE_TEXT)],
        )
        style.configure(
            "MiniAccent.TButton",
            background=ACCENT_BG,
            foreground=WHITE_TEXT,
            borderwidth=0,
            relief="flat",
            padding=(6, 3),
            font=button_font,
            focusthickness=0,
            focuscolor=ACCENT_BG,
        )
        style.map(
            "MiniAccent.TButton",
            background=[("active", ACCENT_HOVER_BG), ("pressed", ACCENT_HOVER_BG)],
            foreground=[("disabled", MUTED_TEXT_COLOR), ("!disabled", WHITE_TEXT)],
        )
        style.configure(
            "MiniSecondary.TButton",
            background=SECONDARY_BG,
            foreground=WHITE_TEXT,
            borderwidth=0,
            relief="flat",
            padding=(6, 3),
            font=button_font,
            focusthickness=0,
            focuscolor=SECONDARY_BG,
        )
        style.map(
            "MiniSecondary.TButton",
            background=[("active", SECONDARY_HOVER_BG), ("pressed", SECONDARY_HOVER_BG)],
            foreground=[("disabled", MUTED_TEXT_COLOR), ("!disabled", WHITE_TEXT)],
        )

        style.configure(
            "App.Vertical.TScrollbar",
            background=BORDER_COLOR,
            troughcolor=SURFACE_MUTED_BG,
            relief="flat",
            borderwidth=0,
            arrowsize=13,
        )
        style.map("App.Vertical.TScrollbar", background=[("active", PRIMARY_COLOR)])
        style.configure(
            "App.Horizontal.TScrollbar",
            background=BORDER_COLOR,
            troughcolor=SURFACE_MUTED_BG,
            relief="flat",
            borderwidth=0,
            arrowsize=13,
        )
        style.map("App.Horizontal.TScrollbar", background=[("active", PRIMARY_COLOR)])

        style.configure(
            "TEntry",
            fieldbackground=GRID_ENTRY_BG,
            foreground=TEXT_COLOR,
            insertcolor=TEXT_COLOR,
            bordercolor=BORDER_COLOR,
            lightcolor=BORDER_COLOR,
            darkcolor=BORDER_COLOR,
            padding=5,
            font=base_font,
        )
        style.map(
            "TEntry",
            fieldbackground=[("readonly", GRID_ENTRY_BG), ("disabled", GRID_ENTRY_BG)],
            foreground=[("readonly", TEXT_COLOR), ("disabled", MUTED_TEXT_COLOR)],
        )
        style.configure(
            "TCombobox",
            fieldbackground=GRID_ENTRY_BG,
            background=GRID_ENTRY_BG,
            foreground=TEXT_COLOR,
            arrowcolor=TEXT_COLOR,
            padding=4,
        )

        style.configure(
            "Treeview",
            background=TREE_BG,
            fieldbackground=TREE_BG,
            foreground=TEXT_COLOR,
            rowheight=40,
            relief="flat",
            borderwidth=0,
            font=base_font,
        )
        style.map(
            "Treeview",
            background=[("selected", TREE_SELECTED_BG)],
            foreground=[("selected", WHITE_TEXT)],
        )
        style.configure(
            "Treeview.Heading",
            background=TREE_HEADER_BG,
            foreground=TEXT_COLOR,
            font=heading_font,
            relief="flat",
            padding=(12, 12),
        )
        style.map("Treeview.Heading", background=[("active", PRIMARY_COLOR)])

    def _build_ui(self):
        shell = ttk.Frame(self, style="App.TFrame", padding=(SPACE_6, SPACE_5, SPACE_6, SPACE_5))
        self.shell = shell
        shell.pack(fill="both", expand=True)
        shell.columnconfigure(0, weight=1)
        shell.rowconfigure(2, weight=1)

        hero = ttk.Frame(shell, style="Hero.TFrame", padding=(SPACE_6, SPACE_5, SPACE_6, SPACE_5))
        hero.grid(row=0, column=0, sticky="ew")
        hero.columnconfigure(0, weight=1)
        hero.columnconfigure(1, weight=0)

        ttk.Label(hero, text="Nobet Cizelgesi", style="HeroTitle.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            hero,
            text="Haftalik planlama, rotasyon ve PDF/Excel cikti merkezi",
            style="HeroSub.TLabel",
        ).grid(row=1, column=0, sticky="w", pady=(SPACE_2 - 1, 0))
        ttk.Label(
            hero,
            text=f"Bugun: {date.today().strftime('%d.%m.%Y')}",
            style="HeaderDate.TLabel",
        ).grid(row=0, column=1, rowspan=2, sticky="ne", padx=(SPACE_4, 0))

        ttk.Separator(hero, orient="horizontal").grid(row=2, column=0, columnspan=2, sticky="ew", pady=(SPACE_4, SPACE_4))

        info_strip = ttk.Frame(hero, style="InfoStrip.TFrame", padding=(SPACE_1, SPACE_1, SPACE_1, SPACE_1))
        info_strip.grid(row=3, column=0, columnspan=2, sticky="ew")
        for col in range(3):
            info_strip.columnconfigure(col, weight=1)

        self.info_file_var = tk.StringVar(value="(yok)")
        self.info_week_var = tk.StringVar(value="(baslik yok)")
        self.info_last_var = tk.StringVar(value="(yok)")

        info_cells = [
            ("Dosya", self.info_file_var),
            ("Mevcut Hafta", self.info_week_var),
            ("Son Olusturulan", self.info_last_var),
        ]
        for idx, (label_text, value_var) in enumerate(info_cells):
            cell = tk.Frame(
                info_strip,
                bg=SURFACE_BG,
                bd=0,
                highlightthickness=1,
                highlightbackground=STATUS_CARD_BORDER,
                highlightcolor=STATUS_CARD_BORDER,
                padx=SPACE_3,
                pady=SPACE_2 + 1,
            )
            cell.grid(row=0, column=idx, sticky="ew", padx=(0, SPACE_3) if idx < 2 else (0, 0))
            ttk.Label(cell, text=label_text, style="InfoMeta.TLabel").pack(anchor="w")
            ttk.Label(cell, textvariable=value_var, style="InfoValue.TLabel").pack(anchor="w", pady=(SPACE_1, 0))

        action_area = ttk.Frame(shell, style="App.TFrame")
        action_area.grid(row=1, column=0, sticky="ew", pady=(SPACE_4, SPACE_3))
        action_area.columnconfigure(0, weight=1)
        action_area.columnconfigure(1, weight=1)
        action_area.columnconfigure(2, weight=1)
        action_area.rowconfigure(0, weight=1)
        card_button_gap = SPACE_2 - 2

        def _make_action_card(title: str, subtitle: str, column: int, padx: tuple[int, int]):
            card = ttk.Frame(action_area, style="ActionCard.TFrame", padding=(SPACE_3, SPACE_3, SPACE_3, SPACE_3))
            card.grid(row=0, column=column, sticky="nsew", padx=padx)
            card.columnconfigure(0, weight=1)
            ttk.Label(card, text=title, style="ActionTitle.TLabel").grid(row=0, column=0, sticky="w")
            ttk.Label(card, text=subtitle, style="ActionSub.TLabel").grid(row=1, column=0, sticky="w", pady=(SPACE_1, 0))
            ttk.Separator(card, orient="horizontal").grid(row=2, column=0, sticky="ew", pady=(SPACE_2, SPACE_2))
            return card

        data_card = _make_action_card("Veri", "Kaynak dosya ve hafta duzenleme", 0, (0, SPACE_2))
        data_card.columnconfigure(0, weight=1)
        ttk.Button(data_card, text="Excel Yukle", style="Accent.TButton", command=self.load_excel).grid(
            row=3, column=0, sticky="ew", pady=(0, card_button_gap)
        )
        ttk.Button(data_card, text="Yeni / Hafta Duzenle", style="Accent.TButton", command=self.edit_week).grid(
            row=4, column=0, sticky="ew", pady=(0, card_button_gap)
        )
        ttk.Button(data_card, text="Cikis", style="Exit.TButton", command=self.destroy).grid(row=5, column=0, sticky="ew")

        week_card = _make_action_card("Hafta", "Gecis ve otomatik olusturma", 1, (SPACE_1, SPACE_1))
        week_card.columnconfigure(0, weight=1)
        week_card.columnconfigure(1, weight=1)
        ttk.Button(week_card, text="Onceki Hafta", style="Secondary.TButton", command=self.generate_previous).grid(
            row=3, column=0, sticky="ew", padx=(0, SPACE_1), pady=(0, card_button_gap)
        )
        ttk.Button(week_card, text="Sonraki Hafta", style="Secondary.TButton", command=self.generate_next).grid(
            row=3, column=1, sticky="ew", padx=(SPACE_1, 0), pady=(0, card_button_gap)
        )
        ttk.Button(week_card, text="Tarih Araliginda Olustur", style="Accent.TButton", command=self.generate_range_outputs).grid(
            row=4, column=0, columnspan=2, sticky="ew", pady=(0, card_button_gap)
        )
        ttk.Button(week_card, text="Aylik Olustur", style="Accent.TButton", command=self.generate_month).grid(
            row=5, column=0, columnspan=2, sticky="ew"
        )

        output_card = _make_action_card("Cikti", "PDF ve Excel disa aktarma", 2, (SPACE_2, 0))
        output_card.columnconfigure(0, weight=1)
        ttk.Button(output_card, text="PDF Disa Aktar", style="Accent.TButton", command=self.export_pdf).grid(
            row=3, column=0, sticky="ew", pady=(0, card_button_gap)
        )
        ttk.Button(output_card, text="Excel'i Farkli Kaydet", style="Secondary.TButton", command=self.save_excel_as).grid(
            row=4, column=0, sticky="ew"
        )

        table_card = ttk.Frame(shell, style="TableCard.TFrame", padding=(SPACE_4, SPACE_4, SPACE_4, SPACE_3))
        table_card.grid(row=2, column=0, sticky="nsew")
        table_card.columnconfigure(0, weight=1)
        table_card.rowconfigure(2, weight=1)

        self.preview_title_var = tk.StringVar(value="Hafta Onizleme")
        self.preview_meta_var = tk.StringVar(value="")
        self.preview_toggle_var = tk.StringVar(value="Onizlemeyi Gizle")
        header_row = ttk.Frame(table_card, style="TableCard.TFrame")
        header_row.grid(row=0, column=0, sticky="ew")
        header_row.columnconfigure(0, weight=1)
        ttk.Label(header_row, textvariable=self.preview_title_var, style="SectionTitle.TLabel").grid(
            row=0, column=0, sticky="w"
        )
        ttk.Label(header_row, textvariable=self.preview_meta_var, style="TableMeta.TLabel").grid(
            row=0, column=1, sticky="e"
        )
        ttk.Button(
            header_row,
            textvariable=self.preview_toggle_var,
            style="Secondary.TButton",
            command=self._toggle_preview,
        ).grid(row=0, column=2, sticky="e", padx=(SPACE_3, 0))
        self.preview_separator = ttk.Separator(table_card, orient="horizontal")
        self.preview_separator.grid(row=1, column=0, sticky="ew", pady=(SPACE_3, SPACE_3))

        self.table_card = table_card
        self.preview_table_wrap = ttk.Frame(table_card, style="TableCard.TFrame")
        self.preview_table_wrap.grid(row=2, column=0, sticky="nsew")
        self.preview_table_wrap.columnconfigure(0, weight=1)
        self.preview_table_wrap.rowconfigure(0, weight=1)

        self.tree = ttk.Treeview(
            self.preview_table_wrap,
            columns=["Location"] + DAY_NAMES,
            show="headings",
            height=PREVIEW_MIN_VISIBLE_ROWS,
        )
        self.tree.grid(row=0, column=0, sticky="nsew")
        y_scroll = ttk.Scrollbar(self.preview_table_wrap, orient="vertical", style="App.Vertical.TScrollbar", command=self.tree.yview)
        y_scroll.grid(row=0, column=1, sticky="ns")
        x_scroll = ttk.Scrollbar(self.preview_table_wrap, orient="horizontal", style="App.Horizontal.TScrollbar", command=self.tree.xview)
        x_scroll.grid(row=1, column=0, sticky="ew")
        self.tree.configure(yscrollcommand=y_scroll.set, xscrollcommand=x_scroll.set)
        self.tree.bind("<Double-1>", self._begin_preview_cell_edit)
        self.tree.bind("<MouseWheel>", self._on_preview_mousewheel)
        self.tree.bind("<Button-4>", self._on_preview_mousewheel)
        self.tree.bind("<Button-5>", self._on_preview_mousewheel)

        self.tree.heading("Location", text="Gorev Yeri", anchor="w")
        self.tree.column("Location", width=MAIN_TREE_LOCATION_WIDTH, anchor="w", stretch=True)
        for day in DAY_NAMES:
            self.tree.heading(day, text=day.title(), anchor="center")
            self.tree.column(day, width=MAIN_TREE_DAY_WIDTH, anchor="center", stretch=True)

        self.tree.tag_configure("row_even", background=TREE_BG)
        self.tree.tag_configure("row_odd", background=TREE_ALT_ROW_BG)
        self.tree.tag_configure(
            "week_header",
            background=WEEK_HEADER_BG,
            foreground=TEXT_COLOR,
            font=FONT_BOLD,
        )
        self.tree.tag_configure("week_spacer", background=APP_BG)

        self._update_info_label()

    def _toggle_preview(self):
        visible = not self.preview_visible_var.get()
        self.preview_visible_var.set(visible)
        self.preview_toggle_var.set("Onizlemeyi Gizle" if visible else "Onizlemeyi Goster")
        if visible:
            self.preview_separator.grid()
            self.preview_table_wrap.grid()
            self.table_card.grid_configure(sticky="nsew")
            self.shell.rowconfigure(2, weight=1)
        else:
            self.preview_separator.grid_remove()
            self.preview_table_wrap.grid_remove()
            self.table_card.grid_configure(sticky="ew")
            self.shell.rowconfigure(2, weight=0)

    def _on_preview_mousewheel(self, event):
        if hasattr(event, "num") and event.num in (4, 5):
            direction = -1 if event.num == 4 else 1
        else:
            direction = -1 if event.delta > 0 else 1
        self.tree.yview_scroll(direction * max(1, self._preview_scroll_rows), "units")
        return "break"

    def _begin_preview_cell_edit(self, event):
        item = self.tree.identify_row(event.y)
        column = self.tree.identify_column(event.x)
        if not item or not column:
            return
        cell_info = self._preview_item_map.get(item)
        if not cell_info:
            return
        try:
            col_idx = int(column.replace("#", "")) - 1
        except ValueError:
            return
        if col_idx < 0 or col_idx > MAIN_TABLE_DAY_COUNT:
            return
        bbox = self.tree.bbox(item, column)
        if not bbox:
            return

        self._close_preview_editor()
        x, y, width, height = bbox
        columns = ["Location"] + DAY_NAMES
        column_name = columns[col_idx]
        entry = ttk.Entry(self.tree)
        entry.insert(0, str(self.tree.set(item, column_name) or ""))
        entry.select_range(0, "end")
        entry.focus_set()
        entry.place(x=x, y=y, width=width, height=height)
        self._preview_editor = {
            "entry": entry,
            "item": item,
            "column": column_name,
            "column_index": col_idx,
            "cell_info": cell_info,
        }
        entry.bind("<Return>", lambda _event: self._commit_preview_cell_edit())
        entry.bind("<FocusOut>", lambda _event: self._commit_preview_cell_edit())
        entry.bind("<Escape>", lambda _event: self._close_preview_editor())

    def _close_preview_editor(self):
        if self._preview_editor:
            entry = self._preview_editor.get("entry")
            if entry and entry.winfo_exists():
                entry.destroy()
        self._preview_editor = None

    def _commit_preview_cell_edit(self):
        editor = self._preview_editor
        if not editor:
            return
        entry = editor["entry"]
        if not entry.winfo_exists():
            self._preview_editor = None
            return
        value = entry.get().strip()
        item = editor["item"]
        col_idx = editor["column_index"]
        cell_info = editor["cell_info"]
        self.tree.set(item, editor["column"], value)
        self._close_preview_editor()

        week_idx = cell_info["week_index"]
        row_idx = cell_info["row_index"]
        if week_idx >= len(self.preview_weeks):
            return
        week = self.preview_weeks[week_idx]
        self._ensure_preview_week_row(week, row_idx)
        if col_idx == 0:
            week["locations"][row_idx] = value
        else:
            week["roster"][row_idx][col_idx - 1] = value
        self._sync_preview_edits()

    def _ensure_preview_week_row(self, week, row_idx: int):
        locations = week.setdefault("locations", [])
        roster = week.setdefault("roster", [])
        while len(locations) <= row_idx:
            locations.append("")
        while len(roster) <= row_idx:
            roster.append(_empty_day_row())
        while len(roster[row_idx]) < MAIN_TABLE_DAY_COUNT:
            roster[row_idx].append("")

    def _sync_preview_edits(self):
        self._update_info_label()

    def _update_info_label(self):
        title = self.current_title or "(baslik yok)"
        path = Path(self.workbook_path).name if self.workbook_path else "(yok)"
        preview_weeks = self._preview_weeks_for_export()
        week_label = self._format_preview_summary(preview_weeks) if preview_weeks else title
        if self.last_output and isinstance(self.last_output, dict):
            last = str(self.last_output.get("label", "") or "").strip() or "(yok)"
        elif self.last_generated:
            last = str(self.last_generated.get("title", "") or "").strip() or "(yok)"
        else:
            last = "(yok)"
        self.info_file_var.set(_ellipsize_middle(path, 34))
        self.info_week_var.set(_ellipsize_middle(week_label, 56))
        self.info_last_var.set(_ellipsize_middle(last, 56))

    def _refresh_preview(self):
        self._close_preview_editor()
        self._preview_item_map = {}
        for item in self.tree.get_children():
            self.tree.delete(item)

        preview_weeks = []
        for week in self.month_generated or []:
            if isinstance(week, dict) and str(week.get("title", "") or "").strip():
                preview_weeks.append(_copy_week(week))

        if (
            not preview_weeks
            and self.current_start
            and self.current_end
            and self.locations
            and self.roster
        ):
            # If user sets a wider date range in edit mode, build multi-week preview on the fly.
            auto_weeks = self._build_weeks_for_output_range(self.current_start, self.current_end)
            if auto_weeks:
                preview_weeks = auto_weeks

        if not preview_weeks and (self.current_title or self.locations or self.roster):
            preview_weeks.append(
                _copy_week({
                    "title": self.current_title or "",
                    "start_date": self.current_start.isoformat() if self.current_start else "",
                    "end_date": self.current_end.isoformat() if self.current_end else "",
                    "school_name": self.school_name,
                    "principal_name": self.principal_name,
                    "locations": self.locations,
                    "roster": self.roster,
                })
            )

        week_count = len(preview_weeks)
        self.preview_weeks = _copy_weeks(preview_weeks)
        preview_weeks = self.preview_weeks
        if week_count == 0:
            self.preview_weeks = []
            self.tree.configure(height=PREVIEW_MIN_VISIBLE_ROWS)
            self._preview_scroll_rows = PREVIEW_MIN_VISIBLE_ROWS
            self.preview_title_var.set("Hafta Onizleme")
            self.preview_meta_var.set("Veri bekleniyor")
            return
        first_week_rows = 1 + len(list(preview_weeks[0].get("locations", []) or []))
        visible_rows = max(PREVIEW_MIN_VISIBLE_ROWS, min(PREVIEW_MAX_VISIBLE_ROWS, first_week_rows))
        self.tree.configure(height=visible_rows)
        self._preview_scroll_rows = first_week_rows + (1 if week_count > 1 else 0)
        if week_count == 1:
            only = preview_weeks[0]
            start_text = _format_iso_date(str(only.get("start_date", "") or ""))
            end_text = _format_iso_date(str(only.get("end_date", "") or ""))
            self.preview_title_var.set("Hafta Onizleme")
            if start_text and end_text:
                self.preview_meta_var.set(f"{start_text} - {end_text}")
            else:
                self.preview_meta_var.set("1 hafta")
        else:
            first_start = _format_iso_date(str(preview_weeks[0].get("start_date", "") or ""))
            last_end = _format_iso_date(str(preview_weeks[-1].get("end_date", "") or ""))
            self.preview_title_var.set("Hafta Onizleme")
            if first_start and last_end:
                self.preview_meta_var.set(f"{week_count} hafta  |  {first_start} - {last_end}")
            else:
                self.preview_meta_var.set(f"{week_count} hafta")

        row_counter = 0
        for week_idx, week in enumerate(preview_weeks, start=1):
            start_text = _format_iso_date(str(week.get("start_date", "") or ""))
            end_text = _format_iso_date(str(week.get("end_date", "") or ""))
            title = str(week.get("title", "") or "").strip()
            if start_text and end_text:
                header_text = f"Hafta {week_idx}  |  {start_text} - {end_text}"
                if title:
                    header_text = f"{header_text}  |  {title}"
            else:
                header_text = f"Hafta {week_idx}  |  {title or '(Baslik yok)'}"

            self.tree.insert("", "end", values=[header_text, "", "", "", "", ""], tags=("week_header",))
            row_counter += 1

            locations = list(week.get("locations", []) or [])
            roster = list(week.get("roster", []) or [])
            for idx, location in enumerate(locations):
                row_vals = roster[idx] if idx < len(roster) else _empty_day_row()
                tag = "row_even" if row_counter % 2 == 0 else "row_odd"
                item = self.tree.insert("", "end", values=[location] + row_vals, tags=(tag,))
                self._preview_item_map[item] = {"week_index": week_idx - 1, "row_index": idx}
                row_counter += 1

            if week_idx < week_count:
                self.tree.insert("", "end", values=["", "", "", "", "", ""], tags=("week_spacer",))
                row_counter += 1

    def _persist(self):
        state = {
            "workbook_path": self.workbook_path,
            "year": self.year,
            "current_title": self.current_title,
            "current_start_date": self.current_start.isoformat() if self.current_start else "",
            "current_end_date": self.current_end.isoformat() if self.current_end else "",
            "school_name": self.school_name,
            "principal_name": self.principal_name,
            "locations": list(self.locations or []),
            "roster": _copy_roster_rows(self.roster),
            "last_generated": _copy_week(self.last_generated) if self.last_generated else None,
            "last_output": dict(self.last_output) if isinstance(self.last_output, dict) else self.last_output,
            "month_generated": _copy_weeks(self.month_generated),
        }
        save_state(state)

    def _require_dates(self) -> bool:
        if not self.current_start or not self.current_end:
            messagebox.showwarning("Eksik Tarih", "Lutfen Yeni/Hafta Duzenle ekranindan mevcut hafta tarihlerini girin.")
            return False
        return True

    def _require_roster_data(self) -> bool:
        if not self.roster or not self.locations:
            messagebox.showwarning("Eksik Cizelge", "Lutfen once mevcut hafta cizelgesini girin.")
            return False
        return True

    def _parse_range_dates(self, start_val: str, end_val: str) -> tuple[date, date]:
        year = self._ensure_year()
        start_date = parse_date_input(start_val, year) if start_val else None
        end_date = parse_date_input(end_val, year) if end_val else None
        if not start_date or not end_date:
            raise ValueError("Baslangic ve bitis tarihi zorunlu.")
        if start_date > end_date:
            raise ValueError("Baslangic tarihi bitis tarihinden buyuk olamaz.")
        return start_date, end_date

    def _set_current_week(self, start_date: date, end_date: date, roster_data: Optional[List[List[str]]] = None):
        if roster_data is None:
            roster_data = _copy_roster_rows(self.roster)
        self.current_start = start_date
        self.current_end = end_date
        self.current_title = build_title(start_date, end_date)
        self.roster = _copy_roster_rows(roster_data)
        self.last_generated = _copy_week({
            "title": self.current_title,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "school_name": self.school_name,
            "principal_name": self.principal_name,
            "locations": self.locations,
            "roster": self.roster,
        })
        self.month_generated = []
        self._update_info_label()
        self._refresh_preview()
        self._persist()

    def _build_month_in_range(self, start_date: date, end_date: date, table_count: int = 4) -> List[dict]:
        if table_count <= 0:
            return []

        if self.current_start and self.current_end:
            span_days = max(0, (self.current_end - self.current_start).days)
        else:
            span_days = 4

        generated: List[dict] = []
        week = build_week(
            start_date,
            start_date + timedelta(days=span_days),
            self.locations,
            self.roster,
            self.school_name,
            self.principal_name,
        )

        while len(generated) < table_count:
            week_end = date.fromisoformat(week["end_date"])
            if week_end > end_date:
                break
            generated.append(_copy_week(week))
            week = build_next_week(
                date.fromisoformat(week["start_date"]),
                week_end,
                week["locations"],
                week["roster"],
                week["school_name"],
                week["principal_name"],
            )

        while len(generated) < table_count:
            generated.append(
                {
                    "title": "",
                    "start_date": "",
                    "end_date": "",
                    "school_name": "",
                    "principal_name": "",
                    "locations": [],
                    "roster": [],
                }
            )

        return generated

    def load_excel(self):
        path = filedialog.askopenfilename(
            title="Excel Dosyasi Sec",
            filetypes=EXCEL_FILE_TYPES,
        )
        if not path:
            return
        try:
            year = self._ensure_year()
            data = load_last_week(path, year)
        except Exception as e:
            messagebox.showerror(
                "Excel Yukleme Hatasi",
                _turkish_error_message(e, "Excel dosyasi okunamadi. Beklenen format algilanamadiysa manuel kurulum yapin."),
            )
            return

        self.workbook_path = path
        self.current_title = data["title"]
        self.current_start = data["start_date"]
        self.current_end = data["end_date"]
        self.school_name = data.get("school_name", "")
        self.principal_name = data.get("principal_name", "")
        data_locations = data.get("locations", [])
        self.locations = list(data_locations) if isinstance(data_locations, (list, tuple)) else []
        self.roster = _copy_roster_rows(data.get("roster", []))
        self.month_generated = []

        self._update_info_label()
        self._refresh_preview()
        self._persist()

    def _on_edit_window_destroy(self, event, win):
        if event.widget is win:
            self.edit_window = None

    def edit_week(self):
        if self.edit_window and self.edit_window.winfo_exists():
            self.edit_window.lift()
            self.edit_window.focus_force()
            return

        start_str = self.current_start.isoformat() if self.current_start else ""
        end_str = self.current_end.isoformat() if self.current_end else ""
        school_str = self.school_name or ""
        principal_str = self.principal_name or ""

        def on_save(start_val, end_val, school_val, principal_val, locations, roster):
            try:
                year = self._ensure_year()
                start_date = parse_date_input(start_val, year) if start_val else self.current_start
                end_date = parse_date_input(end_val, year) if end_val else self.current_end
            except Exception:
                messagebox.showerror("Dogrulama", "Gecersiz tarih bicimi.")
                return
            if start_date and end_date and start_date > end_date:
                messagebox.showerror("Dogrulama", "Baslangic tarihi bitis tarihinden buyuk olamaz.")
                return

            self.school_name = school_val
            self.principal_name = principal_val
            self.locations = list(locations or [])
            self.roster = _copy_roster_rows(roster)
            self.current_start = start_date
            self.current_end = end_date
            if self.current_start and self.current_end:
                self.current_title = build_title(self.current_start, self.current_end)
            self.month_generated = []
            self._update_info_label()
            self._refresh_preview()
            self._persist()

        win = EditWindow(self, self.locations, self.roster, start_str, end_str, school_str, principal_str, on_save)
        self.edit_window = win
        win.transient(self)
        win.grab_set()
        win.focus_set()
        win.bind("<Destroy>", lambda event, ref=win: self._on_edit_window_destroy(event, ref))

    def open_range_generate_window(self):
        start_str = self.current_start.isoformat() if self.current_start else ""
        end_str = self.current_end.isoformat() if self.current_end else ""
        RangeGenerateWindow(
            self,
            start_str,
            end_str,
            self.apply_input_dates,
            self.generate_month_in_range,
            self.generate_next_in_range,
        )

    def _build_weeks_for_output_range(self, range_start: date, range_end: date) -> List[dict]:
        generated: List[dict] = []
        week = build_week(
            range_start,
            range_start + timedelta(days=WEEK_SPAN_DAYS),
            self.locations,
            self.roster,
            self.school_name,
            self.principal_name,
        )

        while True:
            week_end = date.fromisoformat(week["end_date"])
            if week_end > range_end:
                break
            generated.append(_copy_week(week))
            week = build_next_week(
                date.fromisoformat(week["start_date"]),
                week_end,
                week["locations"],
                week["roster"],
                week["school_name"],
                week["principal_name"],
            )

        return generated

    def _default_output_dir(self) -> Path:
        if self.workbook_path:
            source_path = Path(self.workbook_path)
            if source_path.exists():
                return source_path.parent

        docs = Path.home() / "Documents"
        if docs.exists():
            return docs
        return Path.home()

    def _ask_output_dir(self, title: str) -> Optional[Path]:
        selected = filedialog.askdirectory(
            title=title,
            initialdir=str(self._default_output_dir()),
            mustexist=True,
        )
        if not selected:
            return None
        return Path(selected)

    def _existing_workbook_source(self) -> Optional[str]:
        """
        Return workbook path only when the file exists on disk.
        """
        if not self.workbook_path:
            return None
        source_path = Path(self.workbook_path)
        return str(source_path) if source_path.exists() else None

    def _apply_preview_weeks(self, generated: List[dict]) -> None:
        """
        Persist generated preview set and refresh UI summary/preview widgets.
        """
        self.month_generated = _copy_weeks(generated)
        valid_generated = [week for week in self.month_generated if str((week or {}).get("title", "") or "").strip()]
        if valid_generated:
            self.last_generated = _copy_week(valid_generated[-1])
        self._refresh_preview()
        self._update_info_label()
        self._persist()

    def _set_last_output(self, output_kind: str, label: str, path: str) -> None:
        """
        Track latest exported artifact for header status cards.
        """
        self.last_output = {
            "label": f"{output_kind} | {label}",
            "path": str(path),
            "date": date.today().isoformat(),
        }
        self._update_info_label()
        self._persist()

    def _export_weeks_snapshot(self) -> List[dict]:
        weeks: List[dict] = []
        for week in _copy_weeks(self.month_generated):
            if isinstance(week, dict) and str(week.get("title", "") or "").strip():
                weeks.append(week)
        if weeks:
            return weeks
        if self.current_title and (self.locations or self.roster):
            return [
                _copy_week({
                    "title": self.current_title,
                    "start_date": self.current_start.isoformat() if self.current_start else "",
                    "end_date": self.current_end.isoformat() if self.current_end else "",
                    "school_name": self.school_name,
                    "principal_name": self.principal_name,
                    "locations": self.locations,
                    "roster": self.roster,
                })
            ]
        return weeks

    def _preview_weeks_for_export(self) -> List[dict]:
        return self._export_weeks_snapshot()

    def _format_preview_summary(self, weeks: List[dict]) -> str:
        if not weeks:
            return ""
        if len(weeks) == 1:
            one_title = str(weeks[0].get("title", "") or "").strip()
            if one_title:
                return one_title
        start_text = _format_iso_date(str(weeks[0].get("start_date", "") or ""))
        end_text = _format_iso_date(str(weeks[-1].get("end_date", "") or ""))
        if start_text and end_text:
            return f"Onizleme: {len(weeks)} hafta ({start_text} - {end_text})"
        return f"Onizleme: {len(weeks)} hafta"

    def generate_range_outputs(self):
        if self.edit_window and self.edit_window.winfo_exists():
            messagebox.showwarning(
                "Kaydet Gerekli",
                "Yeni/Hafta Duzenle penceresi acik. Once Kaydet'e basin.",
            )
            self.edit_window.lift()
            self.edit_window.focus_force()
            return

        if not self._require_dates() or not self._require_roster_data():
            return

        range_start = self.current_start
        range_end = self.current_end
        if range_start > range_end:
            messagebox.showerror("Dogrulama", "Baslangic tarihi bitis tarihinden buyuk olamaz.")
            return

        generated = self._build_weeks_for_output_range(range_start, range_end)
        if not generated:
            messagebox.showwarning(
                "Aralik Bos",
                "Secilen aralikta olusturulacak tam hafta bulunamadi (en az 5 gun gerekli).",
            )
            return

        # Tarih araliginda olustur sadece onizleme hazirlar; cikti sag panelden manuel alinir.
        self._apply_preview_weeks(generated)

        messagebox.showinfo(
            "Tarih Araliginda Olustur",
            f"{len(generated)} haftalik onizleme hazirlandi.\n\n"
            "Cikti almak isterseniz sag panelden manuel olarak disa aktarabilirsiniz.",
        )

    def apply_input_dates(self, start_val: str, end_val: str):
        if not self._require_roster_data():
            return
        try:
            start_date, end_date = self._parse_range_dates(start_val, end_val)
        except Exception:
            messagebox.showerror("Dogrulama", "Gecersiz tarih araligi.")
            return
        self._set_current_week(start_date, end_date, self.roster)

    def generate_next_in_range(self, start_val: str, end_val: str):
        if not self._require_dates() or not self._require_roster_data():
            return
        try:
            range_start, range_end = self._parse_range_dates(start_val, end_val)
        except Exception:
            messagebox.showerror("Dogrulama", "Gecersiz tarih araligi.")
            return

        next_week = build_next_week(
            self.current_start,
            self.current_end,
            self.locations,
            self.roster,
            self.school_name,
            self.principal_name,
        )
        next_start = date.fromisoformat(next_week["start_date"])
        next_end = date.fromisoformat(next_week["end_date"])
        if next_start < range_start or next_end > range_end:
            messagebox.showwarning(
                "Aralik Disi",
                "Sonraki hafta, girdiginiz tarih araliginin disina ciktigi icin olusturulmadi.",
            )
            return
        self._set_current_week(next_start, next_end, next_week["roster"])

    def generate_month_in_range(self, start_val: str, end_val: str):
        if not self._require_roster_data():
            return
        try:
            start_date, end_date = self._parse_range_dates(start_val, end_val)
        except Exception:
            messagebox.showerror("Dogrulama", "Gecersiz tarih araligi.")
            return

        generated = self._build_month_in_range(start_date, end_date, table_count=4)
        real_weeks = [w for w in generated if w["title"]]
        if not real_weeks:
            messagebox.showwarning("Aralik Bos", "Bu tarih araliginda olusturulacak tam hafta bulunamadi.")
            return

        self._apply_preview_weeks(generated)

        blank_count = len([w for w in generated if not w["title"]])
        messagebox.showinfo(
            "Aylik Olustur",
            f"Tarih araliginda {len(real_weeks)} hafta olusturuldu. Bos tablo sayisi: {blank_count}.",
        )

    def generate_previous(self):
        if not self._require_dates() or not self._require_roster_data():
            return

        prev_roster = rotate_roster_back(self.roster)
        prev_start = self.current_start - timedelta(days=7)
        prev_end = self.current_end - timedelta(days=7)
        self._set_current_week(prev_start, prev_end, prev_roster)

    def generate_next(self):
        if not self._require_dates() or not self._require_roster_data():
            return

        next_week = build_next_week(
            self.current_start,
            self.current_end,
            self.locations,
            self.roster,
            self.school_name,
            self.principal_name,
        )
        next_start = date.fromisoformat(next_week["start_date"])
        next_end = date.fromisoformat(next_week["end_date"])
        self._set_current_week(next_start, next_end, next_week["roster"])

    def generate_month(self):
        if not self._require_dates() or not self._require_roster_data():
            return

        generated = []
        week = build_week(
            self.current_start,
            self.current_start + timedelta(days=WEEK_SPAN_DAYS),
            self.locations,
            self.roster,
            self.school_name,
            self.principal_name,
        )

        for _ in range(4):
            generated.append(_copy_week(week))
            week = build_next_week(
                date.fromisoformat(week["start_date"]),
                date.fromisoformat(week["end_date"]),
                week["locations"],
                week["roster"],
                week["school_name"],
                week["principal_name"],
            )

        # Aylik olustur sadece onizleme hazirlar; dosya ciktilari manuel disa aktarimla alinir.
        self._apply_preview_weeks(generated)
        messagebox.showinfo(
            "Aylik Olustur",
            "4 haftalik onizleme hazirlandi.\n\n"
            "Cikti almak isterseniz sag panelden manuel olarak disa aktarabilirsiniz.",
        )

    def export_pdf(self):
        export_weeks = self._export_weeks_snapshot()
        if len(export_weeks) >= 2:
            first_start = str(export_weeks[0].get("start_date", "") or "").strip()
            last_end = str(export_weeks[-1].get("end_date", "") or "").strip()
            range_name = f"nobet_{first_start}_{last_end}.pdf" if first_start and last_end else DEFAULT_PDF_FILENAME
            path = filedialog.asksaveasfilename(
                title="PDF Dosyasini Kaydet",
                defaultextension=".pdf",
                filetypes=PDF_FILE_TYPES,
                initialfile=range_name,
            )
            if not path:
                return
            try:
                export_weeks_pdf(path, export_weeks)
            except Exception as e:
                messagebox.showerror("PDF Disa Aktarma Hatasi", _turkish_error_message(e, "PDF olusturulurken bir hata olustu."))
                return
            self._set_last_output("PDF", self._format_preview_summary(export_weeks), path)
            messagebox.showinfo("PDF Disa Aktar", f"PDF basariyla olusturuldu:\n{path}\n\nHafta sayisi: {len(export_weeks)}")
            return

        if not export_weeks:
            messagebox.showwarning("Veri Yok", "Once hafta uretin veya duzenleyin.")
            return
        week = export_weeks[0]

        path = filedialog.asksaveasfilename(
            title="PDF Dosyasini Kaydet",
            defaultextension=".pdf",
            filetypes=PDF_FILE_TYPES,
            initialfile=DEFAULT_PDF_FILENAME,
        )
        if not path:
            return

        try:
            export_week_pdf(
                path,
                str(week.get("title", "") or ""),
                list(week.get("locations", []) or []),
                _copy_roster_rows(week.get("roster", []) or []),
                str(week.get("school_name", "") or self.school_name),
                str(week.get("principal_name", "") or self.principal_name),
            )
        except Exception as e:
            messagebox.showerror("PDF Disa Aktarma Hatasi", _turkish_error_message(e, "PDF olusturulurken bir hata olustu."))
            return

        self._set_last_output("PDF", self._format_preview_summary(export_weeks), path)
        messagebox.showinfo("PDF Disa Aktar", f"PDF basariyla olusturuldu:\n{path}")

    def save_excel_as(self):
        export_weeks = self._export_weeks_snapshot()
        if len(export_weeks) >= 2:
            initial_dir = str(Path(self.workbook_path).parent) if self.workbook_path else None
            first_start = str(export_weeks[0].get("start_date", "") or "").strip()
            last_end = str(export_weeks[-1].get("end_date", "") or "").strip()
            range_name = f"nobet_{first_start}_{last_end}.xlsx" if first_start and last_end else DEFAULT_EXCEL_FILENAME
            path = filedialog.asksaveasfilename(
                title="Excel Dosyasini Kaydet",
                defaultextension=".xlsx",
                filetypes=EXCEL_FILE_TYPES,
                initialdir=initial_dir,
                initialfile=range_name,
            )
            if not path:
                return

            workbook_source = self._existing_workbook_source()
            try:
                write_weeks_to_excel(workbook_source, export_weeks, path)
            except Exception as e:
                messagebox.showerror(
                    "Excel Kaydetme Hatasi",
                    _turkish_error_message(e, "Excel dosyasi kaydedilirken bir hata olustu."),
                )
                return
            self._set_last_output("Excel", self._format_preview_summary(export_weeks), path)
            messagebox.showinfo("Excel Kaydet", f"Excel basariyla kaydedildi:\n{path}\n\nHafta sayisi: {len(export_weeks)}")
            return

        if not export_weeks:
            messagebox.showwarning("Veri Yok", "Once hafta uretin veya duzenleyin.")
            return
        week = export_weeks[0]

        initial_dir = str(Path(self.workbook_path).parent) if self.workbook_path else None
        path = filedialog.asksaveasfilename(
            title="Excel Dosyasini Kaydet",
            defaultextension=".xlsx",
            filetypes=EXCEL_FILE_TYPES,
            initialdir=initial_dir,
            initialfile=DEFAULT_EXCEL_FILENAME,
        )
        if not path:
            return

        try:
            write_week_to_excel(
                self.workbook_path,
                str(week.get("title", "") or ""),
                list(week.get("locations", []) or []),
                _copy_roster_rows(week.get("roster", []) or []),
                path,
                school_name=str(week.get("school_name", "") or self.school_name),
                principal_name=str(week.get("principal_name", "") or self.principal_name),
            )
        except Exception as e:
            messagebox.showerror(
                "Excel Kaydetme Hatasi",
                _turkish_error_message(e, "Excel dosyasi kaydedilirken bir hata olustu."),
            )
            return

        self._set_last_output("Excel", self._format_preview_summary(export_weeks), path)
        messagebox.showinfo("Excel Kaydet", f"Excel basariyla kaydedildi:\n{path}")


def run_app():
    app = App()
    app.mainloop()


