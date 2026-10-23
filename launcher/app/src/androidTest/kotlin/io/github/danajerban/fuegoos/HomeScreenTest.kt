package io.github.danajerban.fuegoos

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class HomeScreenTest {
    @get:Rule
    val homeTakeover = HomeTakeover()

    @get:Rule
    val dockApps = DockApps()

    private val tv = Tv()

    @Test
    fun homeOpensTheLauncher() {
        tv.pressHome()

        assertTrue("Home opened ${tv.foregroundPackage}, not the Launcher", tv.waitForApp(LAUNCHER))
        assertNotNull("The Dock is not on screen", tv.dock())
    }

    @Test
    fun dockShowsItsTilesInFixedOrder() {
        dockApps.installOnly(DockApp.NETFLIX, DockApp.YOUTUBE, DockApp.STREMIO, DockApp.SPOTIFY)

        tv.pressHome()

        assertEquals(listOf("Netflix", "YouTube", "Stremio", "Spotify", "Settings"), tv.dockLabels())
    }

    @Test
    fun tilesOfMissingAppsAreHidden() {
        dockApps.installOnly(DockApp.NETFLIX, DockApp.SPOTIFY)

        tv.pressHome()

        assertEquals(listOf("Netflix", "Spotify", "Settings"), tv.dockLabels())
    }

    @Test
    fun backOnHomeDoesNothing() {
        dockApps.installOnly(DockApp.NETFLIX, DockApp.SPOTIFY)
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Spotify")

        tv.pressBack()

        assertTrue("Back changed the screen; focus is on ${tv.focusedTile()}", tv.tileKeepsFocus("Spotify"))
        assertEquals(LAUNCHER, tv.foregroundPackage)
    }
}
