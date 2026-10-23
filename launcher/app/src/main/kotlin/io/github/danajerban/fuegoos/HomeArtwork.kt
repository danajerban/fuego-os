package io.github.danajerban.fuegoos

import android.graphics.Bitmap
import android.view.WindowManager
import android.widget.ImageView

/**
 * Home's artwork: the next [Artwork] picture on every Home visit, full screen in [view] and frosted on
 * the Dock's [band]. Pictures are decoded off the main thread and faded in, so the Dock never waits
 * for them; between visits the Launcher holds no artwork at all.
 */
class HomeArtwork(private val view: ImageView, private val band: GlassBand) {
    private val artwork = Artwork(view.context, Artwork.Screen.HOME)

    /** Counts visits, so a picture decoded for an earlier visit is never shown in a later one. */
    private var visit = 0

    /** Shows the next picture. Call when Home comes on screen. */
    fun show() {
        val thisVisit = ++visit
        val screen = view.context.getSystemService(WindowManager::class.java).currentWindowMetrics.bounds
        artwork.showNext(
            decode = { picture ->
                picture.fill(screen.width(), screen.height()) to
                    GlassBand.frosted(picture.thumbnail(GlassBand.FROST_WIDTH * 4, GlassBand.FROST_HEIGHT * 4))
            },
            show = { pictures -> if (pictures != null && thisVisit == visit) fadeIn(pictures.first, pictures.second) },
        )
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
        const val FADE_MS = 200L
    }
}
