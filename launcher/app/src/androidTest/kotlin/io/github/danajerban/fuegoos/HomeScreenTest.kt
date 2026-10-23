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

        assertEquals(listOf("Netflix", "YouTube", "Stremio", "Spotify", "Inputs", "Settings"), tv.dockLabels())
    }

    @Test
    fun tilesOfMissingAppsAreHidden() {
        dockApps.installOnly(DockApp.NETFLIX, DockApp.SPOTIFY)

        tv.pressHome()

        assertEquals(listOf("Netflix", "Spotify", "Inputs", "Settings"), tv.dockLabels())
    }

    @Test
    fun appTilesShowTheirAppsOwnIcons() {
        val apps = mapOf("Netflix" to DockApp.NETFLIX, "Stremio" to DockApp.STREMIO, "Spotify" to DockApp.SPOTIFY)
        dockApps.installOnly(*apps.values.toTypedArray())

        tv.pressHome()
        tv.waitForApp(LAUNCHER)

        apps.forEach { (label, app) ->
            val shown = tv.waitForTileIcon(label) { tv.mostly(it, app.fakeIconColour) }
            assertTrue("The $label tile does not show its app's icon; seen ${hex(tv.tileIconColours(label).distinct().take(8))}", shown)
            // The fake's icon is a plain square: rounded, its corners show the tile behind.
            val corners = tv.tileIconCorners(label, app.fakeIconColour)
            assertTrue("The $label icon's corners are not rounded off; seen ${hex(corners)}", corners.none { tv.sameColour(it, app.fakeIconColour) })
        }
    }

    @Test
    fun inputsAndSettingsTilesShowTheLaunchersOwnIcons() {
        dockApps.installOnly(DockApp.NETFLIX)

        tv.pressHome()
        tv.waitForApp(LAUNCHER)

        listOf("Inputs", "Settings").forEach { label ->
            val shown = tv.waitForTileIcon(label) { tv.hasWhiteLines(it) }
            assertTrue("The $label tile shows no white line icon; seen ${hex(tv.tileIconColours(label).distinct().take(8))}", shown)
        }
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

    @Test
    fun settingsTileOpensSettings() {
        dockApps.installOnly(DockApp.NETFLIX)
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Settings")

        tv.pressCenter()

        assertTrue("Settings tile opened ${tv.foregroundPackage}", tv.waitForApp(TV_SETTINGS))
    }

    @Test
    fun appTileOpensItsApp() {
        dockApps.installOnly(DockApp.NETFLIX, DockApp.STREMIO)
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Stremio")

        tv.pressCenter()

        assertTrue("Stremio tile opened ${tv.foregroundPackage}", tv.waitForApp(DockApp.STREMIO.packageName))
    }
}
