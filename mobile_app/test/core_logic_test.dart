import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/models/roster_row.dart';
import 'package:nobetci_program_mobile/models/week.dart';
import 'package:nobetci_program_mobile/services/cell_teacher_codec.dart';
import 'package:nobetci_program_mobile/services/duplicate_location_service.dart';
import 'package:nobetci_program_mobile/services/excel_export_service.dart';
import 'package:nobetci_program_mobile/services/export_file_service.dart';
import 'package:nobetci_program_mobile/services/export_snapshot_service.dart';
import 'package:nobetci_program_mobile/services/export_table_service.dart';
import 'package:nobetci_program_mobile/services/grid_cell_status_service.dart';
import 'package:nobetci_program_mobile/services/pdf_export_service.dart';
import 'package:nobetci_program_mobile/services/roster_service.dart';
import 'package:nobetci_program_mobile/services/teacher_assignment_lookup_service.dart';
import 'package:nobetci_program_mobile/services/text_normalizer.dart';
import 'package:nobetci_program_mobile/services/week_grid_projection_service.dart';
import 'package:nobetci_program_mobile/models/planning_mode.dart';
import 'package:nobetci_program_mobile/services/week_service.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextNormalizer', () {
    const normalizer = TextNormalizer();

    test('canonical uses Turkish-aware uppercase', () {
      expect(
        normalizer.canonical('n\u00F6bet\u00E7i \u00F6\u011Fretmen listesi'),
        'N\u00D6BET\u00C7\u0130 \u00D6\u011ERETMEN L\u0130STES\u0130',
      );
    });

    test('canonical comparison handles dotted and dotless i', () {
      expect(
        normalizer.canonical('istanbul \u0131\u015F\u0131k'),
        'İSTANBUL IŞIK',
      );
      expect(normalizer.canonicalEquals('\u0130pek', 'ipek'), isTrue);
      expect(
        normalizer.canonicalEquals('I\u015F\u0131k', '\u0131\u015F\u0131k'),
        isTrue,
      );
      expect(normalizer.canonicalEquals('Ali', 'Al\u0131'), isFalse);
    });

    test('handles null, empty, and combining Unicode safely', () {
      expect(normalizer.displayClean(null), '');
      expect(normalizer.canonical(null), '');
      expect(normalizer.canonical(''), '');
      expect(normalizer.canonical('I\u0307zmir'), '\u0130ZM\u0130R');
      expect(normalizer.canonical('S\u0327ubat'), '\u015EUBAT');
      expect(normalizer.canonical('  \t\n  '), '');
    });

    test('displayClean collapses whitespace without changing case', () {
      expect(normalizer.displayClean('  Ali\n  Veli  '), 'Ali Veli');
    });
  });

  group('CellTeacherCodec', () {
    const codec = CellTeacherCodec();

    test('parse handles empty cell', () {
      expect(codec.parse(''), isEmpty);
      expect(codec.parse('   '), isEmpty);
      expect(codec.parse('\n \n'), isEmpty);
    });

    test('parse handles single teacher cell', () {
      expect(codec.parse('  Ali Yilmaz  '), ['Ali Yilmaz']);
    });

    test('parse handles multi teacher cell', () {
      expect(codec.parse('Ali Yilmaz\nAyse Demir\nCan Aydin'), [
        'Ali Yilmaz',
        'Ayse Demir',
        'Can Aydin',
      ]);
    });

    test('addTeacher does not add canonical duplicates', () {
      final cell = codec.addTeacher('Ali Yilmaz', ' ali   yilmaz ');
      expect(cell, 'Ali Yilmaz');
      expect(codec.parse(cell), ['Ali Yilmaz']);
    });

    test('removeTeacher removes teacher safely', () {
      final cell = codec.removeTeacher('Ali Yilmaz\nAyse Demir', 'ali yilmaz');
      expect(cell, 'Ayse Demir');
      expect(codec.parse(cell), ['Ayse Demir']);
    });

    test('Turkish characters are preserved', () {
      final cell = codec.serialize(['Şule Çağrı', 'İpek Öztürk']);
      expect(cell, 'Şule Çağrı\nİpek Öztürk');
      expect(codec.parse(cell), ['Şule Çağrı', 'İpek Öztürk']);
      expect(codec.containsTeacher(cell, 'sule cagrı'), isFalse);
      expect(codec.containsTeacher(cell, 'Şule Çağrı'), isTrue);
    });

    test('newline round-trip remains stable and normalized', () {
      final source = ' Ali Yilmaz \r\n\nAyse Demir\nAli   Yilmaz ';
      final parsed = codec.parse(source);
      final serialized = codec.serialize(parsed);

      expect(parsed, ['Ali Yilmaz', 'Ayse Demir']);
      expect(serialized, 'Ali Yilmaz\nAyse Demir');
      expect(codec.parse(serialized), ['Ali Yilmaz', 'Ayse Demir']);
    });
  });

  group('TeacherAssignmentLookupService', () {
    const service = TeacherAssignmentLookupService();

    test('lookup returns empty when teacher has no assignment', () {
      final week = Week(
        title: 'T1',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahce', teachersByDay: ['Ali Yilmaz']),
        ],
      );

      final result = service.assignmentsFromWeek(
        week: week,
        teacherName: 'Ayse Demir',
      );

      expect(result, isEmpty);
    });

    test('lookup returns single assignment for teacher', () {
      final week = Week(
        title: 'T1',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahce', teachersByDay: ['Ali Yilmaz']),
          RosterRow(location: 'Koridor', teachersByDay: ['']),
        ],
      );

      final result = service.assignmentsFromWeek(
        week: week,
        teacherName: 'Ali Yilmaz',
      );

      expect(result, hasLength(1));
      expect(result.first.dayIndex, 0);
      expect(result.first.location, 'Bahce');
    });

    test('lookup returns multiple locations on same day', () {
      final week = Week(
        title: 'T1',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahce', teachersByDay: ['Ali Yilmaz']),
          RosterRow(location: 'Koridor', teachersByDay: ['Ali Yilmaz']),
          RosterRow(location: 'Kantin', teachersByDay: ['']),
        ],
      );

      final result = service.assignmentsFromWeek(
        week: week,
        teacherName: 'Ali Yilmaz',
        dayIndex: 0,
      );

      expect(result, hasLength(2));
      expect(result.map((item) => item.location).toList(), [
        'Bahce',
        'Koridor',
      ]);
    });

    test('lookup finds target teacher in multi-teacher cell', () {
      final week = Week(
        title: 'T1',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(
            location: 'Bahce',
            teachersByDay: [r'Ali Yilmaz\nAyse Demir'],
          ),
        ],
      );

      final result = service.assignmentsFromWeek(
        week: week,
        teacherName: 'Ayse Demir',
      );

      expect(result, hasLength(1));
      expect(result.first.dayIndex, 0);
      expect(result.first.location, 'Bahce');
    });

    test('lookup without dayIndex returns assignments across all days', () {
      final week = Week(
        title: 'T1',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(
            location: 'Bahce',
            teachersByDay: ['Ali', '', 'Ali', '', 'Ali'],
          ),
        ],
      );

      final all = service.assignmentsFromWeek(
        week: week,
        teacherName: 'Ali',
      );
      expect(all, hasLength(3));
      expect(all.map((e) => e.dayIndex).toList(), [0, 2, 4]);

      final dayZeroOnly = service.assignmentsFromWeek(
        week: week,
        teacherName: 'Ali',
        dayIndex: 0,
      );
      expect(dayZeroOnly, hasLength(1));
    });
  });

  group('DuplicateLocationService', () {
    const service = DuplicateLocationService();

    test('ignores spaces, ASCII hyphen, Unicode dash, and Turkish case', () {
      expect(
        service.isDuplicateLocation('Bah\u00E7e-1', 'bah\u00E7e 1'),
        isTrue,
      );
      expect(service.isDuplicateLocation('Kat\u20131', 'kat-1'), isTrue);
      expect(service.isDuplicateLocation('\u0130dare', 'idare'), isTrue);
    });

    test('matches duplicate locations across supported dash types', () {
      const dashVariants = [
        '-', // hyphen-minus
        '\u2010', // hyphen
        '\u2011', // non-breaking hyphen
        '\u2012', // figure dash
        '\u2013', // en dash
        '\u2014', // em dash
        '\u2015', // horizontal bar
        '\u2212', // minus sign
        '\uFE58', // small em dash
        '\uFE63', // small hyphen-minus
        '\uFF0D', // fullwidth hyphen-minus
      ];

      for (final dash in dashVariants) {
        expect(
          service.isDuplicateLocation('Bah\u00E7e${dash}1', 'bah\u00E7e 1'),
          isTrue,
          reason: 'dash U+${dash.runes.single.toRadixString(16)}',
        );
      }
    });

    test('keeps other punctuation meaningful and rejects empty top key', () {
      expect(service.isDuplicateLocation('A/B', 'AB'), isFalse);
      expect(service.isDuplicateLocation('', ''), isFalse);
    });
  });

  group('RosterService', () {
    const service = RosterService();

    test('normalizes short and long rows to exactly five days', () {
      final row = service.normalizeRow(
        location: ' Bah\u00E7e ',
        teachersByDay: [' Ali ', 'Ay\u015Fe', 'Can', 'Deniz', 'Ece', 'Extra'],
      );

      expect(row.location, 'Bah\u00E7e');
      expect(row.teachersByDay, ['Ali', 'Ay\u015Fe', 'Can', 'Deniz', 'Ece']);

      final shortRow = service.normalizeRow(
        location: 'Koridor',
        teachersByDay: ['Fatma'],
      );
      expect(shortRow.teachersByDay, ['Fatma', '', '', '', '']);
    });

    test('normalizes null and missing teacher values to five cells', () {
      final row = service.normalizeRow(
        location: ' Merdiven ',
        teachersByDay: [' Ali ', null],
      );

      expect(row.location, 'Merdiven');
      expect(row.teachersByDay, ['Ali', '', '', '', '']);
      expect(row.teachersByDay.length, rosterDayCount);
    });

    test(
      'normalizes null location and null teacher list to safe empty cells',
      () {
        final row = service.normalizeRow(location: null, teachersByDay: null);

        expect(row.location, '');
        expect(row.teachersByDay, ['', '', '', '', '']);
        expect(row.teachersByDay.length, rosterDayCount);
      },
    );

    test('rotateForward is safe for empty data and all-empty rows', () {
      expect(service.rotateForward(const []), isEmpty);

      final rows = [
        RosterRow(location: null, teachersByDay: null),
        RosterRow(location: 'R2', teachersByDay: const []),
      ];
      final rotated = service.rotateForward(rows);

      expect(rotated, hasLength(2));
      expect(
        rotated.every((row) => row.teachersByDay.length == rosterDayCount),
        isTrue,
      );
      expect(rotated.map((row) => row.teachersByDay).toList(), [
        ['', '', '', '', ''],
        ['', '', '', '', ''],
      ]);
    });

    test('rotateBackward is safe for empty data and all-empty rows', () {
      expect(service.rotateBackward(const []), isEmpty);

      final rows = [
        RosterRow(location: null, teachersByDay: null),
        RosterRow(location: 'R2', teachersByDay: const []),
      ];
      final rotated = service.rotateBackward(rows);

      expect(rotated, hasLength(2));
      expect(
        rotated.every((row) => row.teachersByDay.length == rosterDayCount),
        isTrue,
      );
      expect(rotated.map((row) => row.teachersByDay).toList(), [
        ['', '', '', '', ''],
        ['', '', '', '', ''],
      ]);
    });

    test('rotateForward matches Python column rotation behavior', () {
      final rows = [
        RosterRow(location: 'R1', teachersByDay: ['A', 'B', '', 'D', 'E']),
        RosterRow(location: 'R2', teachersByDay: ['', 'C', 'X', '', 'F']),
        RosterRow(location: 'R3', teachersByDay: ['G', '', 'Y', 'H', '']),
        RosterRow(location: 'R4', teachersByDay: ['I', 'J', '', 'K', 'L']),
      ];

      final rotated = service.rotateForward(rows).map((row) {
        return row.teachersByDay;
      }).toList();

      expect(rotated, [
        ['G', 'C', '', 'H', 'F'],
        ['', 'J', 'Y', '', 'L'],
        ['I', '', 'X', 'K', ''],
        ['A', 'B', '', 'D', 'E'],
      ]);
    });

    test('rotation preserves empty cell positions', () {
      final rows = [
        RosterRow(location: 'R1', teachersByDay: ['A', '', '', '', '']),
        RosterRow(location: 'R2', teachersByDay: ['', '', '', '', '']),
        RosterRow(location: 'R3', teachersByDay: ['B', '', '', '', '']),
        RosterRow(location: 'R4', teachersByDay: ['', '', '', '', '']),
      ];

      final rotated = service.rotateForward(rows);

      expect(rotated.map((row) => row.teachersByDay.first).toList(), [
        'B',
        '',
        'A',
        '',
      ]);
    });

    test('rotation leaves a single-item column unchanged', () {
      final rows = [
        RosterRow(location: 'R1', teachersByDay: ['', '', '', '', '']),
        RosterRow(location: 'R2', teachersByDay: ['Only', '', '', '', '']),
        RosterRow(location: 'R3', teachersByDay: ['', '', '', '', '']),
      ];

      final forward = service.rotateForward(rows);
      final backward = service.rotateBackward(rows);

      expect(forward.map((row) => row.teachersByDay.first).toList(), [
        '',
        'Only',
        '',
      ]);
      expect(backward.map((row) => row.teachersByDay.first).toList(), [
        '',
        'Only',
        '',
      ]);
    });

    test('rotateBackward reverses rotateForward', () {
      final rows = [
        RosterRow(location: 'R1', teachersByDay: ['A', 'B', '', 'D', 'E']),
        RosterRow(location: 'R2', teachersByDay: ['', 'C', 'X', '', 'F']),
        RosterRow(location: 'R3', teachersByDay: ['G', '', 'Y', 'H', '']),
        RosterRow(location: 'R4', teachersByDay: ['I', 'J', '', 'K', 'L']),
      ];

      final restored = service.rotateBackward(service.rotateForward(rows));

      expect(restored.map((row) => row.teachersByDay).toList(), [
        ['A', 'B', '', 'D', 'E'],
        ['', 'C', 'X', '', 'F'],
        ['G', '', 'Y', 'H', ''],
        ['I', 'J', '', 'K', 'L'],
      ]);
    });

    test('rotateDayForward rotates only selected day column', () {
      final rows = [
        RosterRow(location: 'R1', teachersByDay: ['A', 'B', '', 'D', 'E']),
        RosterRow(location: 'R2', teachersByDay: ['', 'C', 'X', '', 'F']),
        RosterRow(location: 'R3', teachersByDay: ['G', '', 'Y', 'H', '']),
        RosterRow(location: 'R4', teachersByDay: ['I', 'J', '', 'K', 'L']),
      ];

      final rotated = service.rotateDayForward(rows, 0);

      expect(rotated.map((row) => row.teachersByDay).toList(), [
        ['G', 'B', '', 'D', 'E'],
        ['', 'C', 'X', '', 'F'],
        ['I', '', 'Y', 'H', ''],
        ['A', 'J', '', 'K', 'L'],
      ]);
    });

    test('rotateDayBackward rotates only selected day column', () {
      final rows = [
        RosterRow(location: 'R1', teachersByDay: ['A', 'B', '', 'D', 'E']),
        RosterRow(location: 'R2', teachersByDay: ['', 'C', 'X', '', 'F']),
        RosterRow(location: 'R3', teachersByDay: ['G', '', 'Y', 'H', '']),
        RosterRow(location: 'R4', teachersByDay: ['I', 'J', '', 'K', 'L']),
      ];

      final rotated = service.rotateDayBackward(rows, 4);

      expect(rotated.map((row) => row.teachersByDay).toList(), [
        ['A', 'B', '', 'D', 'L'],
        ['', 'C', 'X', '', 'E'],
        ['G', '', 'Y', 'H', ''],
        ['I', 'J', '', 'K', 'F'],
      ]);
    });

    test('rotateDayForward and rotateDayBackward validate day index', () {
      final rows = [
        RosterRow(location: 'R1', teachersByDay: ['A', '', '', '', '']),
      ];

      expect(
        () => service.rotateDayForward(rows, -1),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.rotateDayBackward(rows, rosterDayCount),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WeekService', () {
    final service = WeekService();

    test('buildTitle matches Python title format', () {
      expect(
        service.buildTitle(DateTime(2026, 2, 2), DateTime(2026, 2, 6)),
        '2 \u015EUBAT-6 \u015EUBAT HAFTASI N\u00D6BET\u00C7\u0130 '
        '\u00D6\u011ERETMEN L\u0130STES\u0130',
      );
    });

    test('buildTitle haftalık mod HAFTASI suffix kullanır', () {
      expect(
        service.buildTitle(
          DateTime(2026, 2, 2),
          DateTime(2026, 2, 6),
          PlanningMode.weekly,
        ),
        '2 ŞUBAT-6 ŞUBAT HAFTASI NÖBETÇİ '
        'ÖĞRETMEN LİSTESİ',
      );
    });

    test('buildTitle aylık mod AYLIK suffix kullanır', () {
      expect(
        service.buildTitle(
          DateTime(2026, 4, 1),
          DateTime(2026, 4, 30),
          PlanningMode.monthly,
        ),
        '1 NİSAN-30 NİSAN AYLIK NÖBETÇİ '
        'ÖĞRETMEN LİSTESİ',
      );
    });

    test('buildTitle aylık Şubat normal yıl', () {
      expect(
        service.buildTitle(
          DateTime(2026, 2, 1),
          DateTime(2026, 2, 28),
          PlanningMode.monthly,
        ),
        '1 ŞUBAT-28 ŞUBAT AYLIK NÖBETÇİ '
        'ÖĞRETMEN LİSTESİ',
      );
    });

    test('buildTitle aylık Şubat artık yıl', () {
      expect(
        service.buildTitle(
          DateTime(2028, 2, 1),
          DateTime(2028, 2, 29),
          PlanningMode.monthly,
        ),
        '1 ŞUBAT-29 ŞUBAT AYLIK NÖBETÇİ '
        'ÖĞRETMEN LİSTESİ',
      );
    });

    test('buildWeek aylık modda title AYLIK içerir', () {
      final week = service.buildWeek(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        rows: const [],
        mode: PlanningMode.monthly,
      );
      expect(week.title, contains('AYLIK'));
      expect(week.title, isNot(contains('HAFTASI')));
    });

    test('buildWeek haftalık modda title HAFTASI içerir', () {
      final week = service.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: const [],
      );
      expect(week.title, contains('HAFTASI'));
      expect(week.title, isNot(contains('AYLIK')));
    });

    test('parseTitle aylık başlık kabul eder', () {
      final parsed = service.parseTitle(
        '1 NİSAN-30 NİSAN AYLIK NÖBETÇİ '
        'ÖĞRETMEN LİSTESİ',
        2026,
      );
      expect(parsed.startDate, DateTime(2026, 4, 1));
      expect(parsed.endDate, DateTime(2026, 4, 30));
      expect(parsed.suffix, monthlyTitleSuffix);
    });

    test('parseTitle accepts human-cased Turkish title', () {
      final parsed = service.parseTitle(
        '2 \u015Eubat-6 \u015Eubat Haftas\u0131 N\u00F6bet\u00E7i '
        '\u00D6\u011Fretmen Listesi',
        2026,
      );

      expect(parsed.startDate, DateTime(2026, 2, 2));
      expect(parsed.endDate, DateTime(2026, 2, 6));
      expect(parsed.suffix, titleSuffix);
    });

    test('parseTitle fixes cross-year ranges', () {
      final parsed = service.parseTitle(
        '29 ARALIK-2 OCAK HAFTASI N\u00D6BET\u00C7\u0130 '
        '\u00D6\u011ERETMEN L\u0130STES\u0130',
        2026,
      );

      expect(parsed.startDate, DateTime(2026, 12, 29));
      expect(parsed.endDate, DateTime(2027, 1, 2));
    });

    test('parseTitle accepts human-cased cross-year title', () {
      final parsed = service.parseTitle(
        '29 Aral\u0131k-2 Ocak Haftas\u0131 N\u00F6bet\u00E7i '
        '\u00D6\u011Fretmen Listesi',
        2026,
      );

      expect(parsed.startDate, DateTime(2026, 12, 29));
      expect(parsed.endDate, DateTime(2027, 1, 2));
    });

    test('parseTitle rejects malformed input predictably', () {
      expect(() => service.parseTitle('', 2026), throwsFormatException);
      expect(
        () => service.parseTitle('2 \u015EUBAT-6 \u015EUBAT', 2026),
        throwsFormatException,
      );
      expect(
        () => service.parseTitle(
          '2 \u015EUBAT HAFTASI N\u00D6BET\u00C7\u0130 '
          '\u00D6\u011ERETMEN L\u0130STES\u0130',
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => service.parseTitle(
          '2 FOO-6 \u015EUBAT HAFTASI N\u00D6BET\u00C7\u0130 '
          '\u00D6\u011ERETMEN L\u0130STES\u0130',
          2026,
        ),
        throwsFormatException,
      );
    });

    test('parseTitle rejects invalid dates and unsafe years', () {
      expect(
        () => service.parseTitle(
          '31 \u015EUBAT-6 MART HAFTASI N\u00D6BET\u00C7\u0130 '
          '\u00D6\u011ERETMEN L\u0130STES\u0130',
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => service.parseTitle(
          '29 ARALIK-2 OCAK HAFTASI N\u00D6BET\u00C7\u0130 '
          '\u00D6\u011ERETMEN L\u0130STES\u0130',
          9999,
        ),
        throwsFormatException,
      );
      expect(
        () => service.parseTitle(
          '2 \u015EUBAT-6 \u015EUBAT HAFTASI N\u00D6BET\u00C7\u0130 '
          '\u00D6\u011ERETMEN L\u0130STES\u0130',
          0,
        ),
        throwsFormatException,
      );
    });

    test('buildNextWeek moves dates and rotates roster forward', () {
      final week = service.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'L1', teachersByDay: ['A', '', '', '', '']),
          RosterRow(location: 'L2', teachersByDay: ['B', '', '', '', '']),
        ],
      );

      final next = service.buildNextWeek(week);

      expect(next.startDate, DateTime(2026, 2, 9));
      expect(next.endDate, DateTime(2026, 2, 13));
      expect(next.rows.map((row) => row.teachersByDay.first).toList(), [
        'B',
        'A',
      ]);
    });

    test('validateDateRange weekly: 6 day diff is valid', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 2),
          DateTime(2026, 2, 8),
          PlanningMode.weekly,
        ),
        isNull,
      );
    });

    test('validateDateRange weekly: 7 day diff is tooLong', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 2),
          DateTime(2026, 2, 9),
          PlanningMode.weekly,
        ),
        WeekValidationError.tooLong,
      );
    });

    test('validateDateRange monthly: full month Feb is valid', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 1),
          DateTime(2026, 2, 28),
          PlanningMode.monthly,
        ),
        isNull,
      );
    });

    test('validateDateRange monthly: full month April is valid', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 4, 1),
          DateTime(2026, 4, 30),
          PlanningMode.monthly,
        ),
        isNull,
      );
    });

    test('validateDateRange monthly: non-first-day start is notFullMonth', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 2),
          DateTime(2026, 2, 28),
          PlanningMode.monthly,
        ),
        WeekValidationError.notFullMonth,
      );
    });

    test('validateDateRange monthly: non-last-day end is notFullMonth', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 1),
          DateTime(2026, 2, 27),
          PlanningMode.monthly,
        ),
        WeekValidationError.notFullMonth,
      );
    });

    test('validateDateRange monthly: cross-month range is notFullMonth', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 1),
          DateTime(2026, 3, 31),
          PlanningMode.monthly,
        ),
        WeekValidationError.notFullMonth,
      );
    });

    test('validateDateRange monthly: cross-month start/end is notFullMonth', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 1),
          DateTime(2026, 3, 1),
          PlanningMode.monthly,
        ),
        WeekValidationError.notFullMonth,
      );
    });

    test('monthStart returns first of month', () {
      expect(service.monthStart(DateTime(2026, 2, 15)), DateTime(2026, 2, 1));
      expect(service.monthStart(DateTime(2026, 4, 10)), DateTime(2026, 4, 1));
      expect(service.monthStart(DateTime(2026, 12, 31)), DateTime(2026, 12, 1));
    });

    test('monthEnd returns last day of month', () {
      expect(service.monthEnd(DateTime(2026, 2, 1)), DateTime(2026, 2, 28));
      expect(service.monthEnd(DateTime(2026, 4, 1)), DateTime(2026, 4, 30));
      expect(service.monthEnd(DateTime(2028, 2, 1)), DateTime(2028, 2, 29));
      expect(service.monthEnd(DateTime(2026, 12, 1)), DateTime(2026, 12, 31));
    });

    test('currentMonthRange returns full month for given date', () {
      final r1 = service.currentMonthRange(DateTime(2026, 2, 15));
      expect(r1.startDate, DateTime(2026, 2, 1));
      expect(r1.endDate, DateTime(2026, 2, 28));

      final r2 = service.currentMonthRange(DateTime(2026, 4, 10));
      expect(r2.startDate, DateTime(2026, 4, 1));
      expect(r2.endDate, DateTime(2026, 4, 30));

      final r3 = service.currentMonthRange(DateTime(2028, 2, 10));
      expect(r3.startDate, DateTime(2028, 2, 1));
      expect(r3.endDate, DateTime(2028, 2, 29));
    });

    test('validateDateRange startDate after endDate returns invalidRange', () {
      expect(
        service.validateDateRange(
          DateTime(2026, 2, 8),
          DateTime(2026, 2, 2),
          PlanningMode.weekly,
        ),
        WeekValidationError.invalidRange,
      );
    });

    test('generateMonthlyFromWeek returns 4 weeks', () {
      final base = service.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: const [],
      );
      expect(service.generateMonthlyFromWeek(base), hasLength(4));
    });

    test('generateMonthlyFromWeek weeks advance 7 days each', () {
      final base = service.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: const [],
      );
      final weeks = service.generateMonthlyFromWeek(base);
      expect(weeks[0].startDate, DateTime(2026, 2, 2));
      expect(weeks[1].startDate, DateTime(2026, 2, 9));
      expect(weeks[2].startDate, DateTime(2026, 2, 16));
      expect(weeks[3].startDate, DateTime(2026, 2, 23));
    });

    test('generateMonthlyFromWeek applies forward rotation each step', () {
      final base = service.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'L1', teachersByDay: ['A', '', '', '', '']),
          RosterRow(location: 'L2', teachersByDay: ['B', '', '', '', '']),
        ],
      );
      final weeks = service.generateMonthlyFromWeek(base);
      expect(weeks[0].rows[0].teachersByDay[0], 'A');
      expect(weeks[1].rows[0].teachersByDay[0], 'B');
      expect(weeks[2].rows[0].teachersByDay[0], 'A');
      expect(weeks[3].rows[0].teachersByDay[0], 'B');
    });

    test('generateMonthlyFromWeek does not mutate input week', () {
      final base = service.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'L1', teachersByDay: ['A', '', '', '', '']),
        ],
      );
      final originalRows = base.rows;
      service.generateMonthlyFromWeek(base);
      expect(base.rows, same(originalRows));
    });
  });

  group('WeekGridProjectionService', () {
    const service = WeekGridProjectionService();
    final startDate = DateTime(2026, 2, 2);
    final endDate = DateTime(2026, 2, 6);

    test('projects empty week into five empty day buckets', () {
      final projection = service.project(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: const [],
        ),
      );

      expect(projection.days, hasLength(rosterDayCount));
      expect(projection.dayAt(0).dayName, 'PAZARTESİ');
      expect(projection.dayAt(0).cells, isEmpty);
      expect(projection.dayAt(4).dayName, 'CUMA');
      expect(projection.dayAt(4).cells, isEmpty);
    });

    test('preserves row index, day index, location, and teacher values', () {
      final projection = service.project(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bahçe', teachersByDay: ['Ali', 'Ayşe']),
            RosterRow(location: 'Koridor', teachersByDay: ['', 'Veli']),
          ],
        ),
      );

      expect(projection.dayAt(0).cells, hasLength(2));
      expect(projection.dayAt(0).cells[0].rowIndex, 0);
      expect(projection.dayAt(0).cells[0].dayIndex, 0);
      expect(projection.dayAt(0).cells[0].location, 'Bahçe');
      expect(projection.dayAt(0).cells[0].teacher, 'Ali');
      expect(projection.dayAt(0).cells[0].teachers, ['Ali']);
      expect(projection.dayAt(0).cells[1].location, 'Koridor');
      expect(projection.dayAt(0).cells[1].teacher, '');
      expect(projection.dayAt(0).cells[1].teachers, isEmpty);
      expect(projection.dayAt(1).cells[0].teacher, 'Ayşe');
      expect(projection.dayAt(1).cells[0].teachers, ['Ayşe']);
      expect(projection.dayAt(1).cells[1].teacher, 'Veli');
      expect(projection.dayAt(1).cells[1].teachers, ['Veli']);
    });

    test('marks empty teacher cells without changing logical rows', () {
      final week = Week(
        title: 'T1',
        startDate: startDate,
        endDate: endDate,
        rows: [
          RosterRow(location: 'Bahçe', teachersByDay: ['', 'Ayşe']),
        ],
      );
      final projection = service.project(week);

      expect(projection.dayAt(0).cells.single.isEmpty, isTrue);
      expect(projection.dayAt(1).cells.single.isEmpty, isFalse);
      expect(week.rows.single.teachersByDay, ['', 'Ayşe', '', '', '']);
    });

    test('marks duplicate locations while preserving each row identity', () {
      final projection = service.project(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
            RosterRow(location: 'Koridor', teachersByDay: ['Veli']),
            RosterRow(location: 'Bahçe', teachersByDay: ['Can']),
          ],
        ),
      );

      final monday = projection.dayAt(0).cells;
      expect(monday.map((cell) => cell.rowIndex), [0, 1, 2]);
      expect(monday.map((cell) => cell.location), [
        'Bahçe',
        'Koridor',
        'Bahçe',
      ]);
      expect(monday.map((cell) => cell.teacher), ['Ali', 'Veli', 'Can']);
      expect(monday.map((cell) => cell.isDuplicateLocation), [
        true,
        false,
        true,
      ]);
    });

    test(
      'preserves multi teacher cells as list while keeping teacher string',
      () {
        final projection = service.project(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(
                location: 'Bahçe',
                teachersByDay: [r'Ali Yilmaz\nAyse Demir'],
              ),
            ],
          ),
        );

        final mondayCell = projection.dayAt(0).cells.single;
        expect(mondayCell.teachers, ['Ali Yilmaz', 'Ayse Demir']);
        expect(mondayCell.teacher, 'Ali Yilmaz\nAyse Demir');
        expect(mondayCell.isEmpty, isFalse);
      },
    );
  });

  group('GridCellStatusService', () {
    const projectionService = WeekGridProjectionService();
    const statusService = GridCellStatusService();
    final startDate = DateTime(2026, 2, 2);
    final endDate = DateTime(2026, 2, 6);

    test('returns empty when teacher list is empty', () {
      final projection = projectionService.project(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bahçe', teachersByDay: ['']),
          ],
        ),
      );
      final monday = projection.dayAt(0);

      expect(
        statusService.statusForCell(day: monday, cell: monday.cells.single),
        GridCellStatus.empty,
      );
    });

    test('returns filled when multi teacher list exists', () {
      final projection = projectionService.project(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(
              location: 'Bahçe',
              teachersByDay: [r'Ali Yilmaz\nAyse Demir'],
            ),
          ],
        ),
      );
      final monday = projection.dayAt(0);

      expect(
        statusService.statusForCell(day: monday, cell: monday.cells.single),
        GridCellStatus.filled,
      );
    });

    test('same teacher on same day across locations does not conflict', () {
      final projection = projectionService.project(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bahçe', teachersByDay: ['Ali Yilmaz']),
            RosterRow(location: 'Koridor', teachersByDay: ['Ali Yilmaz']),
          ],
        ),
      );
      final monday = projection.dayAt(0);
      final statuses = monday.cells
          .map((cell) => statusService.statusForCell(day: monday, cell: cell))
          .toList(growable: false);

      expect(statuses, [GridCellStatus.filled, GridCellStatus.filled]);
    });
  });

  group('RosterState edit validation', () {
    test(
      'saveWeekDraft blocks invalid date range and preserves current week',
      () {
        final state = RosterState.initial();
        final originalWeek = state.currentWeek;

        final error = state.saveWeekDraft(
          startDate: DateTime(2026, 2, 10),
          endDate: DateTime(2026, 2, 9),
          schoolName: 'Okul',
          principalName: 'Müdür',
          rows: originalWeek.rows,
        );

        expect(error, 'Başlangıç tarihi bitiş tarihinden büyük olamaz.');
        expect(state.currentWeek, same(originalWeek));
      },
    );

    test('generateMonthlyWeeks produces 4 weeks starting from currentWeek', () {
      final state = RosterState.initial();
      expect(state.generatedMonthlyWeeks, isNull);
      state.generateMonthlyWeeks();
      expect(state.generatedMonthlyWeeks, hasLength(4));
      expect(state.generatedMonthlyWeeks!.first, same(state.currentWeek));
    });

    test('saveWeekDraft normalizes and skips fully empty rows', () {
      final state = RosterState.initial();

      final error = state.saveWeekDraft(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        schoolName: ' Okul ',
        principalName: ' Müdür ',
        rows: [
          RosterRow(location: '  ', teachersByDay: const []),
          RosterRow(location: 'Bahçe', teachersByDay: [' Ali ', null]),
        ],
      );

      expect(error, isNull);
      expect(state.currentWeek.schoolName, 'Okul');
      expect(state.currentWeek.principalName, 'Müdür');
      expect(state.currentWeek.rows, hasLength(1));
      expect(state.currentWeek.rows.single.teachersByDay, [
        'Ali',
        '',
        '',
        '',
        '',
      ]);
    });
  });

  group('RosterState exportSnapshot', () {
    test('exportSnapshot uses currentWeek when no monthly weeks generated', () {
      final state = RosterState.initial();
      final snapshot = state.exportSnapshot;
      expect(snapshot.isSingleWeek, isTrue);
      expect(snapshot.weeks.single.title, state.currentWeek.title);
    });

    test('exportSnapshot uses generatedMonthlyWeeks after generateMonthlyWeeks()',
        () {
      final state = RosterState.initial();
      state.generateMonthlyWeeks();
      final snapshot = state.exportSnapshot;
      expect(snapshot.isMultiWeek, isTrue);
      expect(snapshot.weeks, hasLength(4));
    });

    test('generatedMonthlyWeeks starts from currentWeek and advances 7 days',
        () {
      final state = RosterState.initial();
      state.generateMonthlyWeeks();
      final weeks = state.generatedMonthlyWeeks!;
      expect(weeks[0].startDate, state.currentWeek.startDate);
      expect(
        weeks[1].startDate,
        weeks[0].startDate.add(const Duration(days: 7)),
      );
      expect(
        weeks[3].startDate,
        weeks[0].startDate.add(const Duration(days: 21)),
      );
    });
  });

  group('Export services', () {
    final startDate = DateTime(2026, 2, 2);
    final endDate = DateTime(2026, 2, 6);

    test('snapshot filters empty titles and normalizes roster rows', () {
      const service = ExportSnapshotService();
      final snapshot = service.fromPreviewWeeks([
        Week(
          title: '  ',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Boş', teachersByDay: ['Atlanacak']),
          ],
        ),
        Week(
          title: ' T1 ',
          startDate: startDate,
          endDate: endDate,
          schoolName: ' Okul ',
          principalName: ' Müdür ',
          rows: [
            RosterRow(location: ' Bahçe ', teachersByDay: [' Ali ', null]),
          ],
        ),
      ]);

      expect(snapshot.weeks, hasLength(1));
      expect(snapshot.weeks.single.title, 'T1');
      expect(snapshot.weeks.single.schoolName, 'Okul');
      expect(snapshot.weeks.single.rows.single.location, 'Bahçe');
      expect(snapshot.weeks.single.rows.single.teachersByDay, [
        'Ali',
        '',
        '',
        '',
        '',
      ]);
    });

    test('snapshot keeps encoded multi teacher cell string unchanged', () {
      const service = ExportSnapshotService();
      const encodedCell = r'Ali Yilmaz\nAyse Demir';
      final snapshot = service.fromCurrentWeek(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bah\u00E7e', teachersByDay: [encodedCell]),
          ],
        ),
      );

      expect(
        snapshot.weeks.single.rows.single.teachersByDay.first,
        encodedCell,
      );
    });

    test('shared export table uses desktop duplicate pair merge rules', () {
      const service = ExportTableService();
      const snapshotService = ExportSnapshotService();
      final sourceWeek = Week(
        title: 'T1',
        startDate: startDate,
        endDate: endDate,
        rows: [
          RosterRow(
            location: 'Bahçe-1',
            teachersByDay: ['Ali', '', 'Can', 'Deniz', 'Ece'],
          ),
          RosterRow(
            location: 'bahçe\u20131',
            teachersByDay: ['', 'Bora', 'CAN', 'Derya', ''],
          ),
          RosterRow(
            location: 'BAHÇE 1',
            teachersByDay: ['ALİ', '', '', '', ''],
          ),
        ],
      );
      final snapshot = snapshotService.fromCurrentWeek(sourceWeek);
      final table = service.buildWeekTable(snapshot.weeks.single);

      expect(snapshot.weeks.single.rows.map((row) => row.location), [
        'Bahçe-1',
        'bahçe\u20131',
        'BAHÇE 1',
      ]);
      expect(table.bodyRows[0], [
        'Bahçe-1',
        'Ali',
        'Bora',
        'Can',
        'Deniz',
        'Ece',
      ]);
      expect(table.bodyRows[1], ['', '', '', '', 'Derya', '']);
      expect(table.bodyRows[2], ['BAHÇE 1', 'ALİ', '', '', '', '']);
      expect(_hasSpan(table.spans, 0, 0, 1), isTrue);
      expect(_hasSpan(table.spans, 0, 0, 2), isFalse);
      expect(table.spans.where((span) => span.column == 4), isEmpty);
    });

    test(
      'export table decodes multi teacher token and preserves Turkish line order',
      () {
        const service = ExportTableService();
        const snapshotService = ExportSnapshotService();
        const firstTeacher = '\u00C7a\u011Fr\u0131 \u00DCnl\u00FC';
        const secondTeacher = '\u015Eule \u00D6zt\u00FCrk';
        final encodedCell = '$firstTeacher\\n$secondTeacher';
        final snapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Bah\u00E7e', teachersByDay: [encodedCell]),
            ],
          ),
        );

        final table = service.buildWeekTable(snapshot.weeks.single);

        expect(table.bodyRows.single[1], '$firstTeacher\n$secondTeacher');
      },
    );

    test(
      'duplicate merge behavior stays consistent with multi teacher cells',
      () {
        const service = ExportTableService();
        const snapshotService = ExportSnapshotService();
        final snapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Kat-1', teachersByDay: [r'Ali\nAyse']),
              RosterRow(location: 'kat 1', teachersByDay: [r'ali\nayse']),
              RosterRow(location: 'KAT 1', teachersByDay: ['Veli']),
            ],
          ),
        );

        final table = service.buildWeekTable(snapshot.weeks.single);

        expect(_hasSpan(table.spans, 0, 0, 1), isTrue);
        expect(_hasSpan(table.spans, 0, 0, 2), isFalse);
        expect(_hasSpan(table.spans, 1, 0, 1), isTrue);
        expect(table.bodyRows[0][1], 'Ali\nAyse');
        expect(table.bodyRows[1][1], '');
        expect(table.bodyRows[2][1], 'Veli');
      },
    );

    test('single teacher export behavior remains unchanged', () {
      const service = ExportTableService();
      const snapshotService = ExportSnapshotService();
      final snapshot = snapshotService.fromCurrentWeek(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Kat-1', teachersByDay: ['Ali']),
          ],
        ),
      );

      final table = service.buildWeekTable(snapshot.weeks.single);

      expect(table.bodyRows.single[1], 'Ali');
      expect(table.spans, isEmpty);
    });

    test(
      'duplicate pair policy handles one, two, three, and four-plus repeats',
      () {
        const service = ExportTableService();

        final one = service.buildWeekTable(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Kat-1', teachersByDay: ['Ali']),
            ],
          ),
        );
        expect(one.spans, isEmpty);
        expect(one.bodyRows.single[0], 'Kat-1');

        final two = service.buildWeekTable(
          Week(
            title: 'T2',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Kat-1', teachersByDay: ['Ali']),
              RosterRow(location: 'kat 1', teachersByDay: ['AL\u0130']),
            ],
          ),
        );
        expect(_hasSpan(two.spans, 0, 0, 1), isTrue);
        expect(_hasSpan(two.spans, 1, 0, 1), isTrue);
        expect(two.bodyRows[1], ['', '', '', '', '', '']);

        final three = service.buildWeekTable(
          Week(
            title: 'T3',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Kat-1', teachersByDay: ['Ali']),
              RosterRow(location: 'kat 1', teachersByDay: ['AL\u0130']),
              RosterRow(location: 'KAT\u20131', teachersByDay: ['Veli']),
            ],
          ),
        );
        expect(_hasSpan(three.spans, 0, 0, 1), isTrue);
        expect(_hasSpan(three.spans, 0, 0, 2), isFalse);
        expect(_hasSpan(three.spans, 1, 0, 1), isTrue);
        expect(three.bodyRows.map((row) => row[1]), ['Ali', '', 'Veli']);

        final fourPlus = service.buildWeekTable(
          Week(
            title: 'T4',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Kat-1', teachersByDay: ['Ali', '']),
              RosterRow(location: 'kat 1', teachersByDay: ['AL\u0130', '']),
              RosterRow(
                location: 'KAT\u20131',
                teachersByDay: ['', 'Ay\u015Fe'],
              ),
              RosterRow(
                location: 'Kat\u20111',
                teachersByDay: ['', 'AY\u015EE'],
              ),
              RosterRow(location: 'KAT 1', teachersByDay: ['', '']),
            ],
          ),
        );
        expect(_hasSpan(fourPlus.spans, 0, 0, 1), isTrue);
        expect(_hasSpan(fourPlus.spans, 0, 2, 3), isTrue);
        expect(_hasSpan(fourPlus.spans, 0, 0, 4), isFalse);
        expect(_hasSpan(fourPlus.spans, 1, 0, 1), isTrue);
        expect(_hasSpan(fourPlus.spans, 2, 2, 3), isTrue);
        expect(fourPlus.bodyRows[0], ['Kat-1', 'Ali', '', '', '', '']);
        expect(fourPlus.bodyRows[1], ['', '', '', '', '', '']);
        expect(fourPlus.bodyRows[2], [
          'KAT\u20131',
          '',
          'Ay\u015Fe',
          '',
          '',
          '',
        ]);
        expect(fourPlus.bodyRows[3], ['', '', '', '', '', '']);
        expect(fourPlus.bodyRows[4], ['KAT 1', '', '', '', '', '']);
      },
    );

    test(
      'PDF export keeps third duplicate row separate when day counts differ',
      () async {
        const snapshotService = ExportSnapshotService();
        const tableService = ExportTableService();
        const pdfService = PdfExportService();
        final snapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(
                location: 'BAHÇE',
                teachersByDay: ['Ali', 'Ayşe', '', '', ''],
              ),
              RosterRow(
                location: 'bahçe',
                teachersByDay: ['Veli', '', '', '', ''],
              ),
              RosterRow(
                location: 'BAHÇE',
                teachersByDay: ['Can', '', '', '', ''],
              ),
            ],
          ),
        );

        final pdfBytes = await pdfService.buildPdf(snapshot);
        final table = tableService.buildWeekTable(snapshot.weeks.single);
        final pdfCells = pdfService.debugBodyCells(snapshot.weeks.single);

        expect(pdfBytes.take(4), [37, 80, 68, 70]);
        expect(table.bodyRows, hasLength(3));
        expect(table.bodyRows.map((row) => row[1]), ['Ali', 'Veli', 'Can']);
        expect(table.bodyRows.map((row) => row[2]), ['Ayşe', '', '']);
        expect(_hasSpan(table.spans, 0, 0, 1), isTrue);
        expect(_hasSpan(table.spans, 0, 0, 2), isFalse);
        expect(_hasSpan(table.spans, 1, 0, 1), isFalse);
        expect(_hasSpan(table.spans, 2, 0, 1), isTrue);
        expect(_pdfBodyCell(pdfCells, 0, 0).rowSpan, 2);
        expect(_hasPdfBodyCell(pdfCells, 0, 1), isFalse);
        expect(_pdfBodyCell(pdfCells, 0, 2).rowSpan, 1);
        expect(_pdfBodyCell(pdfCells, 2, 0).rowSpan, 2);
        expect(_hasPdfBodyCell(pdfCells, 2, 1), isFalse);
      },
    );

    test('PDF render applies duplicate rowSpan as 2, 2+1, and 2+2', () {
      const pdfService = PdfExportService();

      final twoCells = pdfService.debugBodyCells(
        _duplicateLocationWeek(startDate, endDate, 2),
      );
      expect(_pdfBodyCell(twoCells, 0, 0).rowSpan, 2);
      expect(_hasPdfBodyCell(twoCells, 0, 1), isFalse);

      final threeCells = pdfService.debugBodyCells(
        _duplicateLocationWeek(startDate, endDate, 3),
      );
      expect(_pdfBodyCell(threeCells, 0, 0).rowSpan, 2);
      expect(_hasPdfBodyCell(threeCells, 0, 1), isFalse);
      expect(_pdfBodyCell(threeCells, 0, 2).rowSpan, 1);

      final fourCells = pdfService.debugBodyCells(
        _duplicateLocationWeek(startDate, endDate, 4),
      );
      expect(_pdfBodyCell(fourCells, 0, 0).rowSpan, 2);
      expect(_hasPdfBodyCell(fourCells, 0, 1), isFalse);
      expect(_pdfBodyCell(fourCells, 0, 2).rowSpan, 2);
      expect(_hasPdfBodyCell(fourCells, 0, 3), isFalse);
    });

    test('PDF footer renders principal name and title on separate lines', () {
      const pdfService = PdfExportService();

      expect(pdfService.debugPrincipalFooterLines(' Şule Çağrı '), [
        'Şule Çağrı',
        'Müdür',
      ]);
      expect(pdfService.debugPrincipalFooterLines('   '), ['', 'Müdür']);
    });

    test(
      'PDF renderer applies newline line breaks for multi-teacher cell values',
      () async {
        const snapshotService = ExportSnapshotService();
        const pdfService = PdfExportService();
        final singleLineSnapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            principalName: '',
            rows: [
              RosterRow(location: 'Bahçe', teachersByDay: ['Çağrı Şule']),
            ],
          ),
        );
        final multiLineSnapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            principalName: '',
            rows: [
              RosterRow(location: 'Bahçe', teachersByDay: [r'Çağrı\nŞule']),
            ],
          ),
        );

        final singleBytes = await pdfService.buildPdf(singleLineSnapshot);
        final multiBytes = await pdfService.buildPdf(multiLineSnapshot);

        final singleBreakCount = _countPdfTextLineBreakOperators(singleBytes);
        final multiBreakCount = _countPdfTextLineBreakOperators(multiBytes);
        final singleDecodedStreams = _decodedPdfStreams(singleBytes).join('\n');
        final multiDecodedStreams = _decodedPdfStreams(multiBytes).join('\n');

        expect(singleBytes.take(4), [37, 80, 68, 70]);
        expect(multiBytes.take(4), [37, 80, 68, 70]);
        expect(_pdfPageCount(multiBytes), 1);
        expect(String.fromCharCodes(multiBytes), contains('/ToUnicode'));
        expect(multiBreakCount, greaterThanOrEqualTo(singleBreakCount));
        expect(multiDecodedStreams, isNot(equals(singleDecodedStreams)));
      },
    );

    test('Excel export writes structured table with duplicate merges', () {
      const snapshotService = ExportSnapshotService();
      const excelService = ExcelExportService();
      final snapshot = snapshotService.fromCurrentWeek(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          schoolName: 'Örnek Okul',
          principalName: 'Ayşe Müdür',
          rows: [
            RosterRow(
              location: 'Bahçe-1',
              teachersByDay: ['Ali', '', '', '', ''],
            ),
            RosterRow(
              location: 'bahçe\u20131',
              teachersByDay: ['', 'Ayşe', '', '', ''],
            ),
          ],
        ),
      );

      final bytes = excelService.buildWorkbook(snapshot);
      final workbook = xl.Excel.decodeBytes(bytes);
      final sheet = workbook.tables[ExcelExportService.sheetName]!;

      expect(bytes.take(2), [80, 75]);
      expect(_cellText(sheet, 0, 0), 'ÖRNEK OKUL');
      expect(_cellText(sheet, 1, 0), 'T1');
      expect(_cellText(sheet, 2, 0), 'NOBET YERI');
      expect(_cellText(sheet, 3, 0), 'Bahçe-1');
      expect(_cellText(sheet, 3, 1), 'Ali');
      expect(_cellText(sheet, 3, 2), 'Ayşe');
      expect(sheet.spannedItems, contains('A4:A5'));
      expect(sheet.spannedItems, contains('B4:B5'));
      expect(sheet.spannedItems, contains('C4:C5'));
    });

    test('PDF and Excel keep multi teacher cells on separate lines', () async {
      const snapshotService = ExportSnapshotService();
      const excelService = ExcelExportService();
      const pdfService = PdfExportService();
      const firstTeacher = '\u00C7a\u011Fr\u0131 \u00DCnl\u00FC';
      const secondTeacher = '\u015Eule \u00D6zt\u00FCrk';
      final encodedCell = '$firstTeacher\\n$secondTeacher';
      final snapshot = snapshotService.fromCurrentWeek(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bah\u00E7e', teachersByDay: [encodedCell]),
          ],
        ),
      );

      final pdfCells = pdfService.debugBodyCells(snapshot.weeks.single);
      final workbook = xl.Excel.decodeBytes(
        excelService.buildWorkbook(snapshot),
      );
      final sheet = workbook.tables[ExcelExportService.sheetName]!;

      expect(
        _pdfBodyCell(pdfCells, 1, 0).value,
        '$firstTeacher\n$secondTeacher',
      );
      expect(_cellText(sheet, 2, 1), '$firstTeacher\n$secondTeacher');
    });

    test(
      'Excel export includes unmerged logical data for round-trip safety',
      () {
        const snapshotService = ExportSnapshotService();
        const excelService = ExcelExportService();
        final snapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            schoolName: 'Örnek Okul',
            principalName: 'Ayşe Müdür',
            rows: [
              RosterRow(
                location: 'Bahçe-1',
                teachersByDay: ['Ali', '', '', '', ''],
              ),
              RosterRow(
                location: 'bahçe\u20131',
                teachersByDay: ['', 'Ayşe', '', '', ''],
              ),
            ],
          ),
        );

        final workbook = xl.Excel.decodeBytes(
          excelService.buildWorkbook(snapshot),
        );
        final dataSheet = workbook.tables[ExcelExportService.dataSheetName]!;

        expect(dataSheet.spannedItems, isEmpty);
        expect(_cellText(dataSheet, 0, 0), 'EXPORT_DATA_VERSION');
        expect(_cellText(dataSheet, 0, 1), '1');
        expect(_cellText(dataSheet, 2, 1), 'T1');
        expect(_cellText(dataSheet, 3, 1), '2026-02-02');
        expect(_cellText(dataSheet, 4, 1), '2026-02-06');
        expect(_cellText(dataSheet, 5, 1), 'Örnek Okul');
        expect(_cellText(dataSheet, 6, 1), 'Ayşe Müdür');
        expect(_cellText(dataSheet, 7, 1), '2');
        expect(_cellText(dataSheet, 8, 0), 'NOBET YERI');
        expect(_cellText(dataSheet, 9, 0), 'Bahçe-1');
        expect(_cellText(dataSheet, 9, 1), 'Ali');
        expect(_cellText(dataSheet, 10, 0), 'bahçe\u20131');
        expect(_cellText(dataSheet, 10, 2), 'Ayşe');
      },
    );

    test(
      'Excel logical sheet preserves encoded multi teacher data losslessly',
      () {
        const snapshotService = ExportSnapshotService();
        const excelService = ExcelExportService();
        const encodedCell = r'Ali Yilmaz\nAyse Demir';
        final snapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Bah\u00E7e', teachersByDay: [encodedCell]),
            ],
          ),
        );

        final workbook = xl.Excel.decodeBytes(
          excelService.buildWorkbook(snapshot),
        );
        final dataSheet = workbook.tables[ExcelExportService.dataSheetName]!;

        expect(_cellText(dataSheet, 9, 1), encodedCell);
      },
    );

    test(
      'PDF and Excel exports are built from the same snapshot instance',
      () async {
        const snapshotService = ExportSnapshotService();
        const excelService = ExcelExportService();
        const pdfService = PdfExportService();
        final snapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            schoolName: 'Örnek Okul',
            principalName: 'Ayşe Müdür',
            rows: [
              RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
            ],
          ),
        );

        final excelBytes = excelService.buildWorkbook(snapshot);
        final pdfBytes = await pdfService.buildPdf(snapshot);
        final workbook = xl.Excel.decodeBytes(excelBytes);
        final dataSheet = workbook.tables[ExcelExportService.dataSheetName]!;

        expect(snapshot.weeks, hasLength(1));
        expect(_cellText(dataSheet, 2, 1), snapshot.weeks.single.title);
        expect(
          _cellText(dataSheet, 9, 0),
          snapshot.weeks.single.rows.single.location,
        );
        expect(pdfBytes.take(4), [37, 80, 68, 70]);
        expect(_pdfPageCount(pdfBytes), 1);
      },
    );

    test(
      'PDF row count matches rendered table model and page grouping',
      () async {
        const tableService = ExportTableService();
        const pdfService = PdfExportService();
        const snapshotService = ExportSnapshotService();
        final emptyWeek = Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: const [],
        );
        final duplicateWeek = Week(
          title: 'T2',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Kat-1', teachersByDay: ['Ali']),
            RosterRow(location: 'Kat\u20131', teachersByDay: ['ALİ']),
          ],
        );

        expect(
          pdfService.debugRenderedRowCount(emptyWeek),
          2 + tableService.buildWeekTable(emptyWeek).bodyRows.length,
        );
        expect(
          pdfService.debugRenderedRowCount(duplicateWeek),
          2 + tableService.buildWeekTable(duplicateWeek).bodyRows.length,
        );

        final weeks = List<Week>.generate(5, (index) {
          return Week(
            title: 'T${index + 1}',
            startDate: startDate.add(Duration(days: index * 7)),
            endDate: endDate.add(Duration(days: index * 7)),
            rows: [
              RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
            ],
          );
        });
        final pdfBytes = await pdfService.buildPdf(
          snapshotService.fromPreviewWeeks(weeks),
        );

        expect(_pdfPageCount(pdfBytes), 2);
      },
    );

    test('PDF export embeds Turkish-capable unicode font data', () async {
      const snapshotService = ExportSnapshotService();
      final snapshot = snapshotService.fromCurrentWeek(
        Week(
          title: 'ÇĞİÖŞÜ Haftası',
          startDate: startDate,
          endDate: endDate,
          schoolName: 'İzmir Çalışkan Okulu',
          principalName: 'Şule Çağrı',
          rows: [
            RosterRow(
              location: 'Bahçe Öğretmen',
              teachersByDay: ['Ayşe', 'İpek', 'Çağrı', 'Özgür', 'Şule'],
            ),
          ],
        ),
      );

      final bytes = await const PdfExportService().buildPdf(snapshot);
      final pdfText = String.fromCharCodes(bytes);

      expect(bytes.take(4), [37, 80, 68, 70]);
      expect(pdfText, contains('/ToUnicode'));
      expect(pdfText, contains('/FontFile2'));
      expect(pdfText, contains('/CIDToGIDMap'));
    });

    test(
      'file service generates names and writes selected Excel bytes',
      () async {
        const snapshotService = ExportSnapshotService();
        const fileService = ExportFileService();
        final singleSnapshot = snapshotService.fromCurrentWeek(
          Week(
            title: 'T1',
            startDate: startDate,
            endDate: endDate,
            rows: [
              RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
            ],
          ),
        );
        final multiSnapshot = snapshotService.fromPreviewWeeks([
          singleSnapshot.weeks.single,
          Week(
            title: 'T2',
            startDate: DateTime(2026, 2, 9),
            endDate: DateTime(2026, 2, 13),
            rows: [
              RosterRow(location: 'Koridor', teachersByDay: ['Ayşe']),
            ],
          ),
        ]);
        final tempDir = await Directory.systemTemp.createTemp('nobet_export_');

        try {
          expect(
            fileService.suggestedFileName(singleSnapshot, ExportFileType.pdf),
            'nobet_ciktisi.pdf',
          );
          expect(
            fileService.suggestedFileName(multiSnapshot, ExportFileType.excel),
            'nobet_2026-02-02_2026-02-13.xlsx',
          );

          final savePath = '${tempDir.path}${Platform.pathSeparator}roster';
          final writerService = ExportFileService(
            saveLocationPicker: (request) async => FileSaveLocation(savePath),
          );
          final result = await writerService.exportExcel(singleSnapshot);

          expect(result, isNotNull);
          expect(result!.path.endsWith('.xlsx'), isTrue);
          final file = File(result.path);
          expect(await file.exists(), isTrue);
          final bytes = await file.readAsBytes();
          expect(bytes.take(2), [80, 75]);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'file service rejects empty bytes before opening save dialog',
      () async {
        var saveDialogCalled = false;
        var writerCalled = false;
        final service = ExportFileService(
          saveLocationPicker: (request) async {
            saveDialogCalled = true;
            return FileSaveLocation('unused.pdf');
          },
          bytesWriter: ({required path, required bytes, required type}) async {
            writerCalled = true;
          },
        );

        final result = await service.exportFile(
          Uint8List(0),
          ExportFileType.pdf,
        );

        expect(result.isError, isTrue);
        expect(result.message, 'Dışa aktarılacak dosya içeriği boş.');
        expect(saveDialogCalled, isFalse);
        expect(writerCalled, isFalse);
      },
    );

    test(
      'file service returns cancelled when save dialog is cancelled',
      () async {
        var writerCalled = false;
        final service = ExportFileService(
          saveLocationPicker: (request) async => null,
          bytesWriter: ({required path, required bytes, required type}) async {
            writerCalled = true;
          },
        );

        final result = await service.exportFile(
          Uint8List.fromList([1, 2, 3]),
          ExportFileType.pdf,
        );

        expect(result.isCancelled, isTrue);
        expect(writerCalled, isFalse);
      },
    );

    test('file service enforces export file extensions', () async {
      final paths = <String>[];
      final service = ExportFileService(
        saveLocationPicker: (request) async {
          final index = paths.length;
          return switch (index) {
            0 => FileSaveLocation('roster'),
            1 => FileSaveLocation('roster.pdf'),
            2 => FileSaveLocation('roster.PDF'),
            _ => FileSaveLocation('roster.txt'),
          };
        },
        bytesWriter: ({required path, required bytes, required type}) async {
          paths.add(path);
        },
      );

      await service.exportFile(Uint8List.fromList([1]), ExportFileType.pdf);
      await service.exportFile(Uint8List.fromList([1]), ExportFileType.pdf);
      await service.exportFile(Uint8List.fromList([1]), ExportFileType.pdf);
      await service.exportFile(Uint8List.fromList([1]), ExportFileType.pdf);

      expect(paths, [
        'roster.pdf',
        'roster.pdf',
        'roster.PDF',
        'roster.txt.pdf',
      ]);
    });

    test('file service sanitizes suggested file names safely', () async {
      Future<String> suggestedNameFor(String name) async {
        String? capturedName;
        final service = ExportFileService(
          saveLocationPicker: (request) async {
            capturedName = request.suggestedName;
            return null;
          },
        );

        await service.exportFile(
          Uint8List.fromList([1]),
          ExportFileType.pdf,
          suggestedName: name,
        );

        return capturedName!;
      }

      expect(
        await suggestedNameFor('nöbet<>:"|?*çizelgesi.pdf'),
        'nöbetçizelgesi.pdf',
      );
      expect(
        await suggestedNameFor('  nöbet    çizelgesi  2026.pdf  '),
        'nöbet çizelgesi 2026.pdf',
      );
      expect(
        await suggestedNameFor('nöbet çizelgesi.   '),
        'nöbet çizelgesi.pdf',
      );
      expect(await suggestedNameFor(' . .   '), 'nobet_ciktisi.pdf');
      expect(
        await suggestedNameFor('Nöbetçi Öğretmen Listesi 2026-02-02.pdf'),
        'Nöbetçi Öğretmen Listesi 2026-02-02.pdf',
      );
    });

    test('file service handles Windows and mixed path separators', () async {
      Future<String> suggestedNameFor(String name) async {
        String? capturedName;
        final service = ExportFileService(
          saveLocationPicker: (request) async {
            capturedName = request.suggestedName;
            return null;
          },
        );

        await service.exportFile(
          Uint8List.fromList([1]),
          ExportFileType.pdf,
          suggestedName: name,
        );

        return capturedName!;
      }

      expect(await suggestedNameFor(r'C:\Exports\nöbet.pdf'), 'nöbet.pdf');
      expect(await suggestedNameFor(r'C:\Exports/sub\karma.pdf'), 'karma.pdf');
      expect(await suggestedNameFor(r'C:\folder\file.pdf'), 'file.pdf');
      expect(await suggestedNameFor(r'/tmp\folder/sub\file.pdf'), 'file.pdf');
    });

    test(
      'file service rejects invalid selected filename characters before writing',
      () async {
        Future<void> expectRejected(String path) async {
          var writerCalled = false;
          final service = ExportFileService(
            saveLocationPicker: (request) async => FileSaveLocation(path),
            bytesWriter:
                ({required path, required bytes, required type}) async {
                  writerCalled = true;
                },
          );

          final result = await service.exportFile(
            Uint8List.fromList([1]),
            ExportFileType.pdf,
          );

          expect(result.isError, isTrue);
          expect(result.message, 'Geçersiz dosya yolu.');
          expect(writerCalled, isFalse);
        }

        const invalidCharacterPaths = {
          '<': 'bad<name.pdf',
          '>': 'bad>name.pdf',
          ':': 'bad:name.pdf',
          '"': 'bad"name.pdf',
          '/': 'bad/',
          r'\': 'bad\\',
          '|': 'bad|name.pdf',
          '?': 'bad?name.pdf',
          '*': 'bad*name.pdf',
        };

        for (final path in invalidCharacterPaths.values) {
          await expectRejected(path);
        }

        for (var codeUnit = 0; codeUnit <= 0x1F; codeUnit += 1) {
          await expectRejected('bad${String.fromCharCode(codeUnit)}name.pdf');
        }
      },
    );

    test(
      'file service rejects selected paths with empty base names before writing',
      () async {
        Future<void> expectRejected(String path) async {
          var writerCalled = false;
          final service = ExportFileService(
            saveLocationPicker: (request) async => FileSaveLocation(path),
            bytesWriter:
                ({required path, required bytes, required type}) async {
                  writerCalled = true;
                },
          );

          final result = await service.exportFile(
            Uint8List.fromList([1]),
            ExportFileType.pdf,
          );

          expect(result.isError, isTrue);
          expect(result.message, 'Geçersiz dosya yolu.');
          expect(writerCalled, isFalse);
        }

        await expectRejected('.pdf');
        await expectRejected('...pdf');
        await expectRejected('   .pdf');
      },
    );

    test('file service rejects directory paths before writing', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nobet_export_directory_',
      );

      try {
        final directoryPath =
            '${tempDir.path}${Platform.pathSeparator}target.pdf';
        await Directory(directoryPath).create();
        var writerCalled = false;
        final service = ExportFileService(
          saveLocationPicker: (request) async =>
              FileSaveLocation(directoryPath),
          bytesWriter: ({required path, required bytes, required type}) async {
            writerCalled = true;
          },
        );

        final result = await service.exportFile(
          Uint8List.fromList([1]),
          ExportFileType.pdf,
        );

        expect(result.isError, isTrue);
        expect(result.message, 'Geçersiz dosya yolu.');
        expect(writerCalled, isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('file service rejects link paths before writing', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nobet_export_link_',
      );

      try {
        final targetPath = '${tempDir.path}${Platform.pathSeparator}target.pdf';
        final linkPath = '${tempDir.path}${Platform.pathSeparator}link.pdf';
        await File(targetPath).writeAsBytes([1], flush: true);

        try {
          await Link(linkPath).create(targetPath);
        } on FileSystemException {
          markTestSkipped('Symbolic link creation is not available.');
          return;
        } on UnsupportedError {
          markTestSkipped('Symbolic link creation is not available.');
          return;
        }

        var writerCalled = false;
        final service = ExportFileService(
          saveLocationPicker: (request) async => FileSaveLocation(linkPath),
          bytesWriter: ({required path, required bytes, required type}) async {
            writerCalled = true;
          },
        );

        final result = await service.exportFile(
          Uint8List.fromList([1]),
          ExportFileType.pdf,
        );

        expect(result.isError, isTrue);
        expect(result.message, 'Geçersiz dosya yolu.');
        expect(writerCalled, isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'file service refuses existing destination without explicit overwrite confirmation',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'nobet_export_overwrite_',
        );

        try {
          final savePath =
              '${tempDir.path}${Platform.pathSeparator}existing.pdf';
          final file = File(savePath);
          await file.writeAsBytes([1, 2, 3], flush: true);

          final service = ExportFileService(
            saveLocationPicker: (request) async => FileSaveLocation(savePath),
          );

          final result = await service.exportFile(
            Uint8List.fromList([4, 5, 6]),
            ExportFileType.pdf,
          );

          expect(result.isError, isTrue);
          expect(
            result.message,
            'Var olan dosyanın üzerine yazmak için onay gerekiyor.',
          );
          expect(await file.readAsBytes(), [1, 2, 3]);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'file service cancels when overwrite confirmation is rejected',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'nobet_export_cancel_',
        );

        try {
          final savePath =
              '${tempDir.path}${Platform.pathSeparator}existing.pdf';
          final file = File(savePath);
          await file.writeAsBytes([1, 2, 3], flush: true);
          var confirmationAsked = false;

          final service = ExportFileService(
            saveLocationPicker: (request) async => FileSaveLocation(savePath),
            overwriteConfirmation: (path, type) async {
              confirmationAsked = true;
              return false;
            },
          );

          final result = await service.exportFile(
            Uint8List.fromList([4, 5, 6]),
            ExportFileType.pdf,
          );

          expect(confirmationAsked, isTrue);
          expect(result.isCancelled, isTrue);
          expect(await file.readAsBytes(), [1, 2, 3]);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('file service overwrites only after explicit confirmation', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nobet_export_confirm_',
      );

      try {
        final savePath = '${tempDir.path}${Platform.pathSeparator}existing.pdf';
        final file = File(savePath);
        await file.writeAsBytes([1, 2, 3], flush: true);

        final service = ExportFileService(
          saveLocationPicker: (request) async => FileSaveLocation(savePath),
          overwriteConfirmation: (path, type) async => true,
        );

        final result = await service.exportFile(
          Uint8List.fromList([4, 5, 6]),
          ExportFileType.pdf,
        );

        expect(result.isSuccess, isTrue);
        expect(result.path, savePath);
        expect(await file.readAsBytes(), [4, 5, 6]);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'file service removes backup sidecar after successful overwrite',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'nobet_export_backup_',
        );

        try {
          final savePath =
              '${tempDir.path}${Platform.pathSeparator}existing.pdf';
          final file = File(savePath);
          await file.writeAsBytes([1, 2, 3], flush: true);

          final service = ExportFileService(
            saveLocationPicker: (request) async => FileSaveLocation(savePath),
            overwriteConfirmation: (path, type) async => true,
          );

          final result = await service.exportFile(
            Uint8List.fromList([4, 5, 6]),
            ExportFileType.pdf,
          );

          expect(result.isSuccess, isTrue);
          expect(await file.readAsBytes(), [4, 5, 6]);
          expect(
            tempDir
                .listSync()
                .where((entity) => entity.path.endsWith('.bak'))
                .toList(),
            isEmpty,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'file service uses temporary sidecar paths for atomic writes',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'nobet_export_temp_',
        );
        final observedTempPaths = <String>{};
        final savePath = '${tempDir.path}${Platform.pathSeparator}export.pdf';
        final normalizedSavePath = savePath.replaceAll('\\', '/');
        final subscription = tempDir.watch().listen((event) {
          final normalizedEventPath = event.path.replaceAll('\\', '/');
          if (normalizedEventPath.startsWith('$normalizedSavePath.') &&
              normalizedEventPath.endsWith('.tmp')) {
            observedTempPaths.add(event.path);
          }
        });

        try {
          final service = ExportFileService(
            saveLocationPicker: (request) async => FileSaveLocation(savePath),
            overwriteConfirmation: (path, type) async => true,
          );

          final firstBytes = Uint8List.fromList(List<int>.filled(4096, 1));
          final secondBytes = Uint8List.fromList(List<int>.filled(4096, 2));

          final firstResult = await service.exportFile(
            firstBytes,
            ExportFileType.pdf,
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final secondResult = await service.exportFile(
            secondBytes,
            ExportFileType.pdf,
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));

          expect(firstResult.isSuccess, isTrue);
          expect(secondResult.isSuccess, isTrue);
          expect(observedTempPaths.length, greaterThanOrEqualTo(2));
          expect(File(savePath).readAsBytesSync(), secondBytes);
          expect(
            tempDir
                .listSync()
                .where((entity) => entity.path.endsWith('.tmp'))
                .toList(),
            isEmpty,
          );
        } finally {
          await subscription.cancel();
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('file service rejects invalid destination paths safely', () async {
      final service = ExportFileService(
        saveLocationPicker: (request) async => FileSaveLocation('bad:name.pdf'),
      );

      final result = await service.exportFile(
        Uint8List.fromList([1]),
        ExportFileType.pdf,
      );

      expect(result.isError, isTrue);
      expect(result.message, 'Geçersiz dosya yolu.');
    });

    test(
      'file service maps direct permission failures without writing',
      () async {
        Future<void> expectPermissionDenied(
          Object Function() buildError,
        ) async {
          var writerCalled = false;
          final service = ExportFileService(
            saveLocationPicker: (request) async => throw buildError(),
            bytesWriter:
                ({required path, required bytes, required type}) async {
                  writerCalled = true;
                },
          );

          final result = await service.exportFile(
            Uint8List.fromList([1]),
            ExportFileType.pdf,
          );

          expect(result.isError, isTrue);
          expect(result.message, 'Dosya yazma izni reddedildi.');
          expect(writerCalled, isFalse);
        }

        await expectPermissionDenied(
          () => FileSystemException(
            'Access is denied',
            'blocked.pdf',
            const OSError('Access is denied', 5),
          ),
        );
        await expectPermissionDenied(
          () => const PathAccessException(
            'blocked.pdf',
            OSError('Permission denied', 13),
          ),
        );
      },
    );

    test('file service maps invalid path failures without writing', () async {
      Future<void> expectInvalidPath(Object Function() buildError) async {
        var writerCalled = false;
        final service = ExportFileService(
          saveLocationPicker: (request) async => throw buildError(),
          bytesWriter: ({required path, required bytes, required type}) async {
            writerCalled = true;
          },
        );

        final result = await service.exportFile(
          Uint8List.fromList([1]),
          ExportFileType.pdf,
        );

        expect(result.isError, isTrue);
        expect(result.message, 'Geçersiz dosya yolu.');
        expect(writerCalled, isFalse);
      }

      await expectInvalidPath(
        () => FileSystemException(
          'Cannot find path',
          'missing.pdf',
          const OSError('The system cannot find the path specified', 3),
        ),
      );
      await expectInvalidPath(
        () => FileSystemException(
          'Invalid path',
          'bad.pdf',
          const OSError(
            'The filename, directory name, or volume label syntax is incorrect',
            123,
          ),
        ),
      );
      await expectInvalidPath(() => ArgumentError('bad path'));
    });

    test('file service maps generic failures without writing', () async {
      var writerCalled = false;
      final service = ExportFileService(
        saveLocationPicker: (request) async {
          throw StateError('unexpected failure');
        },
        bytesWriter: ({required path, required bytes, required type}) async {
          writerCalled = true;
        },
      );

      final result = await service.exportFile(
        Uint8List.fromList([1]),
        ExportFileType.pdf,
      );

      expect(result.isError, isTrue);
      expect(result.message, 'Dosya kaydedilemedi.');
      expect(writerCalled, isFalse);
    });

    test('legacy file export maps generic failures without writing', () async {
      const snapshotService = ExportSnapshotService();
      final snapshot = snapshotService.fromCurrentWeek(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
          ],
        ),
      );
      var writerCalled = false;
      final service = ExportFileService(
        saveLocationPicker: (request) async {
          throw StateError('unexpected failure');
        },
        bytesWriter: ({required path, required bytes, required type}) async {
          writerCalled = true;
        },
      );

      await expectLater(
        service.exportExcel(snapshot),
        throwsA(
          isA<ExportFileException>().having(
            (error) => error.message,
            'message',
            'Dosya kaydedilemedi.',
          ),
        ),
      );
      expect(writerCalled, isFalse);
    });

    test('file service maps write failures predictably', () async {
      const snapshotService = ExportSnapshotService();
      final snapshot = snapshotService.fromCurrentWeek(
        Week(
          title: 'T1',
          startDate: startDate,
          endDate: endDate,
          rows: [
            RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
          ],
        ),
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'nobet_export_permission_',
      );
      final service = ExportFileService(
        saveLocationPicker: (request) async {
          return FileSaveLocation(
            '${tempDir.path}${Platform.pathSeparator}${request.suggestedName}',
          );
        },
        bytesWriter: ({required path, required bytes, required type}) async {
          throw FileSystemException(
            'Access is denied',
            path,
            const OSError('Access is denied', 5),
          );
        },
      );

      try {
        expect(
          () => service.exportExcel(snapshot),
          throwsA(
            isA<ExportFileException>().having(
              (error) => error.message,
              'message',
              'Dosya yazma izni reddedildi.',
            ),
          ),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });


    test('aylık PDF başlığı AYLIK içerir, HAFTASI içermez', () async {
      const pdfService = PdfExportService();
      const snapshotService = ExportSnapshotService();
      final svc = WeekService();
      final week = svc.buildWeek(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        rows: const [],
        mode: PlanningMode.monthly,
      );
      expect(week.title, contains('AYLIK'));
      expect(week.title, isNot(contains('HAFTASI')));
      final snapshot = snapshotService.fromCurrentWeek(week);
      final bytes = await pdfService.buildPdf(snapshot);
      expect(bytes, isNotEmpty);
    });

    test('haftalık PDF başlığı HAFTASI içerir, AYLIK içermez', () async {
      const pdfService = PdfExportService();
      const snapshotService = ExportSnapshotService();
      final svc = WeekService();
      final week = svc.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: const [],
      );
      expect(week.title, contains('HAFTASI'));
      expect(week.title, isNot(contains('AYLIK')));
      final snapshot = snapshotService.fromCurrentWeek(week);
      final bytes = await pdfService.buildPdf(snapshot);
      expect(bytes, isNotEmpty);
    });

    test('aylık Excel başlığı AYLIK içerir, HAFTASI içermez', () {
      const excelService = ExcelExportService();
      const snapshotService = ExportSnapshotService();
      final svc = WeekService();
      final week = svc.buildWeek(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        rows: const [],
        mode: PlanningMode.monthly,
      );
      final snapshot = snapshotService.fromCurrentWeek(week);
      final bytes = excelService.buildWorkbook(snapshot);
      final workbook = xl.Excel.decodeBytes(bytes);
      final sheet = workbook.tables[ExcelExportService.sheetName]!;
      final titleCell = _cellText(sheet, 0, 0);
      expect(titleCell, contains('AYLIK'));
      expect(titleCell, isNot(contains('HAFTASI')));
    });

    test('haftalık Excel başlığı HAFTASI içerir, AYLIK içermez', () {
      const excelService = ExcelExportService();
      const snapshotService = ExportSnapshotService();
      final svc = WeekService();
      final week = svc.buildWeek(
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: const [],
      );
      final snapshot = snapshotService.fromCurrentWeek(week);
      final bytes = excelService.buildWorkbook(snapshot);
      final workbook = xl.Excel.decodeBytes(bytes);
      final sheet = workbook.tables[ExcelExportService.sheetName]!;
      final titleCell = _cellText(sheet, 0, 0);
      expect(titleCell, contains('HAFTASI'));
      expect(titleCell, isNot(contains('AYLIK')));
    });
    group('Multi-week (monthly) export', () {
      const snapshotService = ExportSnapshotService();
      const tableService = ExportTableService();
      const excelService = ExcelExportService();

      List<Week> fourWeeks() {
        final base = DateTime(2026, 4, 1);
        return List<Week>.generate(4, (i) {
          return Week(
            title: 'W${i + 1}',
            startDate: base.add(Duration(days: i * 7)),
            endDate: base.add(Duration(days: i * 7 + 4)),
            schoolName: 'Okul',
            principalName: 'Müdür',
            rows: [
              RosterRow(
                location: 'Bahçe',
                teachersByDay: ['Ali', '', '', '', ''],
              ),
            ],
          );
        });
      }

      test('ExportSnapshot holds 4 weeks with correct flags', () {
        final snapshot = snapshotService.fromPreviewWeeks(fourWeeks());
        expect(snapshot.weeks, hasLength(4));
        expect(snapshot.isSingleWeek, isFalse);
        expect(snapshot.isMultiWeek, isTrue);
        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.weeks.map((w) => w.title), ['W1', 'W2', 'W3', 'W4']);
      });

      test('ExportTableService produces 4 independent tables in order', () {
        final weeks = fourWeeks();
        final tables = weeks.map(tableService.buildWeekTable).toList();
        expect(tables, hasLength(4));
        for (final table in tables) {
          expect(table.bodyRows, hasLength(1));
          expect(table.bodyRows.first.first, 'Bahçe');
        }
      });

      test('PDF export with 4 weeks produces bytes on 1 page', () async {
        final snapshot = snapshotService.fromPreviewWeeks(fourWeeks());
        final bytes = await const PdfExportService().buildPdf(snapshot);
        expect(bytes, isNotEmpty);
        expect(bytes.take(4), [37, 80, 68, 70]);
        expect(_pdfPageCount(bytes), 1);
      });

      test('Excel export with 4 weeks preserves all 4 in Nobet_Data sheet', () {
        final snapshot = snapshotService.fromPreviewWeeks(fourWeeks());
        final bytes = excelService.buildWorkbook(snapshot);
        expect(bytes, isNotEmpty);
        final workbook = xl.Excel.decodeBytes(bytes);
        final dataSheet = workbook.tables[ExcelExportService.dataSheetName]!;

        // Each week block = 7 header rows + 1 data row + 1 separator = 10 rows.
        // Starts at row 1 (row 0 = EXPORT_DATA_VERSION).
        for (var i = 0; i < 4; i++) {
          final weekStart = 1 + i * 10;
          expect(_cellText(dataSheet, weekStart, 0), 'WEEK_INDEX');
          expect(_cellText(dataSheet, weekStart, 1), '${i + 1}');
          expect(_cellText(dataSheet, weekStart + 1, 0), 'TITLE');
          expect(_cellText(dataSheet, weekStart + 1, 1), 'W${i + 1}');
        }
      });

      test('displayRange same year: "01 Nisan - 30 Nisan 2026"', () {
        final result = displayRange(DateTime(2026, 4, 1), DateTime(2026, 4, 30));
        expect(result, '01 Nisan - 30 Nisan 2026');
      });

      test('displayRange cross-year: "29 Aralık 2025 - 25 Ocak 2026"', () {
        final result =
            displayRange(DateTime(2025, 12, 29), DateTime(2026, 1, 25));
        expect(result, '29 Aralık 2025 - 25 Ocak 2026');
      });

      test('multi-week Excel range row appears on Nobet sheet', () {
        final snapshot = snapshotService.fromPreviewWeeks(fourWeeks());
        final bytes = excelService.buildWorkbook(snapshot);
        final workbook = xl.Excel.decodeBytes(bytes);
        final sheet = workbook.tables[ExcelExportService.sheetName]!;
        // fourWeeks: schoolName='Okul' → row 0=school, row 1=range, row 2=W1 title...
        final rangeText = _cellText(sheet, 1, 0);
        expect(rangeText, contains('Nisan'));
        expect(rangeText, contains('2026'));
      });

      test('single-week Excel export header unchanged (no range row)', () {
        final week = Week(
          title: '01.04.2026 - 05.04.2026',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 5),
          rows: [
            RosterRow(location: 'Bahçe', teachersByDay: ['Ali', '', '', '', '']),
          ],
        );
        final snapshot = snapshotService.fromCurrentWeek(week);
        final bytes = excelService.buildWorkbook(snapshot);
        final workbook = xl.Excel.decodeBytes(bytes);
        final sheet = workbook.tables[ExcelExportService.sheetName]!;
        // row 0 = title, row 1 = NOBET YERI header
        expect(_cellText(sheet, 0, 0), '01.04.2026 - 05.04.2026');
        expect(_cellText(sheet, 1, 0), 'NOBET YERI');
      });

      test('multi-week PDF export produces non-empty bytes and range in content',
          () async {
        final snapshot = snapshotService.fromPreviewWeeks(fourWeeks());
        final bytes = await const PdfExportService().buildPdf(snapshot);
        expect(bytes, isNotEmpty);
        expect(bytes.take(4), [37, 80, 68, 70]);
      });
    });
  });

  group('Stress tests', () {
    const normalizer = TextNormalizer();
    const duplicateLocationService = DuplicateLocationService();
    const rosterService = RosterService();
    final weekService = WeekService();

    test('random unicode text normalization is deterministic and safe', () {
      final random = Random(20260421);

      for (var i = 0; i < 250; i++) {
        final value = _randomUnicodeText(random, maxLength: 180);

        final display = normalizer.displayClean(value);
        final canonical = normalizer.canonical(value);
        final duplicateKey = normalizer.duplicateLocationKey(value);

        expect(display, normalizer.displayClean(display));
        expect(canonical, normalizer.canonical(value));
        expect(duplicateKey, normalizer.duplicateLocationKey(value));
        expect(duplicateKey.contains(RegExp(r'\s')), isFalse);
        expect(_containsSupportedDash(duplicateKey), isFalse);
      }
    });

    test('random duplicate-location comparisons never crash', () {
      final random = Random(1729);

      for (var i = 0; i < 200; i++) {
        final left = _randomUnicodeText(random, maxLength: 120);
        final right = _randomUnicodeText(random, maxLength: 120);

        final result = duplicateLocationService.isDuplicateLocation(
          left,
          right,
        );
        final leftKey = duplicateLocationService.duplicateLocationKey(left);
        final rightKey = duplicateLocationService.duplicateLocationKey(right);

        expect(result, leftKey.isNotEmpty && leftKey == rightKey);
      }
    });

    test(
      'random roster rows stay five-cell and round-trip rotation safely',
      () {
        final random = Random(8675309);

        for (var sample = 0; sample < 150; sample++) {
          final rowCount = random.nextInt(24);
          final rows = List<RosterRow>.generate(rowCount, (_) {
            return RosterRow(
              location: _maybeNullText(random, maxLength: 160),
              teachersByDay: _randomTeacherCells(random),
            );
          });

          final normalized = rosterService.normalizeRows(rows);
          final forward = rosterService.rotateForward(rows);
          final backward = rosterService.rotateBackward(forward);

          expect(forward, hasLength(normalized.length));
          expect(backward, hasLength(normalized.length));

          for (var rowIndex = 0; rowIndex < normalized.length; rowIndex++) {
            expect(forward[rowIndex].teachersByDay, hasLength(rosterDayCount));
            expect(backward[rowIndex].teachersByDay, hasLength(rosterDayCount));
            expect(backward[rowIndex].location, normalized[rowIndex].location);
            expect(
              backward[rowIndex].teachersByDay,
              normalized[rowIndex].teachersByDay,
            );
          }
        }
      },
    );

    test('extreme-length roster values normalize and rotate safely', () {
      final longLocation =
          '${List.filled(500, 'Bah\u00E7e-').join()}\u0130dare';
      final longTeacher =
          '${List.filled(400, 'Ali Veli \u015Eahin ').join()}\u0130pek';
      final rows = [
        RosterRow(
          location: longLocation,
          teachersByDay: [
            longTeacher,
            null,
            '',
            '  Ay\u015Fe  ',
            'Can',
            'extra',
          ],
        ),
        RosterRow(
          location: '$longLocation\u2013alt',
          teachersByDay: ['', longTeacher, null, '', 'Deniz'],
        ),
      ];

      final normalized = rosterService.normalizeRows(rows);
      final rotated = rosterService.rotateForward(rows);

      expect(normalized, hasLength(2));
      expect(rotated, hasLength(2));
      expect(
        normalized.every((row) => row.teachersByDay.length == rosterDayCount),
        isTrue,
      );
      expect(
        rotated.every((row) => row.teachersByDay.length == rosterDayCount),
        isTrue,
      );
      expect(
        normalized.first.teachersByDay.first.endsWith('\u0130pek'),
        isTrue,
      );
    });

    test('random valid date titles parse consistently', () {
      final random = Random(314159);

      for (var i = 0; i < 120; i++) {
        final startMonth = random.nextInt(12) + 1;
        final startDay = random.nextInt(_daysInMonth(2026, startMonth)) + 1;
        final start = DateTime(2026, startMonth, startDay);
        final end = start.add(Duration(days: random.nextInt(12)));
        final title = weekService.buildTitle(start, end);

        final parsed = weekService.parseTitle(title, 2026);

        expect(parsed.startDate, start);
        expect(parsed.endDate, end);
        expect(parsed.suffix, titleSuffix);
      }
    });

    test(
      'random malformed titles either parse or throw FormatException only',
      () {
        final random = Random(271828);
        final invalidSeeds = [
          '',
          '   ',
          'not a title',
          '2 \u015EUBAT-6 \u015EUBAT',
          '0 \u015EUBAT-6 MART $titleSuffix',
          '31 \u015EUBAT-6 MART $titleSuffix',
          '2 UNKNOWN-6 MART $titleSuffix',
          '${List.filled(4096, 'A').join()} $titleSuffix',
        ];

        for (final title in invalidSeeds) {
          _expectParseIsPredictable(weekService, title);
        }

        for (var i = 0; i < 250; i++) {
          final title = _randomTitleLikeText(random);
          _expectParseIsPredictable(weekService, title);
        }
      },
    );
  });
}

String? _maybeNullText(Random random, {required int maxLength}) {
  if (random.nextInt(9) == 0) {
    return null;
  }
  return _randomUnicodeText(random, maxLength: maxLength);
}

List<String?>? _randomTeacherCells(Random random) {
  if (random.nextInt(10) == 0) {
    return null;
  }

  final length = random.nextInt(11);
  return List<String?>.generate(length, (_) {
    return _maybeNullText(random, maxLength: 100);
  });
}

String _randomUnicodeText(Random random, {required int maxLength}) {
  final length = random.nextInt(maxLength + 1);
  final tokens = <String>[
    '',
    ' ',
    '\t',
    '\n',
    '-',
    '\u2010',
    '\u2011',
    '\u2012',
    '\u2013',
    '\u2014',
    '\u2212',
    'A',
    'i',
    '\u0131',
    '\u0130',
    'I\u0307',
    'C\u0327',
    'S\u0327',
    'G\u0306',
    'O\u0308',
    'U\u0308',
    'Ali',
    'Ay\u015Fe',
    'Bah\u00E7e',
    'Koridor',
    '\u00D6\u011Fretmen',
    '123',
    '/',
    '.',
    '()',
  ];

  final buffer = StringBuffer();
  while (buffer.length < length) {
    buffer.write(tokens[random.nextInt(tokens.length)]);
  }
  final value = buffer.toString();
  return value.length <= length ? value : value.substring(0, length);
}

bool _containsSupportedDash(String value) {
  return RegExp(
    '[\\-\u2010\u2011\u2012\u2013\u2014\u2015\u2212\uFE58\uFE63\uFF0D]',
    unicode: true,
  ).hasMatch(value);
}

bool _hasSpan(
  List<ExportCellSpan> spans,
  int column,
  int startRow,
  int endRow,
) {
  return spans.any((span) {
    return span.column == column &&
        span.startRow == startRow &&
        span.endRow == endRow;
  });
}

Week _duplicateLocationWeek(
  DateTime startDate,
  DateTime endDate,
  int rowCount,
) {
  return Week(
    title: 'T1',
    startDate: startDate,
    endDate: endDate,
    rows: List<RosterRow>.generate(rowCount, (index) {
      return RosterRow(
        location: index.isEven ? 'BAHÇE' : 'bahçe',
        teachersByDay: ['P${index + 1}', '', '', '', ''],
      );
    }),
  );
}

bool _hasPdfBodyCell(List<PdfBodyCellDebug> cells, int column, int row) {
  return cells.any((cell) => cell.column == column && cell.row == row);
}

PdfBodyCellDebug _pdfBodyCell(
  List<PdfBodyCellDebug> cells,
  int column,
  int row,
) {
  return cells.singleWhere((cell) {
    return cell.column == column && cell.row == row;
  });
}

String _cellText(xl.Sheet sheet, int row, int column) {
  final value = sheet
      .cell(xl.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
      .value;
  return value?.toString() ?? '';
}

int _pdfPageCount(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  return RegExp(r'/Type\s*/Page\b').allMatches(text).length;
}

int _countPdfTextLineBreakOperators(List<int> bytes) {
  final streamContents = _decodedPdfStreams(bytes);
  var count = 0;
  for (final content in streamContents) {
    count += RegExp(r'(?<!\S)T\*(?!\S)').allMatches(content).length;
  }
  return count;
}

List<String> _decodedPdfStreams(List<int> bytes) {
  const streamToken = 'stream';
  const endStreamToken = 'endstream';
  const flateDecodeToken = '/FlateDecode';
  final streamBytes = ascii.encode(streamToken);
  final endStreamBytes = ascii.encode(endStreamToken);
  final result = <String>[];
  var searchFrom = 0;

  while (true) {
    final streamStart = _indexOfBytes(bytes, streamBytes, searchFrom);
    if (streamStart < 0) {
      break;
    }

    var payloadStart = streamStart + streamBytes.length;
    if (payloadStart < bytes.length && bytes[payloadStart] == 13) {
      payloadStart += 1;
    }
    if (payloadStart < bytes.length && bytes[payloadStart] == 10) {
      payloadStart += 1;
    }

    final endStreamStart = _indexOfBytes(bytes, endStreamBytes, payloadStart);
    if (endStreamStart < 0) {
      break;
    }

    var payloadEnd = endStreamStart;
    if (payloadEnd > payloadStart && bytes[payloadEnd - 1] == 10) {
      payloadEnd -= 1;
    }
    if (payloadEnd > payloadStart && bytes[payloadEnd - 1] == 13) {
      payloadEnd -= 1;
    }

    final dictionaryStart = _lastIndexOfByte(bytes, 60, streamStart);
    final dictionaryEnd = streamStart;
    final dictionarySliceStart = dictionaryStart < 0
        ? (streamStart - 128).clamp(0, bytes.length)
        : dictionaryStart;
    final dictionaryText = latin1.decode(
      bytes.sublist(dictionarySliceStart, dictionaryEnd),
      allowInvalid: true,
    );

    var payload = bytes.sublist(payloadStart, payloadEnd);
    if (dictionaryText.contains(flateDecodeToken)) {
      try {
        payload = ZLibDecoder().convert(payload);
      } on FormatException {
        payload = const <int>[];
      }
    }

    if (payload.isNotEmpty) {
      result.add(latin1.decode(payload, allowInvalid: true));
    }

    searchFrom = endStreamStart + endStreamBytes.length;
  }

  return List<String>.unmodifiable(result);
}

int _indexOfBytes(List<int> source, List<int> pattern, int start) {
  if (pattern.isEmpty || start < 0 || start >= source.length) {
    return -1;
  }
  for (var i = start; i <= source.length - pattern.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length; j++) {
      if (source[i + j] != pattern[j]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return i;
    }
  }
  return -1;
}

int _lastIndexOfByte(List<int> source, int value, int startExclusive) {
  final start = startExclusive.clamp(0, source.length);
  for (var i = start - 1; i >= 0; i--) {
    if (source[i] == value) {
      return i;
    }
  }
  return -1;
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

String _randomTitleLikeText(Random random) {
  final months = [
    ...turkishMonths,
    'Ocak',
    '\u015Eubat',
    'Nisan',
    'INVALID',
    'MAYIS',
  ];
  final separators = ['-', '\u2013', '/', ' ', '--'];
  final suffixes = [
    titleSuffix,
    'Haftas\u0131 N\u00F6bet\u00E7i \u00D6\u011Fretmen Listesi',
    '',
    'WRONG SUFFIX',
    '${List.filled(random.nextInt(512), 'X').join()} $titleSuffix',
  ];

  if (random.nextBool()) {
    return _randomUnicodeText(random, maxLength: 600);
  }

  final firstDay = random.nextInt(40).toString();
  final secondDay = random.nextInt(40).toString();
  final firstMonth = months[random.nextInt(months.length)];
  final secondMonth = months[random.nextInt(months.length)];
  final separator = separators[random.nextInt(separators.length)];
  final suffix = suffixes[random.nextInt(suffixes.length)];
  final maybeYear = random.nextInt(4) == 0
      ? ' ${2000 + random.nextInt(40)}'
      : '';

  return '$firstDay $firstMonth$separator$secondDay $secondMonth$maybeYear $suffix';
}

void _expectParseIsPredictable(WeekService service, String title) {
  try {
    final parsed = service.parseTitle(title, 2026);
    expect(parsed.startDate.year, inInclusiveRange(1, 9999));
    expect(parsed.endDate.year, inInclusiveRange(1, 9999));
    expect(parsed.suffix, titleSuffix);
  } on FormatException {
    return;
  } catch (error) {
    fail(
      'Expected parseTitle to return a parsed title or FormatException, got $error',
    );
  }
}
