package io.github.danajerban.fuegoos

import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator

/**
 * Shows which Dock tile has focus: the focused tile scales up and the [glass] highlight slides under it.
 * Both animations change only transform and opacity and finish in [DURATION_MS], inside the 150 ms budget.
 *
 * [glass] and [dock] share a parent, and [dock] holds the tiles.
 */
class DockFocus(private val dock: ViewGroup, private val glass: View) {
    private val easing = DecelerateInterpolator()

    init {
        glass.alpha = 0f
        for (i in 0 until dock.childCount) {
            dock.getChildAt(i).setOnFocusChangeListener { tile, hasFocus -> if (hasFocus) focus(tile) else rest(tile) }
        }
        // Tiles appear and vanish as apps are installed or removed: put the glass back under the focused tile.
        dock.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> dock.findFocus()?.let { snapTo(it) } }
    }

    private fun focus(tile: View) {
        tile.animate().scaleX(SCALE).scaleY(SCALE).setDuration(DURATION_MS).setInterpolator(easing)
        if (glass.alpha == 0f || !tile.isLaidOut) return snapTo(tile)
        glass.animate().translationX(glassX(tile)).translationY(glassY(tile)).scaleX(SCALE).scaleY(SCALE)
            .setDuration(DURATION_MS).setInterpolator(easing)
    }

    private fun rest(tile: View) {
        tile.animate().scaleX(1f).scaleY(1f).setDuration(DURATION_MS).setInterpolator(easing)
    }

    /** Puts the glass under [tile] at once, with no animation. */
    private fun snapTo(tile: View) {
        if (!tile.isLaidOut) return
        glass.animate().cancel()
        glass.translationX = glassX(tile)
        glass.translationY = glassY(tile)
        glass.scaleX = SCALE
        glass.scaleY = SCALE
        glass.alpha = 1f
    }

    private fun glassX(tile: View) = dock.left + tile.left + (tile.width - glass.width) / 2f - glass.left

    private fun glassY(tile: View) = dock.top + tile.top + (tile.height - glass.height) / 2f - glass.top

    private companion object {
        const val SCALE = 1.1f
        const val DURATION_MS = 120L
    }
}
