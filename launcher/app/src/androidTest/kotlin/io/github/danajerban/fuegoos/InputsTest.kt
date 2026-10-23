package io.github.danajerban.fuegoos

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InputsTest {
    @get:Rule
    val homeTakeover = HomeTakeover()

    @get:Rule
    val tvInputs = FakeTvInputs()

    private val tv = Tv()

    @Test
    fun inputsTileOpensTheInputsList() {
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Inputs")

        tv.pressCenter()

        assertNotNull("The Inputs tile did not open the inputs list", tv.inputsScreen())
    }

    @Test
    fun withNoInputsTheListSaysSo() {
        openInputs()

        assertEquals(emptyList<String>(), tv.inputNames())
        assertEquals("No HDMI inputs found", tv.inputsMessage())
    }

    @Test
    fun listsTheHdmiPortsByName() {
        tvInputs.connect()

        openInputs()

        // Not the tuner, and not the device behind HDMI 1: only the ports the owner plugs into.
        assertEquals(listOf("HDMI 1", "HDMI 2"), tv.inputNames())
        assertEquals(null, tv.inputsMessage())
    }

    @Test
    fun inputsThatComeUpLaterAreListed() {
        openInputs()

        // A TV's HDMI inputs can register after Home is up, for example right after boot.
        tvInputs.connect()

        assertTrue("HDMI 2 never showed up; the list has ${tv.inputNames()}", tv.waitForText("HDMI 2"))
        assertEquals(listOf("HDMI 1", "HDMI 2"), tv.inputNames())
        assertEquals(null, tv.inputsMessage())
    }

    @Test
    fun choosingAnInputOpensItInTheTvInputPlayer() {
        tvInputs.installInputPlayer()
        tvInputs.connect()
        openInputs()
        tv.focusInput("HDMI 2")

        tv.pressCenter()

        assertTrue("Choosing HDMI 2 opened ${tv.foregroundPackage}", tv.waitForApp(FakeTvInputs.INPUT_PLAYER))
        assertTrue("The TV input player did not get HDMI 2", tv.waitForText("Playing ${FakeTvInputs.HDMI_2}"))
    }

    @Test
    fun withNothingToPlayInputsChoosingOneKeepsTheList() {
        tvInputs.connect()
        openInputs()
        tv.focusInput("HDMI 2")

        tv.pressCenter()

        assertTrue("Choosing HDMI 2 left the list for ${tv.foregroundPackage}", tv.inputsStays())
    }

    @Test
    fun showsTheNamesTheOwnerGaveInputs() {
        tvInputs.connect()
        tvInputs.name(FakeTvInputs.HDMI_2, "Set-top box")

        openInputs()

        assertEquals(listOf("HDMI 1", "Set-top box"), tv.inputNames())
    }

    @Test
    fun leavesOutInputsTheOwnerHid() {
        tvInputs.connect()
        tvInputs.hide(FakeTvInputs.HDMI_1)

        openInputs()

        assertEquals(listOf("HDMI 2"), tv.inputNames())
    }

    private fun openInputs() {
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Inputs")
        tv.pressCenter()
        requireNotNull(tv.inputsScreen()) { "The Inputs tile did not open the inputs list" }
    }
}
