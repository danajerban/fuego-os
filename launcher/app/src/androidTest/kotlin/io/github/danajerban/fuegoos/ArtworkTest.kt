package io.github.danajerban.fuegoos

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
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
    fun homeShowsTheEmberGradientWhenTheArtworkFolderIsEmpty() {
        dockApps.installOnly(DockApp.NETFLIX)

        repeat(2) { visit ->
            leaveHome()
            tv.pressHome()
            tv.dock()
            val shown = tv.waitForColours(EmberOnScreen.points, EmberOnScreen.colours)
            assertTrue("Visit ${visit + 1} does not show the Ember gradient; seen ${hex(tv.screenColours(EmberOnScreen.points))}", shown)
        }
    }

    @Test
    fun ownerPicturesReplaceTheGradientOnePerHomeVisitInNameOrder() {
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
