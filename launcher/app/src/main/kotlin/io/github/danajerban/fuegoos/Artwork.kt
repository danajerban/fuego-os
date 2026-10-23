package io.github.danajerban.fuegoos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.graphics.Rect
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Which artwork to show, for Home and the Idle Screen alike: the owner's JPEG and PNG pictures in the
 * artwork folder (`getExternalFilesDir("artwork")`) when there are any, else the bundled set. Each call
 * to [next] moves one picture on, in name order, round and round; the place is kept across restarts.
 *
 * It reads storage, so call it off the main thread.
 */
class Artwork(context: Context) {
    private val context = context.applicationContext
    private val place = context.getSharedPreferences("artwork", Context.MODE_PRIVATE)

    /** Moves on to the next picture and returns it. */
    fun next(): Picture {
        val (set, pictures) = ownerPictures()?.let { OWNER to it } ?: (BUNDLED to bundledPictures())
        val last = place.getString(LAST, null).takeIf { place.getString(SET, null) == set }
        val picture = pictures.firstOrNull { last != null && it.name > last } ?: pictures.first()
        place.edit().putString(SET, set).putString(LAST, picture.name).apply()
        return picture
    }

    /** The owner's pictures in name order, or null when there are none. */
    private fun ownerPictures(): List<Picture>? =
        context.getExternalFilesDir("artwork")
            ?.listFiles { file -> file.isFile && file.extension.lowercase() in OWNER_EXTENSIONS }
            ?.sortedBy { it.name }
            ?.map { Picture(it.name, ImageDecoder.createSource(it)) }
            ?.takeIf { it.isNotEmpty() }

    private fun bundledPictures(): List<Picture> = BUNDLED_PICTURES.map { (name, id) ->
        Picture(name, ImageDecoder.createSource(context.resources, id))
    }

    private companion object {
        const val SET = "set"
        const val LAST = "last"
        const val OWNER = "owner"
        const val BUNDLED = "bundled"
        val OWNER_EXTENSIONS = setOf("jpg", "jpeg", "png")

        /** The bundled artwork, in name order. Made by launcher/tools/make-bundled-artwork.py. */
        val BUNDLED_PICTURES = listOf(
            "dusk" to R.drawable.artwork_dusk,
            "ember" to R.drawable.artwork_ember,
            "moss" to R.drawable.artwork_moss,
            "tide" to R.drawable.artwork_tide,
        )
    }
}

/** One artwork picture, decoded only when asked for. */
class Picture(val name: String, private val source: ImageDecoder.Source) {
    /**
     * The picture scaled and centre-cropped to fill [width] by [height], as a hardware bitmap: it lives in
     * graphics memory only, with no second copy on the app's heap.
     */
    fun fill(width: Int, height: Int): Bitmap = decode(width, height, ImageDecoder.ALLOCATOR_HARDWARE)

    /** Like [fill], but a small software bitmap whose pixels can be read, for blurring. */
    fun thumbnail(width: Int, height: Int): Bitmap = decode(width, height, ImageDecoder.ALLOCATOR_SOFTWARE)

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
