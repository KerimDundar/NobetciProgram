import 'dart:typed_data';

enum AndroidDocumentSaveStatus { success, cancelled, error }

class AndroidDocumentSaveResult {
  const AndroidDocumentSaveResult._({
    required this.status,
    this.uri,
    this.message,
  });

  final AndroidDocumentSaveStatus status;
  final String? uri;
  final String? message;

  bool get isSuccess => status == AndroidDocumentSaveStatus.success;
  bool get isCancelled => status == AndroidDocumentSaveStatus.cancelled;
  bool get isError => status == AndroidDocumentSaveStatus.error;

  factory AndroidDocumentSaveResult.success(String uri) {
    return AndroidDocumentSaveResult._(
      status: AndroidDocumentSaveStatus.success,
      uri: uri,
    );
  }

  factory AndroidDocumentSaveResult.cancelled() {
    return const AndroidDocumentSaveResult._(
      status: AndroidDocumentSaveStatus.cancelled,
    );
  }

  factory AndroidDocumentSaveResult.error(String message) {
    return AndroidDocumentSaveResult._(
      status: AndroidDocumentSaveStatus.error,
      message: message,
    );
  }
}

abstract interface class AndroidDocumentSaver {
  Future<AndroidDocumentSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
    required String mimeType,
  });
}
