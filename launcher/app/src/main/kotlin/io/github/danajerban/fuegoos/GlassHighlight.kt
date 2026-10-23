// Adapted from CleanYourTV's GlassView.java (https://github.com/Gathin23/cleanyourtv, commit 30626a8),
// Copyright (c) 2026 Gathin, MIT licence: see THIRD_PARTY_NOTICES.md. Ported to Kotlin, festival accents removed.
package io.github.danajerban.fuegoos

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View

/**
 * The Dock's focus highlight: a translucent glass slab with a soft sheen, a bright top, a crisp rim
 * and a faint outer glow. One slab floats under the tiles and moves to whichever tile has focus.
 *
 * It is drawn once into a hardware layer. Focus moves only change its translation and scale, so the
 * GPU moves a cached texture instead of redrawing the glow and gradients on every frame.
 */
class GlassHighlight(context: Context, attrs: AttributeSet?) : View(context, attrs) {
    private val density = resources.displayMetrics.density
    private val radius = resources.getDimension(R.dimen.dock_tile_corner)
    private val glowWidth = resources.getDimension(R.dimen.focus_glass_glow)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val specular = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.5f * density
        color = 0xCCFFFFFF.toInt()
    }
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val slab = RectF()

    init {
        setLayerType(LAYER_TYPE_HARDWARE, null)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        fill.shader = LinearGradient(0f, 0f, 0f, h.toFloat(), 0x3DFFFFFF, 0x12FFFFFF, Shader.TileMode.CLAMP)
        specular.shader = LinearGradient(0f, 0f, 0f, h * 0.45f, 0x66FFFFFF, 0x00FFFFFF, Shader.TileMode.CLAMP)
    }

    override fun onDraw(canvas: Canvas) {
        slab.set(glowWidth, glowWidth, width - glowWidth, height - glowWidth)

        // Outer glow: thin rings, each a little fainter, so it fades out without visible bands.
        val rings = 12
        val step = glowWidth / rings
        glow.strokeWidth = step + 0.5f
        for (i in 0 until rings) {
            val o = step * (i + 0.5f)
            glow.color = (Math.round(GLOW_ALPHA * (1f - i.toFloat() / rings)) shl 24) or 0xFFFFFF
            canvas.drawRoundRect(slab.left - o, slab.top - o, slab.right + o, slab.bottom + o, radius + o, radius + o, glow)
        }

        canvas.drawRoundRect(slab, radius, radius, fill)

        // Sheen across the top 45%. clipRect stays on the GPU, where clipPath may not.
        canvas.save()
        canvas.clipRect(slab.left, slab.top, slab.right, slab.top + slab.height() * 0.45f)
        canvas.drawRoundRect(slab, radius, radius, specular)
        canvas.restore()

        canvas.drawRoundRect(slab, radius, radius, rim)
    }

    private companion object {
        const val GLOW_ALPHA = 0x30
    }
}
