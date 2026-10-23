package io.github.danajerban.fuegoos

import android.graphics.Bitmap
import android.util.Log
import android.view.WindowManager
import android.widget.ImageView
import java.io.IOException
import kotlin.concurrent.thread

/**
 * Home's artwork: the next [Artwork] picture on every Home visit, full screen in [view] and frosted on
 * the Dock's [band]. Pictures are decoded off the main thread and faded in, so the Dock never waits
 * for them; between visits the Launcher holds no artwork at all.
 */
class HomeArtwork(private val view: ImageView, private val band: GlassBand) {
    private val artwork = Artwork(view.context)

    /** Counts visits, so a picture decoded for an earlier visit is never shown in a later one. */
    private var visit = 0

    /** Shows the next picture. Call when Home comes on screen. */
    fun show() {
        val thisVisit = ++visit
        val screen = view.context.getSystemService(WindowManager::class.java).currentWindowMetrics.bounds
        thread(name = "artwork") {
            val picture = artwork.next()
            val (full, frost) = try {
                picture.fill(screen.width(), screen.height()) to
                    GlassBand.frosted(picture.thumbnail(GlassBand.FROST_WIDTH * 4, GlassBand.FROST_HEIGHT * 4))
            } catch (e: IOException) {
                Log.w(TAG, "Cannot show the artwork ${picture.name}", e)
                return@thread
            }
            view.post { if (thisVisit == visit) fadeIn(full, frost) }
        }
    }

    /** Lets go of the picture. Call when Home leaves the screen. */
    fun hide() {
        visit++
        view.animate().cancel()
        view.alpha = 0f
        view.setImageDrawable(null)
        band.setFrost(null)
    }

    private fun fadeIn(full: Bitmap, frost: Bitmap) {
        view.setImageBitmap(full)
        band.setFrost(frost)
        view.animate().alpha(1f).setDuration(FADE_MS)
    }

    private companion object {
        const val TAG = "HomeArtwork"
        const val FADE_MS = 200L
    }
}
