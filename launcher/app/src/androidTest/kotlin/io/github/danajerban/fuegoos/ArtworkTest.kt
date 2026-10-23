package io.github.danajerban.fuegoos

import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ArtworkTest {
    @get:Rule
    val homeTakeover = HomeTakeover()

    @get:Rule
    val dockApps = DockApps()

    @get:Rule
    val ownerPictures = OwnerPictures()

    private val tv = Tv()

    @Test
    fun homeShowsBundledArtworkThatChangesEachVisit() {
        dockApps.installOnly(DockApp.NETFLIX)

        val first = visitHome()
        val second = visitHome()

        assertNotEquals("Home shows no artwork", 0, first and 0xF0F0F0)
        assertNotEquals("The artwork did not change on the next Home visit", first, second)
    }

    @Test
    fun ownerPicturesReplaceTheBundledSetOnePerHomeVisitInNameOrder() {
        dockApps.installOnly(DockApp.NETFLIX)
        tv.pressHome()
        ownerPictures.add("b-green.png", GREEN)
        ownerPictures.add("a-red.jpg", RED)
        ownerPictures.add("c-blue.PNG", BLUE)
        ownerPictures.addFile("notes.txt", "not a picture".toByteArray())
        val colours = mapOf("red" to RED, "green" to GREEN, "blue" to BLUE)

        val seen = (1..4).map {
            leaveHome()
            tv.pressHome()
            checkNotNull(tv.waitForArtwork(colours)) { "Visit $it shows none of the owner's pictures" }
        }

        val nameOrder = listOf("red", "green", "blue")
        val start = nameOrder.indexOf(seen.first())
        assertEquals("Pictures not shown one per visit in name order", (0..3).map { nameOrder[(start + it) % 3] }, seen)
    }

    /** Leaves Home for an app through the Dock, comes back, and returns the artwork's colour once it settles. */
    private fun visitHome(): Int {
        leaveHome()
        tv.pressHome()
        tv.dock()
        SystemClock.sleep(1_000)
        return tv.artworkColour()
    }

    private fun leaveHome() {
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Netflix")
        tv.pressCenter()
        tv.waitForApp(DockApp.NETFLIX.packageName)
    }

    private companion object {
        const val RED = 0xD03020
        const val GREEN = 0x30B040
        const val BLUE = 0x2050D0
    }
}
