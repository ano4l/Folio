package za.co.folio.folio_mobile

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.multipdf.PDFMergerUtility
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.graphics.image.LosslessFactory
import com.tom_roush.pdfbox.pdmodel.graphics.image.JPEGFactory
import io.flutter.plugin.common.MethodCall
import java.io.File

/** Local PDF operations preserve PDF text and vector pages. Originals are never overwritten. */
internal class PdfTools(private val context: Context) {
    init { PDFBoxResourceLoader.init(context) }
    private fun input(path: String, image: Boolean = false): File {
        val file = File(path).canonicalFile
        val roots = listOfNotNull(File(context.applicationInfo.dataDir), context.externalCacheDir).map { it.canonicalPath + File.separator }
        require(roots.any { file.path.startsWith(it) }) { "Choose a local copy using the file picker." }
        require(file.isFile && file.length() in 1..20L * 1024 * 1024) { "Each file must be smaller than 20 MB." }
        require(if (image) file.extension.lowercase() in listOf("png", "jpg", "jpeg") else file.extension.equals("pdf", true)) { "Choose a supported file type." }
        return file
    }
    private fun load(path: String): PDDocument {
        val pdf = PDDocument.load(input(path), MemoryUsageSetting.setupTempFileOnly())
        if (pdf.isEncrypted || pdf.numberOfPages !in 1..100) { pdf.close(); throw IllegalArgumentException("Use an unlocked PDF with 1–100 pages.") }
        return pdf
    }
    private fun indexes(spec: String, count: Int): List<Int> {
        require(spec.length in 1..600) { "Enter pages such as 1-3,5 or 5,1,2." }
        val result = linkedSetOf<Int>()
        for (token in spec.split(',')) {
            val parts = token.trim().split('-').map { it.trim().toIntOrNull() }
            require(parts.size in 1..2 && parts.all { it != null }) { "Use pages such as 1-3,5." }
            val first = parts[0]!!; val last = parts.last()!!
            require(first >= 1 && last >= first && last <= count) { "Page numbers must be inside the document." }
            for (page in first..last) result.add(page - 1)
            require(result.size <= 100) { "Choose up to 100 pages." }
        }
        return result.toList()
    }
    fun run(call: MethodCall): String {
        val output = File.createTempFile("folio-tool-", ".pdf", context.cacheDir)
        try {
            PDDocument(MemoryUsageSetting.setupTempFileOnly()).use { destination ->
                when (call.method) {
                    "mergePdf" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        require(paths.size in 2..20) { "Choose 2–20 PDFs." }
                        val merger = PDFMergerUtility()
                        for (path in paths) load(path).use { source ->
                            require(destination.numberOfPages + source.numberOfPages <= 100) { "Combined PDF must have at most 100 pages." }
                            merger.appendDocument(destination, source)
                        }
                    }
                    "extractPages" -> {
                        val path = call.argument<String>("path") ?: error("Choose a PDF.")
                        val spec = call.argument<String>("pages") ?: error("Choose pages.")
                        load(path).use { source ->
                            val selected = indexes(spec, source.numberOfPages)
                            PDFMergerUtility().appendDocument(destination, source)
                            val pages = selected.map { destination.getPage(it) }
                            while (destination.numberOfPages > 0) destination.removePage(0)
                            for (page in pages) destination.addPage(page)
                        }
                    }
                    "rotatePdf" -> {
                        val path = call.argument<String>("path") ?: error("Choose a PDF.")
                        val degrees = call.argument<Int>("degrees") ?: 90
                        require(degrees in listOf(90, 180, 270)) { "Choose a quarter turn." }
                        load(path).use { source ->
                            PDFMergerUtility().appendDocument(destination, source)
                            for (page in destination.pages) page.rotation = (page.rotation + degrees) % 360
                        }
                    }
                    "imagesToPdf" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        require(paths.size in 1..20) { "Choose 1–20 images." }
                        for (path in paths) {
                            val file = input(path, true)
                            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                            BitmapFactory.decodeFile(file.path, bounds)
                            require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Image could not be read." }
                            var sample = 1
                            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 2500) sample *= 2
                            var bitmap = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: error("Image could not be read.")
                            try {
                                val orientation = ExifInterface(file.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                                val matrix = Matrix()
                                when (orientation) {
                                    ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
                                    ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
                                    ExifInterface.ORIENTATION_FLIP_VERTICAL -> { matrix.setRotate(180f); matrix.postScale(-1f, 1f) }
                                    ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
                                    ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
                                    ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(-90f); matrix.postScale(-1f, 1f) }
                                    ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
                                }
                                if (!matrix.isIdentity) {
                                    val oriented = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                                    if (oriented !== bitmap) { bitmap.recycle(); bitmap = oriented }
                                }
                                val page = PDPage(PDRectangle.LETTER); destination.addPage(page)
                                val image = if (file.extension.equals("png", true)) LosslessFactory.createFromImage(destination, bitmap) else JPEGFactory.createFromImage(destination, bitmap, 0.85f)
                                val scale = minOf(564f / bitmap.width, 744f / bitmap.height)
                                val width = bitmap.width * scale; val height = bitmap.height * scale
                                PDPageContentStream(destination, page).use { content -> content.drawImage(image, (612f - width) / 2, (792f - height) / 2, width, height) }
                            } finally { bitmap.recycle() }
                        }
                    }
                    else -> error("Unsupported document tool.")
                }
                destination.save(output)
            }
            require(output.length() in 1..20L * 1024 * 1024) { "Finished PDF exceeds 20 MB. Use fewer pages." }
            return output.path
        } catch (error: Exception) { output.delete(); throw error }
    }
}
