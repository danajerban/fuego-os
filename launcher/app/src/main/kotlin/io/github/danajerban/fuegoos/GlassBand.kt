// The blur (frosted) is adapted from CleanYourTV's HeroArt.java (https://github.com/Gathin23/cleanyourtv,
// commit 30626a8), Copyright (c) 2026 Gathin, MIT licence: see THIRD_PARTY_NOTICES.md. Ported to Kotlin.
package io.github.danajerban.fuegoos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.widget.FrameLayout

/**
 * The Dock's glass band: frosted artwork behind the tiles, with a light tint and a rim.
 *
 * The frost is no live blur. The artwork is shrunk to a 48x27 bitmap (see [frosted]) and stretched
 * over the screen with bilinear filtering; the band shows the part of it that lies behind the band.
 * That costs one tiny texture, drawn again only when the artwork changes, not when tiles animate.
 */
class GlassBand(context: Context, attrs: AttributeSet?) : FrameLayout(context, attrs) {
    private val radius = resources.getDimension(R.dimen.dock_band_corner)
    private val frost = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val tint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x33FFFFFF }
    private val rim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = resources.displayMetrics.density
        color = 0x40FFFFFF
    }
    private val shape = RectF()
    private val frostPlacement = Matrix()
    private val location = IntArray(2)

    init {
        setWillNotDraw(false)
    }

    /** Frosts the band with [blur], a [frosted] copy of the artwork behind it, or clears it with null. */
    fun setFrost(blur: Bitmap?) {
        frost.shader = blur?.let { BitmapShader(it, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP) }
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        shape.set(0f, 0f, width.toFloat(), height.toFloat())
        frost.shader?.let { shader ->
            // Stretch the frost over the whole window, then shift it so the band shows what is behind it.
            getLocationInWindow(location)
            val screen = rootView
            frostPlacement.setScale(screen.width / FROST_WIDTH.toFloat(), screen.height / FROST_HEIGHT.toFloat())
            frostPlacement.postTranslate(-location[0].toFloat(), -location[1].toFloat())
            shader.setLocalMatrix(frostPlacement)
            canvas.drawRoundRect(shape, radius, radius, frost)
        }
        canvas.drawRoundRect(shape, radius, radius, tint)
        shape.inset(rim.strokeWidth / 2, rim.strokeWidth / 2)
        canvas.drawRoundRect(shape, radius, radius, rim)
    }

    companion object {
        const val FROST_WIDTH = 48
        const val FROST_HEIGHT = 27
        private const val SATURATION = 1.3f

        /**
         * A frosted copy of [thumbnail] (artwork shrunk to 4x the frost's size, readable on the CPU):
         * FROST_WIDTH by FROST_HEIGHT pixels, saturated and softened so that, stretched, it shows no seams.
         */
        fun frosted(thumbnail: Bitmap): Bitmap {
            // Halve twice: each filtered halving averages 2x2 pixels, where one 4x step would skip most of them.
            val half = Bitmap.createScaledBitmap(thumbnail, FROST_WIDTH * 2, FROST_HEIGHT * 2, true)
            val small = Bitmap.createScaledBitmap(half, FROST_WIDTH, FROST_HEIGHT, true)
            var pixels = IntArray(FROST_WIDTH * FROST_HEIGHT)
            small.getPixels(pixels, 0, FROST_WIDTH, 0, 0, FROST_WIDTH, FROST_HEIGHT)
            saturate(pixels)
            // Three box passes approximate a gaussian.
            repeat(3) {
                pixels = boxBlur(pixels, horizontal = true)
                pixels = boxBlur(pixels, horizontal = false)
            }
            return Bitmap.createBitmap(pixels, FROST_WIDTH, FROST_HEIGHT, Bitmap.Config.ARGB_8888)
        }

        private fun saturate(pixels: IntArray) {
            for (i in pixels.indices) {
                val p = pixels[i]
                val r = Color.red(p)
                val g = Color.green(p)
                val b = Color.blue(p)
                val lum = 0.2126f * r + 0.7152f * g + 0.0722f * b
                pixels[i] = Color.rgb(
                    channel(lum + (r - lum) * SATURATION),
                    channel(lum + (g - lum) * SATURATION),
                    channel(lum + (b - lum) * SATURATION),
                )
            }
        }

        private fun channel(value: Float) = value.coerceIn(0f, 255f).toInt()

        /** One box blur pass of radius 2 along rows (horizontal) or columns, edges clamped. */
        private fun boxBlur(src: IntArray, horizontal: Boolean): IntArray {
            val w = FROST_WIDTH
            val h = FROST_HEIGHT
            val radius = 2
            val span = 2 * radius + 1
            val dst = IntArray(src.size)
            val lines = if (horizontal) h else w
            val length = if (horizontal) w else h
            for (line in 0 until lines) {
                for (i in 0 until length) {
                    var r = 0
                    var g = 0
                    var b = 0
                    for (k in -radius..radius) {
                        val j = (i + k).coerceIn(0, length - 1)
                        val p = if (horizontal) src[line * w + j] else src[j * w + line]
                        r += Color.red(p)
                        g += Color.green(p)
                        b += Color.blue(p)
                    }
                    dst[if (horizontal) line * w + i else i * w + line] = Color.rgb(r / span, g / span, b / span)
                }
            }
            return dst
        }
    }
}
