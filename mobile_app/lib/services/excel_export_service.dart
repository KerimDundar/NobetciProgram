import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

import '../models/roster_row.dart';
import '../models/week.dart';
import 'export_snapshot_service.dart';
import 'export_table_service.dart';
import 'text_normalizer.dart';

class ExcelExportService {
  const ExcelExportService({
    ExportTableService tableService = const ExportTableService(),
    TextNormalizer normalizer = const TextNormalizer(),
  }) : _tableService = tableService,
       _normalizer = normalizer;

  static const String sheetName = 'Nobet';
  static const String dataSheetName = 'Nobet_Data';

  final ExportTableService _tableService;
  final TextNormalizer _normalizer;

  Uint8List buildWorkbook(ExportSnapshot snapshot) {
    if (snapshot.isEmpty) {
      throw const FormatException('Dışa aktarılacak hafta yok.');
    }

    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    final dataSheet = excel[dataSheetName];
    excel.setDefaultSheet(sheetName);

    sheet.setDefaultRowHeight(22);
    for (var column = 0; column <= rosterDayCount; column++) {
      sheet.setColumnWidth(column, 18);
    }
    for (var column = 0; column <= rosterDayCount; column++) {
      dataSheet.setColumnWidth(column, 18);
    }
    _writeLogicalDataSheet(dataSheet, snapshot);

    var row = 0;
    if (snapshot.isSingleWeek) {
      row = _appendWeekBlock(
        sheet,
        snapshot.weeks.single,
        row,
        includeSchoolRow: true,
      );
      _writePrincipalLine(sheet, row, snapshot.weeks.single.principalName);
    } else {
      final schoolName = _firstNonEmptyField(
        snapshot.weeks,
        (week) => week.schoolName,
      );
      if (schoolName.isNotEmpty) {
        _writeSchoolLine(sheet, row, schoolName);
        row += 1;
      }

      for (final week in snapshot.weeks) {
        row = _appendWeekBlock(sheet, week, row, includeSchoolRow: false);
        row += 1;
      }

      final principalName = _firstNonEmptyField(
        snapshot.weeks,
        (week) => week.principalName,
      );
      _writePrincipalLine(sheet, row, principalName);
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Excel dosyası oluşturulamadı.');
    }
    return Uint8List.fromList(bytes);
  }

  int _appendWeekBlock(
    xl.Sheet sheet,
    Week week,
    int startRow, {
    required bool includeSchoolRow,
  }) {
    var row = startRow;
    if (includeSchoolRow && week.schoolName.isNotEmpty) {
      _writeSchoolLine(sheet, row, week.schoolName);
      row += 1;
    }

    _writeMergedRow(sheet, row, 0, rosterDayCount, week.title, _titleStyle);
    row += 1;

    _writeCell(sheet, row, 0, 'NOBET YERI', _headerStyle);
    for (var day = 0; day < rosterDayCount; day++) {
      _writeCell(sheet, row, day + 1, rosterDayNames[day], _headerStyle);
    }
    row += 1;

    final bodyStartRow = row;
    final table = _tableService.buildWeekTable(week);
    for (var bodyRow = 0; bodyRow < table.bodyRows.length; bodyRow++) {
      final values = table.bodyRows[bodyRow];
      for (var column = 0; column < values.length; column++) {
        _writeCell(
          sheet,
          row + bodyRow,
          column,
          values[column],
          _bodyStyle,
          preserveLineBreaks: column > 0,
        );
      }
    }

    for (final span in table.spans) {
      final start = xl.CellIndex.indexByColumnRow(
        columnIndex: span.column,
        rowIndex: bodyStartRow + span.startRow,
      );
      final end = xl.CellIndex.indexByColumnRow(
        columnIndex: span.column,
        rowIndex: bodyStartRow + span.endRow,
      );
      sheet.merge(
        start,
        end,
        customValue: _textValue(
          table.bodyRows[span.startRow][span.column],
          preserveLineBreaks: span.column > 0,
        ),
      );
      sheet.setMergedCellStyle(start, _bodyStyle);
    }

    return bodyStartRow + table.bodyRows.length;
  }

  void _writeLogicalDataSheet(xl.Sheet sheet, ExportSnapshot snapshot) {
    var row = 0;
    _writeCell(sheet, row, 0, 'EXPORT_DATA_VERSION', _dataHeaderStyle);
    _writeCell(sheet, row, 1, '1', _dataStyle);
    row += 1;

    for (var weekIndex = 0; weekIndex < snapshot.weeks.length; weekIndex++) {
      final week = snapshot.weeks[weekIndex];

      _writeCell(sheet, row, 0, 'WEEK_INDEX', _dataHeaderStyle);
      _writeCell(sheet, row, 1, '${weekIndex + 1}', _dataStyle);
      row += 1;
      _writeCell(sheet, row, 0, 'TITLE', _dataHeaderStyle);
      _writeCell(sheet, row, 1, week.title, _dataStyle);
      row += 1;
      _writeCell(sheet, row, 0, 'START_DATE', _dataHeaderStyle);
      _writeCell(sheet, row, 1, _dateKey(week.startDate), _dataStyle);
      row += 1;
      _writeCell(sheet, row, 0, 'END_DATE', _dataHeaderStyle);
      _writeCell(sheet, row, 1, _dateKey(week.endDate), _dataStyle);
      row += 1;
      _writeCell(sheet, row, 0, 'SCHOOL_NAME', _dataHeaderStyle);
      _writeCell(sheet, row, 1, week.schoolName, _dataStyle);
      row += 1;
      _writeCell(sheet, row, 0, 'PRINCIPAL_NAME', _dataHeaderStyle);
      _writeCell(sheet, row, 1, week.principalName, _dataStyle);
      row += 1;
      _writeCell(sheet, row, 0, 'ROW_COUNT', _dataHeaderStyle);
      _writeCell(sheet, row, 1, '${week.rows.length}', _dataStyle);
      row += 1;

      _writeCell(sheet, row, 0, 'NOBET YERI', _dataHeaderStyle);
      for (var day = 0; day < rosterDayCount; day++) {
        _writeCell(sheet, row, day + 1, rosterDayNames[day], _dataHeaderStyle);
      }
      row += 1;

      for (final rosterRow in week.rows) {
        _writeCell(sheet, row, 0, rosterRow.location, _dataStyle);
        for (var day = 0; day < rosterDayCount; day++) {
          _writeCell(
            sheet,
            row,
            day + 1,
            rosterRow.teachersByDay[day],
            _dataStyle,
          );
        }
        row += 1;
      }

      row += 1;
    }
  }

  void _writeSchoolLine(xl.Sheet sheet, int row, String schoolName) {
    final displayName = _normalizer.canonical(schoolName);
    if (displayName.isEmpty) {
      return;
    }
    _writeMergedRow(sheet, row, 0, rosterDayCount, displayName, _schoolStyle);
  }

  void _writePrincipalLine(xl.Sheet sheet, int row, String principalName) {
    _writeCell(sheet, row, 7, _principalText(principalName), _principalStyle);
  }

  void _writeMergedRow(
    xl.Sheet sheet,
    int row,
    int startColumn,
    int endColumn,
    String value,
    xl.CellStyle style,
  ) {
    _writeCell(sheet, row, startColumn, value, style);
    final start = xl.CellIndex.indexByColumnRow(
      columnIndex: startColumn,
      rowIndex: row,
    );
    final end = xl.CellIndex.indexByColumnRow(
      columnIndex: endColumn,
      rowIndex: row,
    );
    sheet.merge(start, end, customValue: _textValue(value));
    sheet.setMergedCellStyle(start, style);
  }

  void _writeCell(
    xl.Sheet sheet,
    int row,
    int column,
    String value,
    xl.CellStyle style, {
    bool preserveLineBreaks = false,
  }) {
    sheet.updateCell(
      xl.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      _textValue(value, preserveLineBreaks: preserveLineBreaks),
      cellStyle: style,
    );
  }

  xl.TextCellValue _textValue(String value, {bool preserveLineBreaks = false}) {
    if (!preserveLineBreaks) {
      return xl.TextCellValue(_normalizer.displayClean(value));
    }
    final normalized = value
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map(_normalizer.displayClean)
        .where((line) => line.isNotEmpty)
        .join('\n');
    return xl.TextCellValue(normalized);
  }

  String _principalText(String value) {
    final cleanName = _normalizer.displayClean(value);
    return cleanName.isEmpty ? 'Müdür :' : 'Müdür : $cleanName';
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _firstNonEmptyField(List<Week> weeks, String Function(Week) select) {
    for (final week in weeks) {
      final value = _normalizer.displayClean(select(week));
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static final xl.Border _thinBorder = xl.Border(
    borderStyle: xl.BorderStyle.Thin,
    borderColorHex: xl.ExcelColor.black,
  );

  static final xl.CellStyle _bodyStyle = xl.CellStyle(
    fontFamily: 'Arial',
    fontSize: 10,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    textWrapping: xl.TextWrapping.WrapText,
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static final xl.CellStyle _headerStyle = _bodyStyle.copyWith(
    boldVal: true,
    backgroundColorHexVal: xl.ExcelColor.fromHexString('FFD9D9D9'),
  );

  static final xl.CellStyle _titleStyle = _bodyStyle.copyWith(boldVal: true);

  static final xl.CellStyle _schoolStyle = _bodyStyle.copyWith(
    boldVal: true,
    fontSizeVal: 11,
  );

  static final xl.CellStyle _principalStyle = xl.CellStyle(
    fontFamily: 'Arial',
    fontSize: 10,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static final xl.CellStyle _dataStyle = xl.CellStyle(
    fontFamily: 'Arial',
    fontSize: 10,
    horizontalAlign: xl.HorizontalAlign.Left,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static final xl.CellStyle _dataHeaderStyle = _dataStyle.copyWith(
    boldVal: true,
  );
}
