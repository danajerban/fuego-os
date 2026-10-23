package io.github.danajerban.fuegoos

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

    private val tv = Tv()

    @Test
    fun idleScreenShowsTheArtworkAtHalfBrightness() {
        tv.pressHome()
        ownerPictures.add("red.png", RED)

        screensaver.goIdle()

        val seen = tv.waitForArtwork(mapOf("red at half brightness" to HALF_RED, "red at full brightness" to RED))
        assertEquals("red at half brightness", seen)
    }

    private companion object {
        const val RED = 0xD03020
        const val HALF_RED = 0x681810
    }
}
