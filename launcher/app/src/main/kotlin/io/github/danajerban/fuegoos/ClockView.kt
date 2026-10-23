package io.github.danajerban.fuegoos

import android.content.Context
import android.text.format.DateFormat
import android.util.AttributeSet
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * The clock on Home and the Idle Screen: the time, large and bold, over a hairline and the date. It
 * follows the TV's 12/24-hour setting, locale and time zone, and moves on exactly at each minute, timed
 * by [clock] (no broadcast receiver: the Launcher declares none). Its text is frosted white, a little
 * clear, with a soft shadow, so it reads over purple and orange alike (style `ClockText`).
 *
 * Laid out from `R.layout.clock`. [start] it while it is on screen and [stop] it when it goes.
 */
class ClockView(context: Context, attrs: AttributeSet?) : LinearLayout(context, attrs) {
    private lateinit var time: TextView
    private lateinit var date: TextView
    private val driftRadius = resources.getDimension(R.dimen.clock_drift)
    private val easing = AccelerateDecelerateInterpolator()
    private var nextTick: AutoCloseable? = null
    private var driftStep = 0

    /** Whether the clock moves a few dp to a new place every minute, against burn-in. */
    var drifts = false

    override fun onFinishInflate() {
        super.onFinishInflate()
        time = findViewById(R.id.clock_time)
        date = findViewById(R.id.clock_date)
    }

    /** Shows the time now and moves on at every minute until [stop]. */
    fun start() {
        stop()
        if (drifts) {
            translationX = driftX(driftStep)
            translationY = driftY(driftStep)
        }
        tick()
    }

    fun stop() {
        nextTick?.close()
        nextTick = null
        animate().cancel()
    }

    private fun tick() {
        val now = clock.wallTime()
        show(now)
        nextTick = clock.schedule(MINUTE_MS - now % MINUTE_MS) {
            if (drifts) drift()
            tick()
        }
    }

    /** Writes [wallTime] out in the TV's locale and 12/24-hour setting, in its time zone as it is now. */
    private fun show(wallTime: Long) {
        val locale = resources.configuration.locales[0]
        val twentyFour = DateFormat.is24HourFormat(context)
        // Like a lock screen, the 12-hour time leaves out AM and PM.
        val timePattern = DateFormat.getBestDateTimePattern(locale, if (twentyFour) "Hm" else "hm")
            .let { if (twentyFour) it else it.replace("a", "").trim() }
        val datePattern = DateFormat.getBestDateTimePattern(locale, "EEEEMMMMd")
        // A new format each minute takes up the time zone as it is now.
        val at = Date(wallTime)
        time.text = SimpleDateFormat(timePattern, locale).format(at)
        date.text = SimpleDateFormat(datePattern, locale).format(at)
    }

    /** Eases the clock to the next of its places, a few dp around where it is laid out. */
    private fun drift() {
        driftStep = (driftStep + 1) % DRIFT_PLACES
        animate().translationX(driftX(driftStep)).translationY(driftY(driftStep))
            .setDuration(DRIFT_MS).setInterpolator(easing)
    }

    // The places lie on a circle, visited in a scattered order: each move goes some way across it.
    private fun driftAngle(step: Int) = 2 * PI * (step * 3 % DRIFT_PLACES) / DRIFT_PLACES

    private fun driftX(step: Int) = (driftRadius * cos(driftAngle(step))).toFloat()

    private fun driftY(step: Int) = (driftRadius * sin(driftAngle(step))).toFloat()

    private companion object {
        const val MINUTE_MS = 60_000L
        const val DRIFT_PLACES = 8
        const val DRIFT_MS = 3_000L
    }
}
