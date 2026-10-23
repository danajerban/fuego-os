package io.github.danajerban.fuegoos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RenderNode
import android.graphics.Shader
import android.util.AttributeSet
import android.view.Choreographer
import android.view.View
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Ember, the Launcher's own artwork when the Artwork Folder has no pictures: a dark plum ramp from the
 * top-left to the bottom-right, with three soft glows on top (purple, crimson, orange). Home shows it
 * still ([StillEmber]); the Idle Screen shows it slowly moving ([EmberView]). Both draw it here, so they
 * can't drift apart.
 *
 * Positions are fractions of the screen's width and height; radii are in screen heights, so the glows
 * are round. Each glow's colour is laid over what is below it with alpha `k * exp(-(d/r)^2)`, d being
 * the distance from its centre. The shaders are made once for one size; drawing again, moved, only
 * moves the canvas, and allocates nothing.
 */
class Ember(private val width: Int, private val height: Int) {
    private val base = Paint(Paint.DITHER_FLAG).apply {
        // The ramp runs over (u + v) / 2 in the unit square, then the square is stretched over the screen.
        shader = LinearGradient(0f, 0f, 1f, 1f, rampColours(), null, Shader.TileMode.CLAMP).apply {
            setLocalMatrix(Matrix().apply { setScale(width.toFloat(), height.toFloat()) })
        }
    }
    private val glowPaints = GLOWS.map { glow ->
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.DITHER_FLAG).apply {
            shader = RadialGradient(0f, 0f, glow.radius * REACH * height, glow.falloff(), null, Shader.TileMode.CLAMP)
        }
    }

    /** Draws Ember as it is [timeMs] after it started moving; at 0 it is Home's still picture. */
    fun draw(canvas: Canvas, timeMs: Long = 0) {
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), base)
        val seconds = timeMs / 1000.0
        GLOWS.forEachIndexed { i, glow ->
            val x = (glow.x + glow.driftX * wave(seconds, glow.periodX)) * width
            val y = (glow.y + glow.driftY * wave(seconds, glow.periodY)) * height
            val scale = 1 + BREATH * wave(seconds, glow.periodBreath)
            canvas.save()
            canvas.translate(x.toFloat(), y.toFloat())
            canvas.scale(scale.toFloat(), scale.toFloat())
            canvas.drawCircle(0f, 0f, glow.radius * REACH * height, glowPaints[i])
            canvas.restore()
        }
    }

    /** One soft glow: where it sits, its size and strength, and how it drifts (periods in seconds). */
    private class Glow(
        val colour: Int, val x: Float, val y: Float, val radius: Float, val strength: Float,
        val driftX: Float, val periodX: Double, val driftY: Float, val periodY: Double, val periodBreath: Double,
    ) {
        /** The glow's colour at [STOPS] even steps from its centre out to [REACH] radii, where it is gone. */
        fun falloff() = IntArray(STOPS) { i ->
            val d = REACH * i / (STOPS - 1)
            val alpha = if (i == STOPS - 1) 0f else strength * exp(-d * d)
            ((alpha * 255).roundToInt() shl 24) or (colour and 0xFFFFFF)
        }
    }

    companion object {
        /**
         * How many times smaller than the screen Ember is drawn before it is stretched over it, on Home and
         * on the Idle Screen alike. Its softest detail spans hundreds of pixels, so the stretch loses nothing.
         */
        const val SHRINK = 4

        /** A screen [length] in pixels, shrunk by [SHRINK] and rounded up. */
        fun shrunk(length: Int) = (length + SHRINK - 1) / SHRINK

        private val TOP_LEFT = Color.parseColor("#14051F")
        private val BOTTOM_RIGHT = Color.parseColor("#2A0A2E")

        /** Drawn in this order, each over the last. Every drift is a smooth loop of 40 to 90 seconds. */
        private val GLOWS = listOf(
            Glow(Color.parseColor("#6A1FB0"), 0.15f, 0.20f, 0.75f, 0.85f, 0.08f, 71.0, 0.07f, 53.0, 61.0),
            Glow(Color.parseColor("#C41E4A"), 0.55f, 0.60f, 0.55f, 0.75f, 0.10f, 83.0, 0.08f, 47.0, 67.0),
            Glow(Color.parseColor("#FF7A1A"), 0.95f, 0.95f, 0.60f, 0.85f, 0.07f, 59.0, 0.09f, 89.0, 43.0),
        )

        /** How far, in radii, a glow is drawn: beyond 2.5 radii it adds less than half a colour level. */
        private const val REACH = 2.5f

        /** Enough stops that the straight lines between them stay within a colour level of the curve. */
        private const val STOPS = 24

        /** How much a glow's radius grows and shrinks as it breathes. */
        private const val BREATH = 0.05

        /** A smooth wave from -1 to 1 and back every [period] seconds, at 0 when [seconds] is 0. */
        private fun wave(seconds: Double, period: Double) = sin(2 * PI * seconds / period)

        /** The ramp from the top-left to the bottom-right, eased in and out (smoothstep) over nine stops. */
        private fun rampColours() = IntArray(9) { i ->
            val t = i / 8f
            val s = t * t * (3 - 2 * t)
            Color.rgb(mix(Color.red(TOP_LEFT), Color.red(BOTTOM_RIGHT), s), mix(Color.green(TOP_LEFT), Color.green(BOTTOM_RIGHT), s), mix(Color.blue(TOP_LEFT), Color.blue(BOTTOM_RIGHT), s))
        }

        private fun mix(from: Int, to: Int, s: Float) = (from + (to - from) * s).roundToInt()
    }
}

/** Ember standing still, as an [Artwork] picture: what Home shows when the Artwork Folder is empty. */
object StillEmber : Picture {
    override val name = "ember"

    /**
     * Ember at a [Ember.SHRINK]th of [width] by [height], which Home's centre-cropping view stretches to fill:
     * a gradient this soft looks the same, in a sixteenth of the graphics memory. It is drawn on the CPU on
     * the calling thread, and moved to graphics memory the way decoded pictures are, so it never holds up
     * the GPU while Home draws its first frame.
     */
    override fun fill(width: Int, height: Int): Bitmap {
        val small = draw(Ember.shrunk(width), Ember.shrunk(height))
        return small.copy(Bitmap.Config.HARDWARE, false).also { small.recycle() }
    }

    override fun thumbnail(width: Int, height: Int): Bitmap = draw(width, height)

    private fun draw(width: Int, height: Int): Bitmap =
        Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { Ember(width, height).draw(Canvas(it)) }
}

/**
 * Ember moving: the Idle Screen's artwork when the Artwork Folder is empty. The glows drift on slow loops
 * and breathe, timed by a clock, so nothing on screen ever stands still.
 *
 * It redraws about 30 times a second while started, cheaply: Ember is drawn at a [Ember.SHRINK]th of the
 * view's width and height into a GPU layer that is kept from frame to frame, and the layer is stretched
 * over the view with filtering. Each frame costs four gradient fills over a sixteenth of the screen and
 * one full-screen copy; no bitmap, no blur.
 */
class EmberView(context: Context, attrs: AttributeSet?) : View(context, attrs), Choreographer.FrameCallback {
    private val frame = RenderNode("ember").apply { setUseCompositingLayer(true, null) }
    private var ember: Ember? = null
    private var now: (() -> Long)? = null
    private var startedAt = 0L
    private var timeMs = 0L
    private var lastFrameNanos = 0L

    val isMoving get() = now != null

    /** Starts moving, from Home's still picture, timed by [now] (milliseconds). */
    fun start(now: () -> Long) {
        this.now = now
        startedAt = now()
        timeMs = 0
        lastFrameNanos = 0
        Choreographer.getInstance().postFrameCallback(this)
        invalidate()
    }

    /** Stops moving; the picture stays where it is. */
    fun stop() {
        now = null
        Choreographer.getInstance().removeFrameCallback(this)
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (now == null) return
        // Every other frame of a 60 Hz screen: the drift is far too slow to need more.
        if (frameTimeNanos - lastFrameNanos >= FRAME_NANOS) {
            lastFrameNanos = frameTimeNanos
            invalidate()
        }
        Choreographer.getInstance().postFrameCallback(this)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        val layerWidth = Ember.shrunk(w)
        val layerHeight = Ember.shrunk(h)
        frame.setPosition(0, 0, layerWidth, layerHeight)
        ember = if (w > 0 && h > 0) Ember(layerWidth, layerHeight) else null
    }

    override fun onDraw(canvas: Canvas) {
        val ember = ember ?: return
        now?.let { timeMs = it() - startedAt }
        ember.draw(frame.beginRecording(), timeMs)
        frame.endRecording()
        canvas.save()
        canvas.scale(Ember.SHRINK.toFloat(), Ember.SHRINK.toFloat())
        canvas.drawRenderNode(frame)
        canvas.restore()
    }

    override fun onDetachedFromWindow() {
        stop()
        super.onDetachedFromWindow()
    }

    private companion object {
        const val FRAME_NANOS = 30_000_000L
    }
}
