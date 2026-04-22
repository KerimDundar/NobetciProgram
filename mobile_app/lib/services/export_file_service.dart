import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'android_document_saver.dart';
import 'excel_export_service.dart';
import 'export_snapshot_service.dart';
import 'method_channel_android_document_saver.dart';
import 'pdf_export_service.dart';

enum ExportType { pdf, excel }

typedef ExportFileType = ExportType;

enum ExportResultStatus { success, cancelled, error }

class ExportResult {
  const ExportResult._({
    required this.status,
    this.path,
    this.message,
    this.error,
    this.stackTrace,
  });

  final ExportResultStatus status;
  final String? path;
  final String? message;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isSuccess => status == ExportResultStatus.success;
  bool get isCancelled => status == ExportResultStatus.cancelled;
  bool get isError => status == ExportResultStatus.error;

  factory ExportResult.success(String path) {
    return ExportResult._(status: ExportResultStatus.success, path: path);
  }

  factory ExportResult.cancelled() {
    return const ExportResult._(status: ExportResultStatus.cancelled);
  }

  factory ExportResult.error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return ExportResult._(
      status: ExportResultStatus.error,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class ExportSaveResult {
  const ExportSaveResult({required this.path});

  final String path;
}

class ExportFileException implements Exception {
  const ExportFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef SaveLocationPicker =
    Future<FileSaveLocation?> Function(SaveLocationRequest request);

typedef ExportBytesWriter =
    Future<void> Function({
      required Uint8List bytes,
      required String path,
      required ExportType type,
    });

typedef OverwriteConfirmation =
    Future<bool> Function(String existingPath, ExportType type);

class SaveLocationRequest {
  const SaveLocationRequest({required this.type, required this.suggestedName});

  final ExportType type;
  final String suggestedName;
}

class ExportFileService {
  const ExportFileService({
    PdfExportService pdfExportService = const PdfExportService(),
    ExcelExportService excelExportService = const ExcelExportService(),
    SaveLocationPicker? saveLocationPicker,
    ExportBytesWriter? bytesWriter,
    OverwriteConfirmation? overwriteConfirmation,
    this.androidDocumentSaver,
  }) : _pdfExportService = pdfExportService,
       _excelExportService = excelExportService,
       _saveLocationPicker = saveLocationPicker,
       _bytesWriter = bytesWriter,
       _overwriteConfirmation = overwriteConfirmation;

  final PdfExportService _pdfExportService;
  final ExcelExportService _excelExportService;
  final SaveLocationPicker? _saveLocationPicker;
  final ExportBytesWriter? _bytesWriter;
  final OverwriteConfirmation? _overwriteConfirmation;
  final AndroidDocumentSaver? androidDocumentSaver;

  Future<ExportResult> exportFile(
    Uint8List bytes,
    ExportType type, {
    String? suggestedName,
  }) async {
    if (bytes.isEmpty) {
      return ExportResult.error('Dışa aktarılacak dosya içeriği boş.');
    }

    final safeSuggestedName = _safeSuggestedName(
      suggestedName ?? defaultFileName(type),
      type,
    );

    try {
      if (Platform.isAndroid) {
        return await _exportFileOnAndroid(bytes, type, safeSuggestedName);
      }

      final picker = _saveLocationPicker ?? _defaultSaveLocationPicker;
      final location = await picker(
        SaveLocationRequest(type: type, suggestedName: safeSuggestedName),
      );

      if (location == null) {
        return ExportResult.cancelled();
      }

      final path = _enforceExtension(location.path, type);
      _validateDestinationPath(path, type);

      final writer = _bytesWriter ?? _atomicXFileWriter;
      final destination = File(path);
      final entityType = FileSystemEntity.typeSync(path, followLinks: false);

      if (entityType == FileSystemEntityType.directory ||
          entityType == FileSystemEntityType.link) {
        return ExportResult.error('Geçersiz dosya yolu.');
      }

      if (destination.existsSync()) {
        final confirmation = _overwriteConfirmation;
        if (confirmation == null) {
          return ExportResult.error(
            'Var olan dosyanın üzerine yazmak için onay gerekiyor.',
          );
        }

        final confirmed = await confirmation(path, type);
        if (!confirmed) {
          return ExportResult.cancelled();
        }
      }

      await writer(bytes: bytes, path: path, type: type);

      return ExportResult.success(path);
    } on ExportFileException catch (error, stackTrace) {
      return ExportResult.error(
        error.message,
        error: error,
        stackTrace: stackTrace,
      );
    } on PathAccessException catch (error, stackTrace) {
      return ExportResult.error(
        'Dosya yazma izni reddedildi.',
        error: error,
        stackTrace: stackTrace,
      );
    } on FileSystemException catch (error, stackTrace) {
      return ExportResult.error(
        _mapFileSystemException(error),
        error: error,
        stackTrace: stackTrace,
      );
    } on ArgumentError catch (error, stackTrace) {
      return ExportResult.error(
        'Geçersiz dosya yolu.',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      return ExportResult.error(
        'Dosya kaydedilemedi.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ExportResult> _exportFileOnAndroid(
    Uint8List bytes,
    ExportType type,
    String suggestedName,
  ) async {
    final saver = androidDocumentSaver ?? MethodChannelAndroidDocumentSaver();
    final result = await saver.save(
      bytes: bytes,
      suggestedName: suggestedName,
      mimeType: type.mimeType,
    );

    return switch (result.status) {
      AndroidDocumentSaveStatus.success =>
        result.uri == null || result.uri!.trim().isEmpty
            ? ExportResult.error('Dosya kaydedilemedi.')
            : ExportResult.success(result.uri!),
      AndroidDocumentSaveStatus.cancelled => ExportResult.cancelled(),
      AndroidDocumentSaveStatus.error => ExportResult.error(
        result.message ?? 'Dosya kaydedilemedi.',
      ),
    };
  }

  Future<ExportSaveResult?> exportPdf(ExportSnapshot snapshot) async {
    if (snapshot.isEmpty) {
      throw const ExportFileException('Dışa aktarılacak geçerli hafta yok.');
    }

    final bytes = await _pdfExportService.buildPdf(snapshot);
    final result = await exportFile(
      bytes,
      ExportType.pdf,
      suggestedName: suggestedFileName(snapshot, ExportType.pdf),
    );

    return _legacyResultOrThrow(result);
  }

  Future<ExportSaveResult?> exportExcel(ExportSnapshot snapshot) async {
    if (snapshot.isEmpty) {
      throw const ExportFileException('Dışa aktarılacak geçerli hafta yok.');
    }

    final bytes = _excelExportService.buildWorkbook(snapshot);
    final result = await exportFile(
      bytes,
      ExportType.excel,
      suggestedName: suggestedFileName(snapshot, ExportType.excel),
    );

    return _legacyResultOrThrow(result);
  }

  String suggestedFileName(ExportSnapshot snapshot, ExportType type) {
    if (snapshot.isMultiWeek) {
      final first = snapshot.weeks.first.startDate;
      final last = snapshot.weeks.last.endDate;
      return _safeSuggestedName(
        'nobet_${_dateKey(first)}_${_dateKey(last)}.${type.extension}',
        type,
      );
    }

    return defaultFileName(type);
  }

  String defaultFileName(ExportType type) {
    return 'nobet_ciktisi.${type.extension}';
  }

  ExportSaveResult? _legacyResultOrThrow(ExportResult result) {
    if (result.isCancelled) {
      return null;
    }
    if (result.isSuccess && result.path != null) {
      return ExportSaveResult(path: result.path!);
    }
    throw ExportFileException(result.message ?? 'Dosya kaydedilemedi.');
  }

  Future<FileSaveLocation?> _defaultSaveLocationPicker(
    SaveLocationRequest request,
  ) {
    return getSaveLocation(
      suggestedName: request.suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(
          label: request.type.typeLabel,
          extensions: [request.type.extension],
          mimeTypes: [request.type.mimeType],
        ),
      ],
      confirmButtonText: 'Kaydet',
    );
  }

  Future<void> _atomicXFileWriter({
    required Uint8List bytes,
    required String path,
    required ExportType type,
  }) async {
    final destination = File(path);
    final parent = destination.parent;
    final parentType = FileSystemEntity.typeSync(
      parent.path,
      followLinks: false,
    );

    if (parentType != FileSystemEntityType.directory) {
      throw const ExportFileException('Geçersiz dosya yolu.');
    }

    final tempPath = await _uniqueSidecarPath(path, 'tmp');
    final backupPath = await _uniqueSidecarPath(path, 'bak');
    final tempFile = File(tempPath);
    final backupFile = File(backupPath);
    var backupCreated = false;

    try {
      final xFile = XFile.fromData(
        bytes,
        name: _baseName(path),
        mimeType: type.mimeType,
        length: bytes.length,
      );

      await xFile.saveTo(tempPath);

      if (!await tempFile.exists() || await tempFile.length() != bytes.length) {
        throw const ExportFileException('Dosya kaydedilemedi.');
      }

      if (destination.existsSync()) {
        if (backupFile.existsSync()) {
          throw const ExportFileException('Dosya kaydedilemedi.');
        }
        await destination.rename(backupPath);
        backupCreated = true;
      }

      await tempFile.rename(path);

      if (backupCreated && await backupFile.exists()) {
        await _deleteIfExists(backupFile, ignoreErrors: true);
      }
    } catch (_) {
      await _deleteIfExists(tempFile, ignoreErrors: true);
      if (backupCreated &&
          !await destination.exists() &&
          await backupFile.exists()) {
        await backupFile.rename(path);
      }
      rethrow;
    }
  }

  String _enforceExtension(String path, ExportType type) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed.contains('\x00')) {
      throw const ExportFileException('Geçersiz dosya yolu.');
    }

    final expectedExtension = '.${type.extension}';
    if (trimmed.toLowerCase().endsWith(expectedExtension)) {
      return trimmed;
    }

    return '$trimmed$expectedExtension';
  }

  void _validateDestinationPath(String path, ExportType type) {
    final normalized = path.replaceAll('\\', '/');
    if (normalized.endsWith('/')) {
      throw const ExportFileException('Geçersiz dosya yolu.');
    }

    final name = _baseName(path).trim();
    final expectedExtension = '.${type.extension}';
    if (name.length <= expectedExtension.length ||
        !name.toLowerCase().endsWith(expectedExtension)) {
      throw const ExportFileException('Geçersiz dosya yolu.');
    }

    if (RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(name)) {
      throw const ExportFileException('Geçersiz dosya yolu.');
    }

    final nameWithoutExtension = name.substring(
      0,
      name.length - expectedExtension.length,
    );
    if (nameWithoutExtension.trim().isEmpty ||
        RegExp(r'^\.+$').hasMatch(nameWithoutExtension)) {
      throw const ExportFileException('Geçersiz dosya yolu.');
    }
  }

  String _safeSuggestedName(String name, ExportType type) {
    final withoutDirectories = name.split(RegExp(r'[\\/]')).last;
    final sanitized = withoutDirectories
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');

    final baseName = sanitized.isEmpty ? 'nobet_ciktisi' : sanitized;
    return _enforceExtension(baseName, type);
  }

  Future<String> _uniqueSidecarPath(String path, String extension) async {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final candidate = '$path.$pidHash.$stamp.$attempt.$extension';
      if (!await File(candidate).exists()) {
        return candidate;
      }
    }

    throw const ExportFileException('Dosya kaydedilemedi.');
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

String _mapFileSystemException(FileSystemException error) {
  final code = error.osError?.errorCode;
  final message = '${error.message} ${error.osError?.message ?? ''}'
      .toLowerCase();

  if (code == 5 ||
      code == 13 ||
      message.contains('access is denied') ||
      message.contains('permission denied')) {
    return 'Dosya yazma izni reddedildi.';
  }

  if (code == 3 ||
      code == 123 ||
      message.contains('path') ||
      message.contains('cannot find') ||
      message.contains('not found') ||
      message.contains('invalid')) {
    return 'Geçersiz dosya yolu.';
  }

  return 'Dosya kaydedilemedi.';
}

String _baseName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  if (index < 0) {
    return normalized;
  }
  return normalized.substring(index + 1);
}

Future<void> _deleteIfExists(File file, {bool ignoreErrors = false}) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    if (!ignoreErrors) {
      rethrow;
    }
  }
}

int get pidHash => pid == 0 ? DateTime.now().microsecondsSinceEpoch : pid;

extension ExportTypeDetails on ExportType {
  String get extension {
    return switch (this) {
      ExportType.pdf => 'pdf',
      ExportType.excel => 'xlsx',
    };
  }

  String get mimeType {
    return switch (this) {
      ExportType.pdf => 'application/pdf',
      ExportType.excel =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
  }

  String get typeLabel {
    return switch (this) {
      ExportType.pdf => 'PDF dosyası',
      ExportType.excel => 'Excel dosyası',
    };
  }
}
