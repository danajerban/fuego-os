package io.github.danajerban.fuegoos

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.rules.ExternalResource
import java.util.Calendar

/**
 * The Launcher's clock, moved by hand: time stands still until [advance] moves it on and runs what fell
 * due. The wall clock starts at [START]. The tests run in the Launcher's process, so Home and the Idle
 * Screen the TV starts use this clock.
 */
class ManualClock : ExternalResource(), Clock {
    private lateinit var clockBefore: Clock
    private var now = 0L
    private val pending = mutableListOf<Pair<Long, Runnable>>()

    override fun before() {
        clockBefore = clock
        clock = this
    }

    override fun after() {
        clock = clockBefore
    }

    override fun now() = now

    override fun wallTime() = START + now

    override fun schedule(delayMs: Long, action: Runnable): AutoCloseable {
        val entry = now + delayMs to action
        pending += entry
        return AutoCloseable { pending -= entry }
    }

    /** Moves time on by [ms], running on the main thread whatever falls due. */
    fun advance(ms: Long) = InstrumentationRegistry.getInstrumentation().runOnMainSync {
        now += ms
        val due = pending.filter { it.first <= now }
        pending -= due.toSet()
        due.forEach { it.second.run() }
    }

    companion object {
        /** Friday 23 October 2026, 18:41:30 in the TV's time zone: where the wall clock starts. */
        val START: Long = Calendar.getInstance().run {
            clear()
            set(2026, Calendar.OCTOBER, 23, 18, 41, 30)
            timeInMillis
        }
    }
}
