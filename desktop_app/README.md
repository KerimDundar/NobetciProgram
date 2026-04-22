# Teacher Duty Roster Generator (Tkinter)

A simple desktop app (Python 3.11+) for creating weekly teacher duty roster tables, rotating teacher names weekly, and exporting the newest week to Excel and PDF.

## Features
- Load an Excel file and detect the last weekly block as the current roster.
- Edit the current week in a grid (locations + day columns).
- Rotate teacher names per day column, preserving empty slots.
- Append the generated week to Excel and export a clean single-page PDF.
- Persist app state in `%LOCALAPPDATA%\NobetCizelgesi\app_state.json`.

## Setup (Developer)

```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

## Run

```bash
python main.py
```

## Build Windows Setup Wizard (setup.exe)

PowerShell:

```powershell
.\build_installer.ps1 -Version 1.0.0 -InstallInnoSetup
```

This command:
- Creates a clean `.venv` with Python 3.11 via `uv`
- Installs app dependencies and `pyinstaller`
- Builds `dist\NobetCizelgesi.exe` (standalone; Python is not required on target PC)
- Builds `dist\installer\NobetCizelgesi-Setup-<version>.exe` with Inno Setup

## Notes
- Excel format expected:
  - Column A contains a title line with `HAFTASI NOBETCI OGRETMEN LISTESI`.
  - Next row has day headers in columns B-F: `PAZARTESI, SALI, CARSAMBA, PERSEMBE, CUMA`.
  - Following rows are locations in column A and teacher names in columns B-F.
  - Blank rows may separate week blocks.

If the file format does not match, the app will show an error and you can set up the roster manually.
