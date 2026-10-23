package io.github.danajerban.fuegoos

import android.os.SystemClock
import org.junit.rules.ExternalResource

/**
 * The TV's screensaver setting, pointed at the Idle Screen the way the script sets it, and put back
 * afterwards. [goIdle] starts it the way the TV does once nothing has been pressed for a while.
 *
 * `cmd dreams` needs root, which the emulator's user build lacks, so this calls the dream manager's
 * binder as the shell user, who holds WRITE_DREAM_STATE. The codes are the order of the methods in
 * API 34's IDreamManager.aidl: 1 dream(), 2 awaken(), 7 isDreaming().
 */
class Screensaver : ExternalResource() {
    private lateinit var componentsBefore: String
    private lateinit var enabledBefore: String

    override fun before() {
        componentsBefore = setting(COMPONENTS)
        enabledBefore = setting(ENABLED)
        Shell.run("settings put secure $COMPONENTS $IDLE_SCREEN")
        Shell.run("settings put secure $ENABLED 1")
    }

    override fun after() {
        wake()
        restore(COMPONENTS, componentsBefore)
        restore(ENABLED, enabledBefore)
    }

    /** Starts the screensaver, and waits until it is showing. */
    fun goIdle() {
        Shell.run("service call dreams 1")
        check(waitFor(showing = true)) { "The screensaver did not start" }
    }

    /** Whether the screensaver is showing. */
    val isShowing: Boolean
        get() = Shell.run("service call dreams 7").contains("00000000 00000001")

    /** Waits until the screensaver is [showing] or not, and returns whether it got there. */
    fun waitFor(showing: Boolean, timeoutMs: Long = 5_000): Boolean {
        val end = SystemClock.uptimeMillis() + timeoutMs
        while (isShowing != showing) {
            if (SystemClock.uptimeMillis() > end) return false
            SystemClock.sleep(100)
        }
        return true
    }

    private fun wake() {
        if (isShowing) Shell.run("service call dreams 2")
        waitFor(showing = false)
    }

    private fun setting(name: String) = Shell.run("settings get secure $name").trim()

    private fun restore(name: String, value: String) {
        if (value == "null") Shell.run("settings delete secure $name") else Shell.run("settings put secure $name $value")
    }

    private companion object {
        const val COMPONENTS = "screensaver_components"
        const val ENABLED = "screensaver_enabled"

        /** The Idle Screen's component, as the script sets it. */
        const val IDLE_SCREEN = "$LAUNCHER/.IdleScreen"
    }
}
