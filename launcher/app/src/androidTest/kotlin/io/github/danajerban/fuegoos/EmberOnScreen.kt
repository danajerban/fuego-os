package io.github.danajerban.fuegoos

import android.graphics.PointF

/**
 * What the Ember gradient looks like on screen, standing still: its colours at a few points clear of the
 * Dock and of the clock (on Home and on the Idle Screen), worked out from the gradient's definition (the owner's reference render) rather than from the
 * Launcher's code.
 */
object EmberOnScreen {
    val points = listOf(PointF(0.15f, 0.2f), PointF(0.5f, 0.08f), PointF(0.75f, 0.55f), PointF(0.95f, 0.5f), PointF(0.1f, 0.8f))
    val colours = listOf(0x5D1987, 0x5D144F, 0x9B362D, 0x8D3B23, 0x431158)

    /** The same colours under the Idle Screen's veil, at half brightness. */
    val dimmedColours = colours.map { (it shr 1) and 0x7F7F7F }
}
