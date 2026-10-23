package io.github.danajerban.fuegoos

import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class IdleScreenTest {
    @get:Rule
    val homeTakeover = HomeTakeover()

    @get:Rule
    val ownerPictures = OwnerPictures()

    @get:Rule
    val screensaver = Screensaver()

    @get:Rule
    val clock = ManualClock()

    private val tv = Tv()

    @Test
    fun idleScreenShowsTheArtworkAtHalfBrightness() {
        tv.pressHome()
        ownerPictures.add("red.png", RED)

        screensaver.goIdle()

        val seen = tv.waitForArtwork(mapOf("red at half brightness" to HALF_RED, "red at full brightness" to RED))
        assertEquals("red at half brightness", seen)
    }

    @Test
    fun idleScreenCrossFadesToTheNextPictureAfterAMinute() {
        tv.pressHome()
        ownerPictures.add("a-red.png", RED)
        ownerPictures.add("b-green.png", GREEN)
        val colours = mapOf("red" to HALF_RED, "green" to HALF_GREEN)
        screensaver.goIdle()
        val first = checkNotNull(tv.waitForArtwork(colours)) { "The Idle Screen shows none of the owner's pictures" }

        clock.advance(59_000)
        SystemClock.sleep(2_000)
        assertEquals("The picture changed before a minute was up", first, tv.waitForArtwork(colours))

        clock.advance(1_000)
        val next = colours.keys.single { it != first }
        assertEquals("The picture did not change after a minute", next, tv.waitForArtwork(mapOf(next to colours.getValue(next))))
    }

    private companion object {
        const val RED = 0xD03020
        const val HALF_RED = 0x681810
        const val GREEN = 0x30B040
        const val HALF_GREEN = 0x185820
    }
}
