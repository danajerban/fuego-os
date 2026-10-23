package io.github.danajerban.fuegoos

import android.graphics.Bitmap
import android.service.dreams.DreamService
import android.widget.ImageView

/**
 * The Idle Screen: the TV's screensaver. It shows the same [Artwork] as Home, from its own place in the
 * pictures, dimmed to half brightness, and cross-fades to the next picture every minute. When the
 * Artwork Folder is empty it shows the Ember gradient slowly moving instead ([EmberView]). The clock
 * ([ClockView]) shows over it, bright above the dimming, larger than on Home, drifting a little every minute. It runs only
 * while the TV is idle; between dreams the Launcher holds no artwork and runs nothing.
 */
class IdleScreen : DreamService() {
    /** The picture on screen, and the one the next picture fades in on; they swap after every fade. */
    private lateinit var shown: ImageView
    private lateinit var incoming: ImageView
    private lateinit var ember: EmberView
    private lateinit var clockView: ClockView
    private lateinit var artwork: Artwork

    /** Counts pictures, so one decoded after the dream stopped, or after a newer one, is never shown. */
    private var turn = 0
    private var nextChange: AutoCloseable? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        // Not interactive: the first key press only wakes the TV, and DreamService consumes it.
        isInteractive = false
        isFullscreen = true
        setContentView(R.layout.idle_screen)
        shown = findViewById(R.id.artwork_front)
        incoming = findViewById(R.id.artwork_back)
        ember = findViewById(R.id.ember)
        clockView = findViewById<ClockView>(R.id.clock).apply {
            drifts = true
            scaleX = CLOCK_SCALE
            scaleY = CLOCK_SCALE
            alpha = CLOCK_ALPHA
        }
        artwork = Artwork(this, Artwork.Screen.IDLE_SCREEN)
    }

    override fun onDreamingStarted() {
        super.onDreamingStarted()
        clockView.start()
        showNext()
    }

    override fun onDreamingStopped() {
        turn++
        nextChange?.close()
        nextChange = null
        listOf(shown, incoming).forEach {
            it.animate().cancel()
            it.setImageDrawable(null)
        }
        ember.animate().cancel()
        ember.stop()
        clockView.stop()
        super.onDreamingStopped()
    }

    private fun showNext() {
        val thisTurn = ++turn
        val screen = windowManager.currentWindowMetrics.bounds
        artwork.showNext(
            // Ember is not decoded here: the Idle Screen draws it moving.
            decode = { picture -> if (picture === StillEmber) StillEmber else picture.fill(screen.width(), screen.height()) },
            show = { next ->
                if (thisTurn == turn) {
                    when (next) {
                        is Bitmap -> crossFade(next)
                        StillEmber -> moveEmber()
                    }
                    nextChange = clock.schedule(CHANGE_MS) { showNext() }
                }
            },
        )
    }

    private fun crossFade(bitmap: Bitmap) {
        val leaving = shown
        shown = incoming
        incoming = leaving
        shown.setImageBitmap(bitmap)
        shown.alpha = 0f
        shown.bringToFront()
        shown.animate().alpha(1f).setDuration(FADE_MS).withEndAction {
            leaving.setImageDrawable(null)
            leaving.alpha = 0f
            ember.stop()
            ember.alpha = 0f
        }
    }

    /** Fades the moving Ember in over whatever is on screen; once it is moving, it just keeps going. */
    private fun moveEmber() {
        if (ember.isMoving) return
        ember.start(clock::now)
        ember.alpha = 0f
        ember.bringToFront()
        ember.animate().alpha(1f).setDuration(FADE_MS).withEndAction {
            listOf(shown, incoming).forEach {
                it.setImageDrawable(null)
                it.alpha = 0f
            }
        }
    }

    private companion object {
        const val CHANGE_MS = 60_000L
        const val FADE_MS = 1_000L

        /** How much bigger the Idle Screen's clock is than Home's. */
        const val CLOCK_SCALE = 1.5f

        /** The clock is over the veil, a little softer than Home's: its 90% white shows at about 83%. */
        const val CLOCK_ALPHA = 0.92f
    }
}
