import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart';

import 'package:nobetci_program_mobile/main.dart';
import 'package:nobetci_program_mobile/models/roster_row.dart';
import 'package:nobetci_program_mobile/models/week.dart';
import 'package:nobetci_program_mobile/services/export_file_service.dart';
import 'package:nobetci_program_mobile/services/export_snapshot_service.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/roster_home_screen.dart';

void main() {
  testWidgets('shows current roster state', (WidgetTester tester) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Bahçe'), 120);
    expect(find.text('Bahçe'), findsOneWidget);
    expect(find.text('PAZARTESİ'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Ali Yılmaz'), 120);
    expect(find.text('Ali Yılmaz'), findsOneWidget);
  });

  testWidgets('baseline home shows week metadata, grid, and export actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.textContaining('2 ŞUBAT-6 ŞUBAT'), findsOneWidget);
    expect(find.text('02.02.2026 - 06.02.2026'), findsOneWidget);
    expect(find.text('Günlük Plan'), findsOneWidget);
    expect(find.text('Bahçe'), findsOneWidget);
    expect(find.text('Koridor'), findsOneWidget);
    expect(find.text('Kantin'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Export PDF'), 120);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
  });

  testWidgets('baseline edit navigation exposes grid edit fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Hafta Düzenle'), findsOneWidget);
    expect(find.text('Tarih Aralığı'), findsOneWidget);
    expect(find.text('Okul'), findsOneWidget);
    expect(find.text('Müdür'), findsWidgets);
    expect(find.text('Günlük Düzenleme'), findsOneWidget);
    expect(find.text('Görev Yeri Ekle'), findsOneWidget);
    expect(find.text('Seçili gün: PAZARTESİ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-grid-teacher-input-0-0')),
      findsOneWidget,
    );
  });

  testWidgets('home dashboard shows weekly summary values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.text('Hafta Özeti'), findsOneWidget);
    expect(find.text('Görev yeri: 3'), findsOneWidget);
    expect(find.text('Dolu: 8'), findsOneWidget);
    expect(find.text('Boş: 7'), findsOneWidget);
    expect(find.text('PAZARTESİ'), findsWidgets);

    await tester.tap(find.text('Hafta Özeti'));
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsNWidgets(3));
    expect(find.text('SAL'), findsWidgets);
    expect(find.text('2/3'), findsWidgets);
  });

  testWidgets('home dashboard handles large text without hiding summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: const NobetciProgramApp(),
      ),
    );

    expect(find.text('Hafta Özeti'), findsOneWidget);
    expect(find.text('Görev yeri: 3'), findsOneWidget);
    expect(find.text('Dolu: 8'), findsOneWidget);
    expect(find.text('Boş: 7'), findsOneWidget);
  });

  testWidgets('home day grid switches selected day and shows assignments', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.text('Günlük Plan'), findsOneWidget);
    expect(find.text('Ali Yılmaz'), findsOneWidget);
    expect(find.text('Fatma Şahin'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.text('SAL'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayşe Demir'), findsOneWidget);
    expect(find.text('Burak Çelik'), findsOneWidget);
  });

  testWidgets('home day grid shows empty cells for selected day', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.text('PER'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mehmet Kaya'), findsOneWidget);
    expect(find.text('-'), findsWidgets);
  });

  testWidgets('home day grid cell tap shows assignment detail', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byKey(const ValueKey('day-grid-cell-0-2')));
    await tester.pumpAndSettle();

    expect(find.text('Atama Detayı'), findsOneWidget);
    expect(find.text('Gün: PAZARTESİ'), findsOneWidget);
    expect(find.text('Görev yeri: Kantin'), findsOneWidget);
    expect(find.text('Öğretmen: Boş'), findsOneWidget);
    expect(find.text('Satır: 3'), findsOneWidget);
  });

  testWidgets('home day grid duplicate row selection shows row identity', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final state = RosterState(
      currentWeek: Week(
        title: 'Tekrar Hafta',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
          RosterRow(location: 'Bahçe', teachersByDay: ['Ayşe']),
        ],
      ),
    );

    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.tap(find.byKey(const ValueKey('day-grid-cell-0-1')));
    await tester.pumpAndSettle();

    expect(find.text('Atama Detayı'), findsOneWidget);
    expect(find.text('Görev yeri: Bahçe'), findsOneWidget);
    expect(find.text('Öğretmen: Ayşe'), findsOneWidget);
    expect(find.text('Satır: 2'), findsOneWidget);
    expect(find.text('Tekrar eden görev yeri'), findsOneWidget);
  });

  testWidgets('home day grid visual labels handle large text and duplicates', (
    WidgetTester tester,
  ) async {
    _useMobileTestView(tester);
    final state = RosterState(
      currentWeek: Week(
        title: 'Tekrar Hafta',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahçe', teachersByDay: ['Ali']),
          RosterRow(location: 'Bahçe', teachersByDay: ['']),
        ],
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: MaterialApp(home: RosterHomeScreen(state: state)),
      ),
    );

    expect(find.text('Seçili gün: PAZARTESİ'), findsOneWidget);
    expect(find.text('1/2 dolu'), findsOneWidget);
    expect(find.text('Dolu'), findsOneWidget);
    expect(find.text('Boş'), findsOneWidget);
    expect(find.text('Tekrar'), findsWidgets);
  });

  testWidgets('home grid stays primary content with large mixed data', (
    WidgetTester tester,
  ) async {
    _useMobileTestView(tester);
    final state = RosterState(
      currentWeek: Week(
        title: 'Büyük Veri Haftası',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: [
          RosterRow(location: 'Bahce', teachersByDay: ['Ali', 'Ayse', 'Can']),
          RosterRow(location: 'Bahce', teachersByDay: ['', 'Bora', '']),
          RosterRow(location: 'Koridor', teachersByDay: ['Cem', '', 'Duru']),
          RosterRow(
            location: 'Kantin',
            teachersByDay: ['Gul', 'Hakan', 'Isil'],
          ),
          RosterRow(location: 'Kutuphane', teachersByDay: ['', '', 'Jale']),
          RosterRow(
            location: 'Laboratuvar',
            teachersByDay: ['Kemal', 'Lale', ''],
          ),
          RosterRow(
            location: 'Spor Salonu',
            teachersByDay: ['Mert', '', 'Nil'],
          ),
          RosterRow(location: 'Bahce', teachersByDay: ['Oya', 'Pelin', '']),
          RosterRow(location: 'Giris', teachersByDay: ['', 'Riza', 'Seda']),
          RosterRow(location: 'Yemekhane', teachersByDay: ['Tuna', '', '']),
        ],
      ),
    );

    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));
    await tester.pumpAndSettle();

    final viewport = Rect.fromLTWH(
      0,
      0,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );

    double visibleRatio(Finder finder) {
      final rect = tester.getRect(finder);
      final visibleWidth = math.max(
        0.0,
        math.min(rect.right, viewport.right) -
            math.max(rect.left, viewport.left),
      );
      final visibleHeight = math.max(
        0.0,
        math.min(rect.bottom, viewport.bottom) -
            math.max(rect.top, viewport.top),
      );
      return (visibleWidth * visibleHeight) / (rect.width * rect.height);
    }

    final gridCard = find
        .ancestor(
          of: find.byKey(const ValueKey('day-grid-selected-day-label')),
          matching: find.byType(Card),
        )
        .first;

    expect(visibleRatio(gridCard), greaterThanOrEqualTo(0.80));
    for (var rowIndex = 0; rowIndex < 4; rowIndex += 1) {
      expect(
        visibleRatio(find.byKey(ValueKey('day-grid-cell-0-$rowIndex'))),
        greaterThan(0.90),
      );
    }
    expect(visibleRatio(find.text('Ali')), greaterThan(0.90));
    expect(find.text('Dolu'), findsWidgets);
    expect(find.text('Boş'), findsWidgets);
    expect(find.text('Tekrar'), findsWidgets);
  });

  testWidgets('next and previous week actions update visible week', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.textContaining('2 ŞUBAT-6 ŞUBAT'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump();

    expect(find.textContaining('9 ŞUBAT-13 ŞUBAT'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pump();

    expect(find.textContaining('2 ŞUBAT-6 ŞUBAT'), findsOneWidget);
  });

  testWidgets('edit screen saves roster changes to home state', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Hafta Düzenle'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Yeni Okul');
    await tester.tap(find.byKey(const ValueKey('edit-grid-edit-location-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-location-field')),
      'Yeni Bahçe',
    );
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-teacher-input-0-0')),
      'Yeni Öğretmen',
    );
    await tester.pump();

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    expect(find.text('Hafta kaydedildi.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Yeni Bahçe'), 120);
    expect(find.text('Yeni Bahçe'), findsOneWidget);
    expect(find.text('Yeni Öğretmen'), findsOneWidget);
  });

  testWidgets('edit grid binding updates selected day before save', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final state = RosterState.initial();
    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();
    expect(find.text('Günlük Düzenleme'), findsOneWidget);
    await tester.tap(find.text('SAL').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-teacher-input-1-0')).last,
      'Grid Öğretmen',
    );
    await tester.pump();

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(state.currentWeek.rows[0].location, 'Bahçe');
    expect(state.currentWeek.rows[0].teachersByDay, [
      'Ali Yılmaz',
      'Grid Öğretmen',
      '',
      'Mehmet Kaya',
      '',
    ]);
  });

  testWidgets('edit grid controls add delete location and save', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final state = RosterState.initial();
    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-grid-delete-location-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-grid-add-location')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-grid-cell-0-2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-grid-edit-location-2')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-location-field')),
      'Grid Alanı',
    );
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-teacher-input-0-2')),
      'Grid Nöbetçi',
    );
    await tester.pump();

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(state.currentWeek.rows, hasLength(3));
    expect(state.currentWeek.rows.map((row) => row.location), [
      'Bahçe',
      'Kantin',
      'Grid Alanı',
    ]);
    expect(state.currentWeek.rows[2].teachersByDay, [
      'Grid Nöbetçi',
      '',
      '',
      '',
      '',
    ]);
  });

  testWidgets(
    'edit grid save keeps export snapshot aligned with current week',
    (WidgetTester tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final beforeRows = _snapshotRowValues(state.exportSnapshot);
      await tester.pumpWidget(
        MaterialApp(home: RosterHomeScreen(state: state)),
      );

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAL').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('edit-grid-teacher-input-1-0')).last,
        'Snapshot Teacher',
      );
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final afterSnapshot = state.exportSnapshot;
      final afterWeek = afterSnapshot.weeks.single;
      expect(_snapshotRowValues(afterSnapshot), isNot(beforeRows));
      expect(afterWeek.title, state.currentWeek.title);
      expect(afterWeek.startDate, state.currentWeek.startDate);
      expect(afterWeek.endDate, state.currentWeek.endDate);
      expect(afterWeek.schoolName, state.currentWeek.schoolName);
      expect(afterWeek.principalName, state.currentWeek.principalName);
      expect(
        afterWeek.rows.map(_rowValues).toList(),
        state.currentWeek.rows.map(_rowValues).toList(),
      );
      expect(afterWeek.rows.first.teachersByDay[1], 'Snapshot Teacher');
    },
  );

  testWidgets('edit grid controls discard unsaved changes', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final state = RosterState.initial();
    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-teacher-input-0-0')),
      'Kaydedilmeyen Nöbetçi',
    );
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmemiş Değişiklikler'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    expect(state.currentWeek.rows[0].teachersByDay[0], 'Ali Yılmaz');
  });

  testWidgets('edit grid visual labels and inline validation state', (
    WidgetTester tester,
  ) async {
    _useMobileTestView(tester);
    final state = RosterState.initial();
    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(find.text('Seçili gün: PAZARTESİ'), findsOneWidget);
    expect(find.text('Dolu'), findsWidgets);
    expect(find.text('Boş'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('edit-grid-edit-location-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-location-field')),
      '',
    );
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaydet'));
    await tester.pump();

    expect(find.byKey(const ValueKey('edit-grid-row-error-0')), findsOneWidget);
    expect(find.text('Görev yeri gerekli'), findsOneWidget);
  });

  testWidgets('edit screen blocks teacher row without location', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-grid-edit-location-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-grid-location-field')),
      '',
    );
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pump();

    expect(find.text('Düzeltme Gerekli'), findsOneWidget);
    expect(find.text('Dolu bir satırda görev yeri boş olamaz.'), findsWidgets);
    expect(find.text('Hafta Düzenle'), findsOneWidget);
  });

  testWidgets('edit screen rotates draft roster before save', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(
      find.text('Pazartesi-Cuma sütunları birlikte döndürülür.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Pazartesi-Cuma İleri'));
    await tester.tap(find.text('Pazartesi-Cuma İleri'));
    await tester.pump();

    expect(
      find.text('Pazartesi-Cuma sütunları ileri döndürüldü.'),
      findsWidgets,
    );

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Fatma Şahin'), 120);
    expect(find.text('Fatma Şahin'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ali Yılmaz'), 120);
    expect(find.text('Ali Yılmaz'), findsOneWidget);
  });

  testWidgets('edit screen warns before leaving unsaved changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Kaydedilmemiş Okul');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Kaydedilmemiş Değişiklikler'), findsOneWidget);
    expect(
      find.text('Çıkarsanız bu ekrandaki değişiklikler kaybolacak.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Kal'));
    await tester.pumpAndSettle();

    expect(find.text('Hafta Düzenle'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
  });

  testWidgets('home and edit screen show empty roster states', (
    WidgetTester tester,
  ) async {
    final state = RosterState(
      currentWeek: Week(
        title: 'Boş Hafta',
        startDate: DateTime(2026, 2, 2),
        endDate: DateTime(2026, 2, 6),
        rows: const [],
        schoolName: 'Boş Okul',
        principalName: 'Müdür',
      ),
    );

    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.scrollUntilVisible(
      find.text('Henüz görev yeri yok. Düzenle ile ilk görev yerini ekleyin.'),
      120,
    );
    expect(
      find.text('Henüz görev yeri yok. Düzenle ile ilk görev yerini ekleyin.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Henüz görev yeri yok. Günlük düzenleme ile ilk görev yerini ekleyin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('home export buttons show loading and success feedback', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final saveCompleter = Completer<void>();
    final writtenFiles = <String, int>{};
    final tempDir = Directory.systemTemp.createTempSync('nobet_widget_export_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final exportFileService = ExportFileService(
      saveLocationPicker: (request) async {
        return FileSaveLocation(
          '${tempDir.path}${Platform.pathSeparator}${request.suggestedName}',
        );
      },
      bytesWriter: ({required path, required bytes, required type}) async {
        writtenFiles[path] = bytes.length;
        await saveCompleter.future;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RosterHomeScreen(
          state: RosterState.initial(),
          exportFileService: exportFileService,
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Export PDF'), 120);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);

    await tester.tap(find.text('Export Excel'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    saveCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Excel kaydedildi:'), findsOneWidget);
    expect(writtenFiles, hasLength(1));
    expect(writtenFiles.keys.single.endsWith('.xlsx'), isTrue);
    expect(writtenFiles.values.single, greaterThan(0));
  });

  testWidgets('home export pdf shows success feedback', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final writtenFiles = <String, int>{};
    final tempDir = Directory.systemTemp.createTempSync('nobet_widget_export_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final exportFileService = ExportFileService(
      saveLocationPicker: (request) async {
        return FileSaveLocation(
          '${tempDir.path}${Platform.pathSeparator}${request.suggestedName}',
        );
      },
      bytesWriter: ({required path, required bytes, required type}) async {
        writtenFiles[path] = bytes.length;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RosterHomeScreen(
          state: RosterState.initial(),
          exportFileService: exportFileService,
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Export PDF'), 120);
    await tester.tap(find.text('Export PDF'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('PDF kaydedildi:'), findsOneWidget);
    expect(writtenFiles, hasLength(1));
    expect(writtenFiles.keys.single.endsWith('.pdf'), isTrue);
    expect(writtenFiles.values.single, greaterThan(0));
  });

  testWidgets('home export shows permission error feedback', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final tempDir = Directory.systemTemp.createTempSync('nobet_widget_export_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final exportFileService = ExportFileService(
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

    await tester.pumpWidget(
      MaterialApp(
        home: RosterHomeScreen(
          state: RosterState.initial(),
          exportFileService: exportFileService,
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Export Excel'), 120);
    await tester.tap(find.text('Export Excel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Dosya yazma izni reddedildi.'), findsOneWidget);
  });
}

void _useTallTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _useMobileTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<List<Object?>> _snapshotRowValues(ExportSnapshot snapshot) {
  return snapshot.weeks
      .expand((week) => week.rows)
      .map(_rowValues)
      .toList(growable: false);
}

List<Object?> _rowValues(RosterRow row) {
  return [row.location, ...row.teachersByDay];
}
