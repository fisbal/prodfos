package com.martinb.prodfos

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Handles "Open with ProDFOS" for PDFs.
 * The PDF (usually a content:// URI) is copied into app storage and its path
 * is handed to Dart over the "prodfos/open_file" channel:
 *  - getInitialFile : the PDF that launched the app (cold start)
 *  - openFile       : a PDF opened while ProDFOS was already running
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var lastHandled: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prodfos/open_file")
        ch.setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                result.success(copyFromIntent(intent))
            } else {
                result.notImplemented()
            }
        }
        channel = ch
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = copyFromIntent(intent) ?: return
        channel?.invokeMethod("openFile", path)
    }

    private fun copyFromIntent(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        if (uri == lastHandled) return null
        lastHandled = uri
        return try {
            if (uri.scheme == "file") {
                uri.path
            } else {
                var name = "document.pdf"
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (i >= 0) c.getString(i)?.let { name = it }
                    }
                }
                if (!name.lowercase().endsWith(".pdf")) name += ".pdf"
                val safe = name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
                val dir = File(filesDir, "opened").apply { mkdirs() }
                val out = File(dir, safe)
                val input = contentResolver.openInputStream(uri) ?: return null
                input.use { src -> out.outputStream().use { dst -> src.copyTo(dst) } }
                out.absolutePath
            }
        } catch (e: Exception) {
            null
        }
    }
}
