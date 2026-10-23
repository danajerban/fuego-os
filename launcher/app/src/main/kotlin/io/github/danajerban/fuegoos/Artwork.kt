package io.github.danajerban.fuegoos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.IOException
import kotlin.concurrent.thread
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Which artwork to show on one [screen], Home or the Idle Screen: the owner's JPEG and PNG pictures in the
 * Artwork Folder (`getExternalFilesDir("artwork")`) when there are any, else the Ember gradient. Each call
 * to [next] moves that screen's place one picture on, in name order, round and round. Home and the Idle
 * Screen each keep their own place, so one never skips the other's pictures; both are kept across
 * restarts.
 *
 * It reads storage, so call [next] off the main thread, or use [showNext].
 */
class Artwork(context: Context, private val screen: Screen) {
    private val context = context.applicationContext
    private val place = context.getSharedPreferences("artwork", Context.MODE_PRIVATE)

    /** The screens that show artwork, each with its own place in the pictures. */
    enum class Screen(val key: String) { HOME("home"), IDLE_SCREEN("idle_screen") }

    /** Moves on to the next picture and returns it. */
    fun next(): Picture {
        val (set, pictures) = ownerPictures()?.let { OWNER to it } ?: (EMBER to listOf(StillEmber))
        val setKey = "${screen.key}.$SET"
        val lastKey = "${screen.key}.$LAST"
        val last = place.getString(lastKey, null).takeIf { place.getString(setKey, null) == set }
        val picture = pictures.firstOrNull { last != null && it.name > last } ?: pictures.first()
        place.edit().putString(setKey, set).putString(lastKey, picture.name).apply()
        return picture
    }

    /**
     * Moves on to the next picture and decodes it with [decode] off the main thread, then hands the result
     * to [show] on the main thread: null when the picture can't be read.
     */
    fun <T : Any> showNext(decode: (Picture) -> T, show: (T?) -> Unit) {
        thread(name = "artwork") {
            val picture = next()
            val decoded = try {
                decode(picture)
            } catch (e: IOException) {
                Log.w(TAG, "Cannot show the artwork ${picture.name}", e)
                null
            }
            mainThread.post { show(decoded) }
        }
    }

    /** The owner's pictures in name order, or null when there are none. */
    private fun ownerPictures(): List<Picture>? =
        context.getExternalFilesDir("artwork")
            ?.listFiles { file -> file.isFile && file.extension.lowercase() in OWNER_EXTENSIONS }
            ?.sortedBy { it.name }
            ?.map { OwnerPicture(it.name, ImageDecoder.createSource(it)) }
            ?.takeIf { it.isNotEmpty() }

    private companion object {
        const val TAG = "Artwork"
        val mainThread = Handler(Looper.getMainLooper())

        const val SET = "set"
        const val LAST = "last"
        const val OWNER = "owner"
        const val EMBER = "ember"
        val OWNER_EXTENSIONS = setOf("jpg", "jpeg", "png")
    }
}

/** One artwork picture, made only when asked for. */
interface Picture {
    val name: String

    /**
     * The picture scaled and centre-cropped to fill [width] by [height], as a hardware bitmap: it lives in
     * graphics memory only, with no second copy on the app's heap.
     */
    fun fill(width: Int, height: Int): Bitmap

    /** Like [fill], but a small software bitmap whose pixels can be read, for blurring. */
    fun thumbnail(width: Int, height: Int): Bitmap
}

/** One of the owner's pictures in the Artwork Folder, decoded only when asked for. */
class OwnerPicture(override val name: String, private val source: ImageDecoder.Source) : Picture {
    override fun fill(width: Int, height: Int): Bitmap = decode(width, height, ImageDecoder.ALLOCATOR_HARDWARE)

    override fun thumbnail(width: Int, height: Int): Bitmap = decode(width, height, ImageDecoder.ALLOCATOR_SOFTWARE)

    private fun decode(width: Int, height: Int, allocator: Int): Bitmap =
        ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            val scale = max(width.toFloat() / info.size.width, height.toFloat() / info.size.height)
            val scaledWidth = max(width, (info.size.width * scale).roundToInt())
            val scaledHeight = max(height, (info.size.height * scale).roundToInt())
            decoder.setTargetSize(scaledWidth, scaledHeight)
            val left = (scaledWidth - width) / 2
            val top = (scaledHeight - height) / 2
            decoder.crop = Rect(left, top, left + width, top + height)
            decoder.allocator = allocator
        }
}
