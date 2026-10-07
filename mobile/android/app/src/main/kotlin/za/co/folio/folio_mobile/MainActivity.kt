package za.co.folio.folio_mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.IntentSenderRequest
import com.google.mlkit.vision.documentscanner.*
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.android.gms.tasks.Tasks
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterFragmentActivity() {
    private var pendingScan: MethodChannel.Result? = null
    private val readerExecutor = Executors.newSingleThreadExecutor()
    private val scannerLauncher = registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { activityResult ->
        val callback = pendingScan
        pendingScan = null
        if (callback != null) {
            val pdf = GmsDocumentScanningResult.fromActivityResultIntent(activityResult.data)?.pdf
            if (activityResult.resultCode != RESULT_OK || pdf == null) callback.success(null)
            else readerExecutor.execute {
                try {
                    val target = File.createTempFile("folio-scan-", ".pdf", cacheDir)
                    contentResolver.openInputStream(pdf.uri).use { input ->
                        requireNotNull(input) { "Scan could not be opened" }
                        target.outputStream().use { output -> input.copyTo(output) }
                    }
                    runOnUiThread { callback.success(target.absolutePath) }
                } catch (_: Exception) { runOnUiThread { callback.error("SCAN_SAVE", "Could not save this scan. Please try again.", null) } }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "folio/documents").setMethodCallHandler { call, result ->
            when (call.method) {
                "scan" -> {
                    if (pendingScan != null) { result.error("BUSY", "A scan is already open.", null) }
                    else {
                        pendingScan = result
                        val options = GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true)
                            .setPageLimit(20).setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
                            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
                        GmsDocumentScanning.getClient(options).getStartScanIntent(this)
                            .addOnSuccessListener { sender ->
                                try { scannerLauncher.launch(IntentSenderRequest.Builder(sender).build()) }
                                catch (_: Exception) { pendingScan = null; result.error("SCANNER_UNAVAILABLE", "Scanner unavailable. Import a file instead.", null) }
                            }
                            .addOnFailureListener { pendingScan = null; result.error("SCANNER_UNAVAILABLE", "Scanner needs compatible Google Play services. Import a file instead.", null) }
                    }
                }
                "extract" -> {
                    val path = call.argument<String>("path")
                    if (path == null) result.error("INVALID_FILE", "Choose a file first.", null)
                    else readerExecutor.execute {
                        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                        try {
                            val file = File(path)
                            require(file.length() in 1..(20L * 1024 * 1024)) { "File must be smaller than 20 MB" }
                            val pages = mutableListOf<Map<String, Any>>()
                            if (path.endsWith(".pdf", ignoreCase = true)) {
                                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                                    PdfRenderer(descriptor).use { renderer ->
                                        require(renderer.pageCount <= 20) { "On-device OCR supports up to 20 pages. Text PDFs can still be uploaded." }
                                        for (index in 0 until renderer.pageCount) {
                                            renderer.openPage(index).use { page ->
                                                val scale = 2000.0 / maxOf(page.width, page.height)
                                                val bitmap = Bitmap.createBitmap(maxOf(1, (page.width * scale).toInt()), maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                                                try {
                                                    bitmap.eraseColor(Color.WHITE)
                                                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                                    val text = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)), 20, TimeUnit.SECONDS).text
                                                    pages.add(mapOf("page" to index + 1, "text" to text))
                                                } finally { bitmap.recycle() }
                                            }
                                        }
                                    }
                                }
                            } else {
                                val text = Tasks.await(recognizer.process(InputImage.fromFilePath(this, Uri.fromFile(file))), 20, TimeUnit.SECONDS).text
                                pages.add(mapOf("page" to 1, "text" to text))
                            }
                            runOnUiThread { result.success(pages) }
                        } catch (_: Exception) { runOnUiThread { result.error("OCR_UNAVAILABLE", "On-device text reading could not finish. The original file can still be uploaded for review.", null) } }
                        finally { recognizer.close() }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        pendingScan?.error("SCANNER_CLOSED", "Scanner closed. Please try again.", null)
        pendingScan = null
        readerExecutor.shutdown()
        super.onDestroy()
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
