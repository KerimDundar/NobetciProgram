import 'package:flutter/services.dart';

import 'android_document_saver.dart';

class MethodChannelAndroidDocumentSaver implements AndroidDocumentSaver {
  MethodChannelAndroidDocumentSaver({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'nobetci_program/android_document_saver';
  static const methodName = 'saveDocument';

  final MethodChannel _channel;

  @override
  Future<AndroidDocumentSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
    required String mimeType,
  }) async {
    try {
      final response = await _channel.invokeMethod<Object?>(
        methodName,
        <String, Object?>{
          'bytes': bytes,
          'suggestedName': suggestedName,
          'mimeType': mimeType,
        },
      );

      return _parseResponse(response);
    } on PlatformException catch (error) {
      return AndroidDocumentSaveResult.error(_messageOrFallback(error.message));
    } catch (_) {
      return AndroidDocumentSaveResult.error('Dosya kaydedilemedi.');
    }
  }

  AndroidDocumentSaveResult _parseResponse(Object? response) {
    if (response is! Map) {
      return AndroidDocumentSaveResult.error('Dosya kaydedilemedi.');
    }

    final status = response['status'];
    if (status == 'success') {
      final uri = response['uri'];
      if (uri is String && uri.trim().isNotEmpty) {
        return AndroidDocumentSaveResult.success(uri);
      }
      return AndroidDocumentSaveResult.error('Dosya kaydedilemedi.');
    }

    if (status == 'cancelled') {
      return AndroidDocumentSaveResult.cancelled();
    }

    if (status == 'error') {
      final message = response['message'];
      return AndroidDocumentSaveResult.error(
        _messageOrFallback(message is String ? message : null),
      );
    }

    return AndroidDocumentSaveResult.error('Dosya kaydedilemedi.');
  }

  String _messageOrFallback(String? message) {
    final cleanMessage = message?.trim();
    if (cleanMessage == null || cleanMessage.isEmpty) {
      return 'Dosya kaydedilemedi.';
    }
    return cleanMessage;
  }
}
