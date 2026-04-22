import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/services/android_document_saver.dart';
import 'package:nobetci_program_mobile/services/export_file_service.dart';
import 'package:nobetci_program_mobile/services/method_channel_android_document_saver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelAndroidDocumentSaver', () {
    const channel = MethodChannel(
      MethodChannelAndroidDocumentSaver.channelName,
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('maps fake handler cancelled response', () async {
      _setAndroidSaverHandler(channel, (_) async {
        return <String, Object?>{'status': 'cancelled'};
      });

      final result = await MethodChannelAndroidDocumentSaver(
        channel: channel,
      ).save(
        bytes: Uint8List.fromList([1, 2, 3]),
        suggestedName: 'nobet_ciktisi.pdf',
        mimeType: ExportFileType.pdf.mimeType,
      );

      expect(result.status, AndroidDocumentSaveStatus.cancelled);
      expect(result.isCancelled, isTrue);
    });

    test('maps fake handler success response and sends SAF arguments', () async {
      MethodCall? capturedCall;
      _setAndroidSaverHandler(channel, (call) async {
        capturedCall = call;
        return <String, Object?>{
          'status': 'success',
          'uri': 'content://exports/nobet_ciktisi.pdf',
        };
      });

      final result = await MethodChannelAndroidDocumentSaver(
        channel: channel,
      ).save(
        bytes: Uint8List.fromList([4, 5, 6]),
        suggestedName: 'nobet_ciktisi.pdf',
        mimeType: ExportFileType.pdf.mimeType,
      );

      expect(capturedCall, isNotNull);
      expect(capturedCall!.method, MethodChannelAndroidDocumentSaver.methodName);
      final arguments = capturedCall!.arguments as Map<Object?, Object?>;
      expect(arguments['bytes'], Uint8List.fromList([4, 5, 6]));
      expect(arguments['suggestedName'], 'nobet_ciktisi.pdf');
      expect(arguments['mimeType'], ExportFileType.pdf.mimeType);
      expect(result.status, AndroidDocumentSaveStatus.success);
      expect(result.uri, 'content://exports/nobet_ciktisi.pdf');
    });

    test('maps fake handler permission denied response', () async {
      _setAndroidSaverHandler(channel, (_) async {
        return <String, Object?>{
          'status': 'error',
          'message': 'Dosya yazma izni reddedildi.',
        };
      });

      final result = await MethodChannelAndroidDocumentSaver(
        channel: channel,
      ).save(
        bytes: Uint8List.fromList([1]),
        suggestedName: 'nobet_ciktisi.pdf',
        mimeType: ExportFileType.pdf.mimeType,
      );

      expect(result.status, AndroidDocumentSaveStatus.error);
      expect(result.message, 'Dosya yazma izni reddedildi.');
    });

    test('maps fake handler generic failure response', () async {
      _setAndroidSaverHandler(channel, (_) async {
        return <String, Object?>{'status': 'error', 'message': '  '};
      });

      final result = await MethodChannelAndroidDocumentSaver(
        channel: channel,
      ).save(
        bytes: Uint8List.fromList([1]),
        suggestedName: 'nobet_ciktisi.pdf',
        mimeType: ExportFileType.pdf.mimeType,
      );

      expect(result.status, AndroidDocumentSaveStatus.error);
      expect(result.message, 'Dosya kaydedilemedi.');
    });
  });

  group('ExportFileService Android SAF branch', () {
    test('cancelled fake saver returns ExportResult.cancelled', () async {
      if (!Platform.isAndroid) {
        markTestSkipped('Platform.isAndroid branch requires Android runtime.');
        return;
      }

      final saver = _FakeAndroidDocumentSaver(
        AndroidDocumentSaveResult.cancelled(),
      );
      final service = ExportFileService(androidDocumentSaver: saver);

      final result = await service.exportFile(
        Uint8List.fromList([1, 2, 3]),
        ExportFileType.pdf,
      );

      expect(result.status, ExportResultStatus.cancelled);
      expect(saver.calls, 1);
    });

    test('success fake saver returns ExportResult.success(uri)', () async {
      if (!Platform.isAndroid) {
        markTestSkipped('Platform.isAndroid branch requires Android runtime.');
        return;
      }

      final saver = _FakeAndroidDocumentSaver(
        AndroidDocumentSaveResult.success('content://exports/nobet.pdf'),
      );
      final service = ExportFileService(androidDocumentSaver: saver);

      final result = await service.exportFile(
        Uint8List.fromList([4, 5, 6]),
        ExportFileType.pdf,
        suggestedName: 'nobet.pdf',
      );

      expect(result.status, ExportResultStatus.success);
      expect(result.path, 'content://exports/nobet.pdf');
      expect(saver.calls, 1);
      expect(saver.lastSuggestedName, 'nobet.pdf');
      expect(saver.lastMimeType, ExportFileType.pdf.mimeType);
      expect(saver.lastBytes, Uint8List.fromList([4, 5, 6]));
    });

    test('permission denied fake saver returns localized error', () async {
      if (!Platform.isAndroid) {
        markTestSkipped('Platform.isAndroid branch requires Android runtime.');
        return;
      }

      final saver = _FakeAndroidDocumentSaver(
        AndroidDocumentSaveResult.error('Dosya yazma izni reddedildi.'),
      );
      final service = ExportFileService(androidDocumentSaver: saver);

      final result = await service.exportFile(
        Uint8List.fromList([1]),
        ExportFileType.pdf,
      );

      expect(result.status, ExportResultStatus.error);
      expect(result.message, 'Dosya yazma izni reddedildi.');
      expect(saver.calls, 1);
    });

    test('generic failure fake saver returns localized fallback error', () async {
      if (!Platform.isAndroid) {
        markTestSkipped('Platform.isAndroid branch requires Android runtime.');
        return;
      }

      final saver = _FakeAndroidDocumentSaver(
        AndroidDocumentSaveResult.error('Dosya kaydedilemedi.'),
      );
      final service = ExportFileService(androidDocumentSaver: saver);

      final result = await service.exportFile(
        Uint8List.fromList([1]),
        ExportFileType.pdf,
      );

      expect(result.status, ExportResultStatus.error);
      expect(result.message, 'Dosya kaydedilemedi.');
      expect(saver.calls, 1);
    });
  });

  group('ExportFileService desktop branch', () {
    test('continues to use desktop save path outside Android', () async {
      if (Platform.isAndroid) {
        markTestSkipped('Desktop branch requires a non-Android runtime.');
        return;
      }

      final saver = _FakeAndroidDocumentSaver(
        AndroidDocumentSaveResult.success('content://unused'),
      );
      final writtenPaths = <String>[];
      final service = ExportFileService(
        androidDocumentSaver: saver,
        saveLocationPicker: (_) async => FileSaveLocation('desktop_export'),
        bytesWriter: ({required bytes, required path, required type}) async {
          writtenPaths.add(path);
        },
      );

      final result = await service.exportFile(
        Uint8List.fromList([1, 2, 3]),
        ExportFileType.pdf,
      );

      expect(result.status, ExportResultStatus.success);
      expect(result.path, 'desktop_export.pdf');
      expect(writtenPaths, ['desktop_export.pdf']);
      expect(saver.calls, 0);
    });
  });
}

void _setAndroidSaverHandler(
  MethodChannel channel,
  Future<Object?> Function(MethodCall call) handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

final class _FakeAndroidDocumentSaver implements AndroidDocumentSaver {
  _FakeAndroidDocumentSaver(this.result);

  final AndroidDocumentSaveResult result;
  int calls = 0;
  Uint8List? lastBytes;
  String? lastSuggestedName;
  String? lastMimeType;

  @override
  Future<AndroidDocumentSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
    required String mimeType,
  }) async {
    calls += 1;
    lastBytes = bytes;
    lastSuggestedName = suggestedName;
    lastMimeType = mimeType;
    return result;
  }
}
