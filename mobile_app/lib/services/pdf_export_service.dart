import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/roster_row.dart';
import '../models/week.dart';
import 'export_snapshot_service.dart';
import 'export_table_service.dart';
import 'text_normalizer.dart';

const String pdfExportFontAsset = 'assets/fonts/Arial.ttf';

class PdfExportService {
  const PdfExportService({
    ExportTableService tableService = const ExportTableService(),
    TextNormalizer normalizer = const TextNormalizer(),
  }) : _tableService = tableService,
       _normalizer = normalizer;

  final ExportTableService _tableService;
  final TextNormalizer _normalizer;

  Future<Uint8List> buildPdf(
    ExportSnapshot snapshot, {
    ByteData? fontData,
  }) async {
    if (snapshot.isEmpty) {
      throw const FormatException('Dışa aktarılacak hafta yok.');
    }

    final loadedFontData =
        fontData ?? await rootBundle.load(pdfExportFontAsset);
    final font = pw.Font.ttf(loadedFontData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    if (snapshot.isSingleWeek) {
      _addSingleWeekPage(document, snapshot.weeks.single, font);
    } else {
      _addMultiWeekPages(document, snapshot.weeks, font);
    }

    return document.save();
  }

  @visibleForTesting
  int debugRenderedRowCount(Week week) {
    return _weekRowCount(week);
  }

  @visibleForTesting
  List<PdfBodyCellDebug> debugBodyCells(Week week) {
    final table = _tableService.buildWeekTable(week);
    return List<PdfBodyCellDebug>.unmodifiable(
      _buildBodyCellsByColumn(table).expand((columnCells) {
        return columnCells.map((cell) {
          return PdfBodyCellDebug(
            row: cell.row,
            column: cell.column,
            rowSpan: cell.rowSpan,
            value: cell.value,
          );
        });
      }),
    );
  }

  void _addSingleWeekPage(pw.Document document, Week week, pw.Font font) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              ..._schoolLine(week.schoolName, font, 10),
              _weekTable(week, font, rowHeight: 22, fontSize: 9),
              pw.SizedBox(height: PdfPageFormat.mm),
              _principalLine(week.principalName, font, 9),
            ],
          );
        },
      ),
    );
  }

  void _addMultiWeekPages(
    pw.Document document,
    List<Week> weeks,
    pw.Font font,
  ) {
    final schoolName = _firstNonEmptyField(weeks, (week) => week.schoolName);
    final principalName = _firstNonEmptyField(
      weeks,
      (week) => week.principalName,
    );
    final range = displayRange(weeks.first.startDate, weeks.last.endDate);

    for (var start = 0; start < weeks.length; start += 4) {
      final pageWeeks = weeks.skip(start).take(4).toList(growable: false);
      final layout = _computePageLayout(pageWeeks, schoolName);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            final children = <pw.Widget>[
              ..._schoolLine(schoolName, font, layout.fontSize),
              ..._rangeLine(range, font, layout.fontSize),
            ];

            for (var index = 0; index < pageWeeks.length; index++) {
              if (index > 0) {
                children.add(pw.SizedBox(height: 3));
              }
              children.add(
                _weekTable(
                  pageWeeks[index],
                  font,
                  rowHeight: layout.rowHeight,
                  fontSize: layout.fontSize,
                ),
              );
            }

            children
              ..add(pw.SizedBox(height: PdfPageFormat.mm))
              ..add(_principalLine(principalName, font, layout.fontSize));

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: children,
            );
          },
        ),
      );
    }
  }

  _PdfPageLayout _computePageLayout(List<Week> weeks, String schoolName) {
    final availableHeight = PdfPageFormat.a4.height - 72;
    final tableRows = weeks.fold<int>(0, (total, week) {
      return total + _weekRowCount(week);
    });
    final metadataRows = (schoolName.isEmpty ? 0 : 1) + 1 + 1; // + range
    final spacerHeight = 3 * (weeks.length - 1);
    final maxRowHeight =
        ((availableHeight - spacerHeight) / (tableRows + metadataRows)).floor();
    final rowHeight = maxRowHeight.clamp(8, 22).toDouble();
    final fontSize = (rowHeight - 3).clamp(5, 9).toDouble();
    return _PdfPageLayout(rowHeight: rowHeight, fontSize: fontSize);
  }

  int _weekRowCount(Week week) {
    final table = _tableService.buildWeekTable(week);
    return 2 + table.bodyRows.length;
  }

  pw.Widget _weekTable(
    Week week,
    pw.Font font, {
    required double rowHeight,
    required double fontSize,
  }) {
    final table = _tableService.buildWeekTable(week);
    final tableWidth = PdfPageFormat.a4.width - 72;
    final columnWidth = tableWidth / (1 + rosterDayCount);
    final baseStyle = pw.TextStyle(font: font, fontSize: fontSize);
    final boldStyle = pw.TextStyle(
      font: font,
      fontSize: fontSize,
      fontWeight: pw.FontWeight.bold,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _cell(
          week.title,
          width: tableWidth,
          height: rowHeight,
          style: boldStyle,
        ),
        pw.Row(
          children: [
            _cell(
              'NOBET YERI',
              width: columnWidth,
              height: rowHeight,
              style: boldStyle,
              fillColor: PdfColors.grey300,
            ),
            for (final dayName in rosterDayNames)
              _cell(
                dayName,
                width: columnWidth,
                height: rowHeight,
                style: boldStyle,
                fillColor: PdfColors.grey300,
              ),
          ],
        ),
        _bodyGrid(
          table,
          columnWidth: columnWidth,
          rowHeight: rowHeight,
          style: baseStyle,
        ),
      ],
    );
  }

  pw.Widget _bodyGrid(
    ExportWeekTable table, {
    required double columnWidth,
    required double rowHeight,
    required pw.TextStyle style,
  }) {
    final cellsByColumn = _buildBodyCellsByColumn(table);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final columnCells in cellsByColumn)
          pw.Column(
            children: [
              for (final cell in columnCells)
                _cell(
                  cell.value,
                  width: columnWidth,
                  height: rowHeight * cell.rowSpan,
                  style: style,
                ),
            ],
          ),
      ],
    );
  }

  List<List<_PdfBodyCell>> _buildBodyCellsByColumn(ExportWeekTable table) {
    final spanByStart = <String, ExportCellSpan>{};
    final coveredCells = <String>{};

    for (final span in table.spans) {
      spanByStart[_cellKey(span.startRow, span.column)] = span;
      for (var row = span.startRow + 1; row <= span.endRow; row++) {
        coveredCells.add(_cellKey(row, span.column));
      }
    }

    return List<List<_PdfBodyCell>>.generate(1 + rosterDayCount, (column) {
      final columnCells = <_PdfBodyCell>[];
      var row = 0;
      while (row < table.bodyRows.length) {
        if (coveredCells.contains(_cellKey(row, column))) {
          row += 1;
          continue;
        }

        final span = spanByStart[_cellKey(row, column)];
        final endRow = span == null
            ? row
            : span.endRow.clamp(row, table.bodyRows.length - 1).toInt();
        columnCells.add(
          _PdfBodyCell(
            row: row,
            column: column,
            rowSpan: endRow - row + 1,
            value: _bodyValue(table, row, column),
          ),
        );
        row = endRow + 1;
      }
      return List<_PdfBodyCell>.unmodifiable(columnCells);
    });
  }

  String _cellKey(int row, int column) => '$row:$column';

  String _bodyValue(ExportWeekTable table, int row, int column) {
    if (row < 0 || row >= table.bodyRows.length) {
      return '';
    }
    final bodyRow = table.bodyRows[row];
    if (column < 0 || column >= bodyRow.length) {
      return '';
    }
    return bodyRow[column];
  }

  pw.Widget _cell(
    String value, {
    required double width,
    required double height,
    required pw.TextStyle style,
    PdfColor? fillColor,
  }) {
    final textLines = _cellLines(value);
    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(1.5),
      decoration: pw.BoxDecoration(
        color: fillColor,
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: textLines.length == 1
          ? pw.Text(
              textLines.first,
              textAlign: pw.TextAlign.center,
              style: style,
            )
          : pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                for (final line in textLines)
                  pw.Text(line, textAlign: pw.TextAlign.center, style: style),
              ],
            ),
    );
  }

  List<String> _cellLines(String value) {
    final lines = value
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map(_normalizer.displayClean)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return const [' '];
    }
    return lines;
  }

  List<pw.Widget> _schoolLine(
    String schoolName,
    pw.Font font,
    double fontSize,
  ) {
    final cleanName = _normalizer.displayClean(schoolName);
    if (cleanName.isEmpty) {
      return const [];
    }
    return [
      pw.Text(
        _normalizer.canonical(cleanName),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize + 1,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: PdfPageFormat.mm),
    ];
  }

  List<pw.Widget> _rangeLine(String range, pw.Font font, double fontSize) {
    if (range.isEmpty) return const [];
    return [
      pw.Text(
        range,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      ),
      pw.SizedBox(height: PdfPageFormat.mm),
    ];
  }

  pw.Widget _principalLine(
    String principalName,
    pw.Font font,
    double fontSize,
  ) {
    final lines = _principalLines(principalName);
    final style = pw.TextStyle(font: font, fontSize: fontSize);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(lines.first, textAlign: pw.TextAlign.right, style: style),
        pw.Text(lines.last, textAlign: pw.TextAlign.right, style: style),
      ],
    );
  }

  List<String> _principalLines(String value) {
    final cleanName = _normalizer.displayClean(value);
    return <String>[cleanName, 'Müdür'];
  }

  @visibleForTesting
  List<String> debugPrincipalFooterLines(String principalName) {
    return List<String>.unmodifiable(_principalLines(principalName));
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
}

class _PdfPageLayout {
  const _PdfPageLayout({required this.rowHeight, required this.fontSize});

  final double rowHeight;
  final double fontSize;
}

@visibleForTesting
class PdfBodyCellDebug {
  const PdfBodyCellDebug({
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.value,
  });

  final int row;
  final int column;
  final int rowSpan;
  final String value;
}

class _PdfBodyCell {
  const _PdfBodyCell({
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.value,
  });

  final int row;
  final int column;
  final int rowSpan;
  final String value;
}
