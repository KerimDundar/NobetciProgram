import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart';

import 'package:nobetci_program_mobile/main.dart';
import 'package:nobetci_program_mobile/models/week.dart';
import 'package:nobetci_program_mobile/services/export_file_service.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/roster_home_screen.dart';

void main() {
  testWidgets('shows current roster state', (WidgetTester tester) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    expect(find.text('Bahçe'), findsOneWidget);
    expect(find.text('PAZARTESİ'), findsWidgets);
    expect(find.text('Ali Yılmaz'), findsOneWidget);
  });

  testWidgets('next and previous week actions update visible week', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.textContaining('2 ŞUBAT-6 ŞUBAT'), findsOneWidget);

    await tester.tap(find.text('Sonraki Hafta'));
    await tester.pump();

    expect(find.textContaining('9 ŞUBAT-13 ŞUBAT'), findsOneWidget);

    await tester.tap(find.text('Önceki Hafta'));
    await tester.pump();

    expect(find.textContaining('2 ŞUBAT-6 ŞUBAT'), findsOneWidget);
  });

  testWidgets('edit screen saves roster changes to home state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Hafta Düzenle'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Yeni Okul');
    await tester.enterText(find.byType(TextField).at(2), 'Yeni Bahçe');
    await tester.enterText(find.byType(TextField).at(3), 'Yeni Öğretmen');

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    expect(find.text('Hafta kaydedildi.'), findsOneWidget);
    expect(find.text('Yeni Okul'), findsOneWidget);
    expect(find.text('Yeni Bahçe'), findsOneWidget);
    expect(find.text('Yeni Öğretmen'), findsOneWidget);
  });

  testWidgets('edit screen blocks teacher row without location', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(2), '');
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

    expect(
      find.text('Henüz görev yeri yok. Düzenle ile ilk görev yerini ekleyin.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Henüz görev yeri yok. İlk kartı doldurun veya yeni görev yeri ekleyin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('home export buttons show loading and success feedback', (
    WidgetTester tester,
  ) async {
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

    await tester.tap(find.text('Export Excel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Dosya yazma izni reddedildi.'), findsOneWidget);
  });
}
