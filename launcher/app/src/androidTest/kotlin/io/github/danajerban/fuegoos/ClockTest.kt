package io.github.danajerban.fuegoos

import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The clock on Home and on the Idle Screen. The wall clock starts at Friday 23 October 2026, 18:41:30
 * ([ManualClock.START]); the emulator's locale is US English.
 */
@RunWith(AndroidJUnit4::class)
class ClockTest {
    @get:Rule
    val homeTakeover = HomeTakeover()

    @get:Rule
    val dockApps = DockApps()

    @get:Rule
    val ownerPictures = OwnerPictures()

    @get:Rule
    val screensaver = Screensaver()

    @get:Rule
    val hourFormat = HourFormat()

    @get:Rule
    val clock = ManualClock()

    private val tv = Tv()

    @Test
    fun homeShowsTheTimeAndDate() {
        hourFormat.use(24)

        tv.pressHome()

        assertTrue("Home's clock shows ${tv.clockText()}", tv.waitForClock("18:41", DATE))
    }

    @Test
    fun homesClockMovesOnExactlyOnTheMinute() {
        hourFormat.use(24)
        tv.pressHome()
        check(tv.waitForClock("18:41", DATE)) { "Home's clock shows ${tv.clockText()}" }

        clock.advance(29_000)
        SystemClock.sleep(500)
        assertEquals("The clock moved on before the minute was up", "18:41" to DATE, tv.clockText())

        clock.advance(1_000)
        assertTrue("The clock did not move on at the minute; it shows ${tv.clockText()}", tv.waitForClock("18:42", DATE))

        clock.advance(60_000)
        assertTrue("The clock did not move on at the next minute; it shows ${tv.clockText()}", tv.waitForClock("18:43", DATE))
    }

    @Test
    fun theClockFollowsTheTvsTwelveHourSetting() {
        hourFormat.use(12)

        tv.pressHome()

        assertTrue("Home's clock shows ${tv.clockText()}", tv.waitForClock("6:41", DATE))
    }

    @Test
    fun idleScreenShowsTheClockAndItMovesOnOnTheMinute() {
        hourFormat.use(24)
        tv.pressHome()

        screensaver.goIdle()
        assertTrue("The Idle Screen's clock shows ${tv.clockText()}", tv.waitForClock("18:41", DATE))

        clock.advance(30_000)
        assertTrue("The Idle Screen's clock did not move on at the minute; it shows ${tv.clockText()}", tv.waitForClock("18:42", DATE))
    }

    @Test
    fun idleScreensClockDriftsAgainstBurnIn() {
        hourFormat.use(24)
        tv.pressHome()
        screensaver.goIdle()
        check(tv.waitForClock("18:41", DATE)) { "The Idle Screen's clock shows ${tv.clockText()}" }
        SystemClock.sleep(DRIFT_MS)
        val before = tv.clockTimeBounds()

        clock.advance(30_000)
        SystemClock.sleep(DRIFT_MS)
        val after = tv.clockTimeBounds()

        assertNotEquals("The clock did not move at the minute", before, after)
        assertTrue(
            "The clock moved from $before to $after, more than a few dp",
            Math.abs(after.centerX() - before.centerX()) < 60 && Math.abs(after.centerY() - before.centerY()) < 60,
        )
        assertTrue("The Idle Screen stopped", screensaver.isShowing)
    }

    @Test
    fun idleScreensClockShowsOverTheOwnersPictures() {
        hourFormat.use(24)
        tv.pressHome()
        ownerPictures.add("red.png", RED)
        screensaver.goIdle()
        check(tv.waitForClock("18:41", DATE)) { "The Idle Screen's clock shows ${tv.clockText()}" }
        SystemClock.sleep(2_000) // past the picture's fade-in

        val seen = tv.coloursIn(tv.clockTimeBounds())

        // The picture is red with almost no green; the clock's white, dimmed with it, has plenty.
        assertTrue("The clock is hidden behind the picture", seen.count { (it shr 8 and 0xFF) > 0x50 } > seen.size / 50)
    }

    private companion object {
        const val DATE = "Friday, October 23"
        const val RED = 0xD03020

        /** Long enough for the clock's drift to finish. */
        const val DRIFT_MS = 4_000L
    }
}
