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

    private fun openInputs() {
        tv.pressHome()
        tv.waitForApp(LAUNCHER)
        tv.focusTile("Inputs")
        tv.pressCenter()
        requireNotNull(tv.inputsScreen()) { "The Inputs tile did not open the inputs list" }
    }
}
