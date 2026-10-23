package io.github.danajerban.fuegoos

import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager
import android.os.SystemClock
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.rules.ExternalResource

/**
 * The TV's inputs on the emulator, which has none of its own. Its [connect] installs the fake TV
 * inputs (the fakeapp `tvinputs` flavour): two HDMI ports, a device behind HDMI 1 (as HDMI-CEC
 * adds) and a tuner. Afterwards the fake inputs are removed and the TV's input settings put back.
 */
class FakeTvInputs : ExternalResource() {
    private val tvInputManager = InstrumentationRegistry.getInstrumentation().targetContext
        .getSystemService(TvInputManager::class.java)
    private lateinit var settingsBefore: Map<String, String>

    override fun before() {
        uninstallPackage(PACKAGE)
        settingsBefore = SETTINGS.associateWith { Shell.run("settings get secure $it").trim() }
        SETTINGS.forEach { Shell.run("settings delete secure $it") }
    }

    override fun after() {
        uninstallPackage(PACKAGE)
        settingsBefore.forEach { (key, value) ->
            if (value == "null") Shell.run("settings delete secure $key") else Shell.run("settings put secure $key $value")
        }
    }

    /** Plugs in the fake inputs, and waits until the TV lists the HDMI ports. */
    fun connect() {
        installFakeApk("fakeapp-tvinputs-release.apk", PACKAGE)
        // Android lists an app's own TV inputs as tuners; this activity makes them HDMI inputs.
        waitUntil("the fake inputs are listed") { HDMI_1 in inputTypes() }
        Shell.run("am start -W -n $PACKAGE/io.github.danajerban.fuegoos.fakeapp.ConnectInputsActivity")
        waitUntil("the fake HDMI ports are listed") {
            inputTypes().let { it[HDMI_1] == TvInputInfo.TYPE_HDMI && it[HDMI_2] == TvInputInfo.TYPE_HDMI }
        }
    }

    private fun inputTypes(): Map<String, Int> =
        tvInputManager.tvInputList.associate { it.id to it.type }

    private fun waitUntil(what: String, condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 10_000
        while (!condition()) {
            check(SystemClock.uptimeMillis() < deadline) { "Timed out waiting until $what" }
            SystemClock.sleep(200)
        }
    }

    companion object {
        const val PACKAGE = "io.github.danajerban.fuegoos.faketvinputs"
        const val HDMI_1 = "$PACKAGE/io.github.danajerban.fuegoos.fakeapp.Hdmi1Input"
        const val HDMI_2 = "$PACKAGE/io.github.danajerban.fuegoos.fakeapp.Hdmi2Input"

        /** Where TV Settings keeps the names the owner gave inputs, and the inputs the owner hid. */
        private val SETTINGS = listOf("tv_input_custom_labels", "tv_input_hidden_inputs")
    }
}
