package io.github.danajerban.fuegoos

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

@RunWith(AndroidJUnit4::class)
class DockFocusTest {
    @get:Rule
    val homeTakeover = HomeTakeover()

    @get:Rule
    val dockApps = DockApps()

    @get:Rule
    val tvScreen = TvScreen()

    private val tv = Tv()

    @Test
    fun allSixTilesFitOnTheTvsScreen() {
        dockApps.installOnly(*DockApp.entries.toTypedArray())
        tv.pressHome()
        tv.waitForApp(LAUNCHER)

        val labels = tv.dockLabels()
        assertEquals(listOf("Netflix", "YouTube", "Stremio", "Spotify", "Inputs", "Settings"), labels)
        // A margin of 1/40 of the screen: 24 dp on the TV.
        val screenWidth = tv.screenWidth()
        val margin = screenWidth / 40
        val band = tv.dockBand()
        assertTrue("The Dock's band $band runs off the $screenWidth px screen", band.left >= margin && band.right <= screenWidth - margin)
        val restingWidth = tv.tileBounds("YouTube").width()
        labels.forEach { label ->
            val tile = tv.tileBounds(label)
            assertTrue("The $label tile $tile is cut off: a resting tile is $restingWidth px wide", tile.width() >= restingWidth - 2)
            assertTrue("The $label tile $tile is not inside the band $band", band.contains(tile))
        }
    }

    @Test
    fun focusMovesBetweenTilesWithScaleUpAndGlassHighlight() {
        dockApps.installOnly(DockApp.NETFLIX, DockApp.SPOTIFY)
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Netflix")
        tv.waitForFocusToSettle()
        val restingWidth = tv.tileBounds("Settings").width()

        tv.pressRight()
        tv.waitForFocusToSettle()

        assertEquals("Spotify", tv.focusedTile())
        val spotify = tv.tileBounds("Spotify")
        assertTrue(
            "The focused tile is ${spotify.width()} px wide, not scaled up from $restingWidth px",
            spotify.width() >= restingWidth * 1.05,
        )
        assertEquals("Netflix did not scale back down", restingWidth.toFloat(), tv.tileBounds("Netflix").width().toFloat(), 2f)
        val glass = tv.focusGlass()
        assertTrue("The glass highlight $glass does not cover the focused tile $spotify", glass.contains(spotify))
        assertTrue(
            "The glass highlight $glass is not centred on the focused tile $spotify",
            abs(glass.centerX() - spotify.centerX()) <= 2 && abs(glass.centerY() - spotify.centerY()) <= 2,
        )
    }
}
