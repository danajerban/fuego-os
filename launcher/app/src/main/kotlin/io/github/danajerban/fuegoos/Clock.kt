package io.github.danajerban.fuegoos

import android.os.Handler
import android.os.Looper
import android.os.SystemClock

/** Times the Launcher: the clock's minutes, the Idle Screen's picture changes and its gradient's motion. */
interface Clock {
    /** The time now, in milliseconds since some fixed point; it never jumps. */
    fun now(): Long

    /** The time of day now, in milliseconds since the epoch, as the TV's clock has it. */
    fun wallTime(): Long

    /** Runs [action] on the main thread after [delayMs]; closing the result cancels it. */
    fun schedule(delayMs: Long, action: Runnable): AutoCloseable
}

private val mainThread = Handler(Looper.getMainLooper())

/** The Launcher's clock: the TV's own. Tests replace it with a clock they move by hand. */
var clock: Clock = object : Clock {
    override fun now() = SystemClock.uptimeMillis()

    override fun wallTime() = System.currentTimeMillis()

    override fun schedule(delayMs: Long, action: Runnable): AutoCloseable {
        mainThread.postDelayed(action, delayMs)
        return AutoCloseable { mainThread.removeCallbacks(action) }
    }
}
