package io.github.danajerban.fuegoos

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
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
