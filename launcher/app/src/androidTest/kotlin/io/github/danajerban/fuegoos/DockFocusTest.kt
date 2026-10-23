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

    private val tv = Tv()

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
