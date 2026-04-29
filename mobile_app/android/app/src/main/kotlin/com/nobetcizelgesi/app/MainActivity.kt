package com.nobetcizelgesi.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val mainHandler: Handler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val createDocumentLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            handleCreateDocumentResult(result.resultCode, result.data)
        }

    private var pendingRequest: PendingSaveRequest? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            if (call.method != METHOD_SAVE_DOCUMENT) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            handleSaveDocument(call, result)
        }
    }

    override fun onDestroy() {
        pendingRequest?.let { request ->
            completePendingRequest(request, cancelledResponse())
        }
        ioExecutor.shutdown()
        super.onDestroy()
    }

    private fun handleSaveDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingRequest != null) {
            result.success(errorResponse(WRITE_FAILURE_MESSAGE))
            return
        }

        val bytes = call.argument<ByteArray>("bytes")
        val suggestedName = call.argument<String>("suggestedName")
        val mimeType = call.argument<String>("mimeType")

        if (bytes == null || suggestedName.isNullOrBlank() || mimeType.isNullOrBlank()) {
            result.success(errorResponse(WRITE_FAILURE_MESSAGE))
            return
        }

        val request = PendingSaveRequest(bytes, result)
        pendingRequest = request

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, suggestedName)
        }

        try {
            createDocumentLauncher.launch(intent)
        } catch (exception: Exception) {
            completePendingRequest(request, errorResponse(WRITE_FAILURE_MESSAGE))
        }
    }

    private fun handleCreateDocumentResult(resultCode: Int, data: Intent?) {
        val request = pendingRequest ?: return
        val uri = data?.data

        if (resultCode != Activity.RESULT_OK || uri == null) {
            completePendingRequest(request, cancelledResponse())
            return
        }

        writeBytesToUri(request, uri)
    }

    private fun writeBytesToUri(request: PendingSaveRequest, uri: Uri) {
        ioExecutor.execute {
            val response = try {
                contentResolver.openOutputStream(uri, "w").use { outputStream ->
                    if (outputStream == null) {
                        throw IOException()
                    }
                    outputStream.write(request.bytes)
                    outputStream.flush()
                }
                successResponse(uri)
            } catch (exception: SecurityException) {
                errorResponse(PERMISSION_DENIED_MESSAGE)
            } catch (exception: IOException) {
                errorResponse(WRITE_FAILURE_MESSAGE)
            } catch (exception: Exception) {
                errorResponse(WRITE_FAILURE_MESSAGE)
            }

            mainHandler.post {
                completePendingRequest(request, response)
            }
        }
    }

    private fun completePendingRequest(
        request: PendingSaveRequest,
        response: Map<String, String>
    ) {
        if (pendingRequest !== request) {
            return
        }

        pendingRequest = null
        request.result.success(response)
    }

    private fun successResponse(uri: Uri): Map<String, String> =
        mapOf(
            "status" to "success",
            "uri" to uri.toString()
        )

    private fun cancelledResponse(): Map<String, String> =
        mapOf("status" to "cancelled")

    private fun errorResponse(message: String): Map<String, String> =
        mapOf(
            "status" to "error",
            "message" to message
        )

    private data class PendingSaveRequest(
        val bytes: ByteArray,
        val result: MethodChannel.Result
    )

    private companion object {
        const val CHANNEL_NAME = "nobetci_program/android_document_saver"
        const val METHOD_SAVE_DOCUMENT = "saveDocument"
        const val PERMISSION_DENIED_MESSAGE = "Dosya yazma izni reddedildi."
        const val WRITE_FAILURE_MESSAGE = "Dosya kaydedilemedi."
    }
}
