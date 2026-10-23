package io.github.danajerban.fuegoos

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.service.dreams.DreamService
import android.widget.ImageView

/**
 * The Idle Screen: the TV's screensaver. It shows the same [Artwork] as Home, from its own place in the
 * pictures, dimmed to half brightness, and cross-fades to the next picture every minute. It runs only while the TV is idle; between dreams
 * the Launcher holds no artwork and runs nothing.
 */
class IdleScreen : DreamService() {
    /** The picture on screen, and the one the next picture fades in on; they swap after every fade. */
    private lateinit var shown: ImageView
    private lateinit var incoming: ImageView
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
        artwork = Artwork(this, Artwork.Screen.IDLE_SCREEN)
    }

    override fun onDreamingStarted() {
        super.onDreamingStarted()
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
        super.onDreamingStopped()
    }

    private fun showNext() {
        val thisTurn = ++turn
        val screen = windowManager.currentWindowMetrics.bounds
        artwork.showNext(
            decode = { picture -> picture.fill(screen.width(), screen.height()) },
            show = { bitmap ->
                if (thisTurn == turn) {
                    bitmap?.let(::crossFade)
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
        }
    }

    companion object {
        private const val CHANGE_MS = 60_000L
        private const val FADE_MS = 1_000L

        private val mainThread = Handler(Looper.getMainLooper())

        /** When the next picture comes. Tests replace it with a clock they move by hand. */
        var clock = Clock { delayMs, action ->
            mainThread.postDelayed(action, delayMs)
            AutoCloseable { mainThread.removeCallbacks(action) }
        }
    }
}

/** Runs the Idle Screen's picture changes. */
fun interface Clock {
    /** Runs [action] on the main thread after [delayMs]; closing the result cancels it. */
    fun schedule(delayMs: Long, action: Runnable): AutoCloseable
}
