package io.github.danajerban.fuegoos

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.rules.ExternalResource

/**
 * The Idle Screen's clock, moved by hand: time stands still until [advance] moves it on and runs what
 * fell due. The tests run in the Launcher's process, so the Idle Screen the TV starts uses this clock.
 */
class ManualClock : ExternalResource(), Clock {
    private lateinit var clockBefore: Clock
    private var now = 0L
    private val pending = mutableListOf<Pair<Long, Runnable>>()

    override fun before() {
        clockBefore = IdleScreen.clock
        IdleScreen.clock = this
    }

    override fun after() {
        IdleScreen.clock = clockBefore
    }

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
}
