package io.github.danajerban.fuegoos

import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class IdleScreenTest {
    @get:Rule
    val homeTakeover = HomeTakeover()

    @get:Rule
    val dockApps = DockApps()

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

    @Test
    fun theFirstKeyPressOnlyWakesTheTv() {
        dockApps.installOnly(DockApp.NETFLIX)
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Netflix")
        screensaver.goIdle()

        tv.pressCenter()

        assertTrue("The key press did not wake the TV", screensaver.waitFor(showing = false))
        assertNotNull("Home is not back on screen", tv.dock())
        assertTrue("The key press did more than wake the TV; focus is on ${tv.focusedTile()}", tv.tileKeepsFocus("Netflix"))
        assertEquals(LAUNCHER, tv.foregroundPackage)
    }

    @Test
    fun aDreamBetweenTwoHomeVisitsDoesNotMoveHomesPicture() {
        dockApps.installOnly(DockApp.NETFLIX)
        tv.pressHome()
        val pictures = listOf("a-red" to RED, "b-green" to GREEN, "c-blue" to BLUE, "d-yellow" to YELLOW, "e-purple" to PURPLE)
        pictures.forEach { (name, colour) -> ownerPictures.add("$name.png", colour) }
        val names = pictures.map { it.first }
        val onHome = pictures.toMap()
        val onIdleScreen = pictures.associate { (name, colour) -> name to halfBrightness(colour) }
        visitHome()
        val before = checkNotNull(tv.waitForArtwork(onHome)) { "Home shows none of the owner's pictures" }

        // The Idle Screen shows two pictures: one when it starts, the next a minute later.
        screensaver.goIdle()
        SystemClock.sleep(2_000) // past the dream's own fade-in and the picture's
        val firstDreamed = checkNotNull(tv.waitForArtwork(onIdleScreen)) { "The Idle Screen shows none of the owner's pictures" }
        clock.advance(60_000)
        checkNotNull(tv.waitForArtwork(onIdleScreen - firstDreamed)) { "The Idle Screen did not move on from $firstDreamed" }
        tv.pressCenter()
        check(screensaver.waitFor(showing = false)) { "The key press did not wake the TV" }

        // Home may show its next picture as it comes back from the dream, or on the next visit.
        val afterWake = checkNotNull(tv.waitForArtwork(onHome)) { "Home shows none of the owner's pictures after the dream" }
        val next = if (afterWake != before) afterWake else {
            visitHome()
            checkNotNull(tv.waitForArtwork(onHome)) { "Home shows none of the owner's pictures" }
        }
        assertEquals("The dream moved Home's picture on", names[(names.indexOf(before) + 1) % names.size], next)
    }

    /** Leaves Home for an app through the Dock, and comes back. */
    private fun visitHome() {
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Netflix")
        tv.pressCenter()
        tv.waitForApp(DockApp.NETFLIX.packageName)
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
    }

    private fun halfBrightness(colour: Int) = (colour shr 1) and 0x7F7F7F

    private companion object {
        const val RED = 0xD03020
        const val HALF_RED = 0x681810
        const val GREEN = 0x30B040
        const val HALF_GREEN = 0x185820
        const val BLUE = 0x2050D0
        const val YELLOW = 0xD0C020
        const val PURPLE = 0x9030C0
    }
}
