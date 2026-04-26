# Problem Set — Implementation Plan

## Pre-Analysis: Current State

| # | Problem | Durum |
|---|---|---|
| 1 | PDF footer format | ✅ DONE — kod zaten `cleanName` sonra `'Müdür'` render ediyor |
| 2 | Nav icons ←/→ → ↑/↓ | ❌ MISSING |
| 3 | Per-row independent day rotation | ⚠️ PARTIAL — day-column rotation var, per-row yok |
| 4 | Hafta özeti kaldır | ❌ MISSING — `_SelectedDayBanner` line 360 roster_home_screen.dart |
| 5 | Weekly/Monthly planning mode | ❌ MISSING — major feature |
| 6 | Manual teacher input kaldır | ✅ DONE — zaten sadece picker var |
| 7 | Multi-teacher + "nerede görevli" | ⚠️ PARTIAL — multi-teacher done, info icon missing |

---

## Phase A — Quick UI Fixes (no data model changes)
**Dependency:** none | **Risk:** low | **Files:** roster_home_screen.dart, teacher_list_screen.dart

### A1 — Navigation icon change (Problem 2)
- roster_home_screen.dart: `goToPreviousWeek` butonunu `Icons.arrow_upward`, `goToNextWeek` butonunu `Icons.arrow_downward` yap
- Validation: widget_test.dart smoke, flutter analyze

### A2 — Remove _SelectedDayBanner (Problem 4)
- roster_home_screen.dart line 284–289: `_SelectedDayBanner` widget çağrısını kaldır
- roster_home_screen.dart line 360–410: `_SelectedDayBanner` class'ını sil
- Validation: widget_test.dart, flutter analyze

### A3 — "Nerede görevli" info icon (Problem 7 remainder)
- teacher_list_screen.dart: her teacher satırına `InfoButton` ekle
- Tap → bottom sheet: o teacher'ın hangi `rowIndex` ve `dayIndex` kombinasyonlarında atandığını listele
- Kaynak: `TeacherAssignmentLookupService` zaten mevcut — `lib/services/teacher_assignment_lookup_service.dart` kullan
- Validation: teacher_list_screen_test.dart, flutter analyze

**Phase A Validation:**
```
flutter test test/widget_test.dart test/teacher_list_screen_test.dart
flutter analyze
```

---

## Phase B — Per-Row Day Rotation (Problem 3)
**Dependency:** Phase A tamamlanmış | **Risk:** medium | **Files:** roster_service.dart, roster_state.dart, edit_week_screen.dart

**Recommended mobile UX:** Her row için seçili gün kolonunda ↑/↓ buton çifti. `ReorderableListView` stretch goal (Phase B sonrası opsiyonel).

### B1 — Service layer: per-row rotation API
- `lib/services/roster_service.dart`: `moveRowUp(rows, rowIndex, dayIndex)` ve `moveRowDown(rows, rowIndex, dayIndex)` ekle
  - Sadece `dayIndex` kolonunda `rowIndex` ile komşusunu swap eder
  - `rowIndex == 0` için up → no-op; `rowIndex == rows.length-1` için down → no-op
- `lib/state/roster_state.dart`: `moveRowUpInDay(rowIndex, dayIndex)` ve `moveRowDownInDay(rowIndex, dayIndex)` expose et
- Unit test: `test/core_logic_test.dart` — edge cases: first row up, last row down, empty cell swap

### B2 — UI: per-row ↑/↓ buttons in edit screen
- `lib/ui/screens/edit_week_screen.dart`: grid row card'ına (selected day view) her satır için `IconButton(Icons.arrow_upward)` ve `IconButton(Icons.arrow_downward)` ekle
- Buttons call `moveRowUpInDay` / `moveRowDownInDay` with current rowIndex and `_selectedGridDayIndex`
- Mevcut "rotate all" butonunu KORU (day-column rotation), per-row butonlar buna ek olarak gelir
- Validation: edit_teacher_picker_integration_test.dart, widget_test.dart

**Phase B Validation:**
```
flutter test test/core_logic_test.dart test/widget_test.dart
flutter analyze
```

---

## Phase C — Weekly/Monthly Planning Mode (Problem 5)
**Dependency:** Phase A + B tamamlanmış | **Risk:** HIGH — yeni state, validation, export flow | **Files:** multiple

### C1 — PlanningMode enum + AppSettings state
- `lib/models/planning_mode.dart` (new): `enum PlanningMode { weekly, monthly }`
- `lib/state/app_settings_state.dart` (new): `ChangeNotifier`, SharedPreferences'a persist eder
  - `PlanningMode mode`
  - `setMode(PlanningMode)`
- `lib/main.dart`: `AppSettingsState` ChangeNotifierProvider olarak ekle
- `Week` modeli DEĞİŞMEZ — mode uygulama seviyesinde

### C2 — First-run/create modal
- `lib/ui/screens/roster_home_screen.dart`: hafta oluşturma akışına modal ekle
  - "Haftalık mı, Aylık mı?" seçim ekranı
  - Seçim `AppSettingsState`'e yazılır, kalıcı
  - Her yeni hafta/dönem oluşturmada sorulur (ayar override edilebilir)

### C3 — WeekService: mode-aware date validation
- `lib/services/week_service.dart`: `validateDateRange(startDate, endDate, mode)` ekle
  - weekly: `endDate - startDate <= 6 gün` — fazlası → `WeekValidationError.tooLong`
  - monthly: `endDate - startDate >= 27 gün` — azı → `WeekValidationError.tooShort`
- Unit test: `test/core_logic_test.dart` — weekly/monthly boundary cases

### C4 — EditWeekScreen: date picker validation
- `lib/ui/screens/edit_week_screen.dart`: tarih seçiminde `AppSettingsState.mode` oku
  - weekly mode: 7 günden fazla seçilirse → "Haftalık modda en fazla 1 hafta seçilebilir" snackbar
  - monthly mode: 28 günden az seçilirse → "Aylık modda en az 1 aylık aralık seçilmeli" snackbar

### C5 — Monthly export: stacked tables
- `lib/services/export_snapshot_service.dart`: monthly mode'da birden fazla `Week` nesnesini tek snapshot'a alır
- PDF/Excel multi-week export zaten destekleniyor (`ExportTableService.buildWeekTable` multi-week parametre alıyor)
- Kontrol: mevcut multi-week export path'ini monthly mode için test et, değişiklik gerekmeyebilir
- Validation: `test/android_saf_export_test.dart`, `test/core_logic_test.dart` export group

### C6 — "Aylık tablo oluştur" button (weekly mode only)
- `lib/ui/screens/roster_home_screen.dart`: weekly modda bir `TextButton` / `ElevatedButton` ekle
  - Tap → `WeekService.generateMonthlyFromWeek(currentWeek)` çağır → 4 hafta üretir (current + 3 forward)
  - 4 hafta mevcut hafta baz alınarak, her hafta önceki haftanın rotation'ını korur
  - Üretilen 4 hafta `RosterState`'e `weeks` listesi olarak eklenir
  - Kullanıcı onayı gerekir: "4 haftalık aylık tablo oluşturulsun mu?" dialog

### C7 — Monthly mode: stacked table header
- Aylık modda export header'ında tarih açıklaması aylık başlangıç ve bitiş tarihlerini gösterir
  - Mevcut `Week.title` parse logic yerine `displayRange(startDate, endDate)` format: "01 Nisan - 30 Nisan 2026"
  - PDF ve Excel her ikisi için `ExportTableService` üzerinden

**Phase C Validation:**
```
flutter test test/core_logic_test.dart
flutter test test/android_saf_export_test.dart
flutter analyze
```
Manuel: weekly mode → 7 gün seçim → export. Monthly mode → 28 gün → export. "Aylık tablo" button → 4 hafta generate → export.

---

## Risk Analizi

| Risk | Seviye | Mitigation |
|---|---|---|
| Phase C `Week` modeli değişirse tüm serialization bozulur | HIGH | Week modeli değiştirilmiyor, mode ayrı state'te |
| C6 "4 hafta generate" rotation mantığı yanlış uygulanırsa veri bozulur | HIGH | Önce unit test yaz, sonra implement |
| B2 per-row swap yanlış index'le çalışırsa roster bozulur | MEDIUM | core_logic_test.dart edge cases zorunlu |
| A3 TeacherAssignmentLookupService mevcut ama test edilmemişse | MEDIUM | `teacher_assignment_lookup_service_test.dart` ekle |
| C5 multi-week export monthly mode'da yanlış sayfa bölmesi | MEDIUM | export snapshot equality test |

---

## Protected Files (bu fazlar boyunca dokunulmamalı)
- `lib/services/text_normalizer.dart`
- `lib/services/export_file_service.dart`
- `lib/services/export_table_service.dart`
- `lib/services/roster_service.dart` (B1 ekleme var, mevcut rotate logic dokunulmamalı)
- `lib/models/roster_row.dart`

---

## Execution Order

```
A1 → A2 → A3   (paralel mümkün, bağımsız)
     ↓
     B1 → B2
     ↓
C1 → C2 → C3 → C4 → C5 → C6 → C7
```

Her step sonrası: `flutter test + flutter analyze` → geçmeden sonraki step'e geçilmez.
