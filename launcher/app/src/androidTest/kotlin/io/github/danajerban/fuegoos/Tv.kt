package io.github.danajerban.fuegoos

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until

const val LAUNCHER = "io.github.danajerban.fuegoos"
const val TV_SETTINGS = "com.android.tv.settings"

/** The TV as the owner meets it: remote key presses in, what the screen shows out. */
class Tv {
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    fun pressHome() = device.pressHome()

    fun pressBack() = device.pressBack()

    fun pressRight() = device.pressDPadRight()

    fun pressCenter() = device.pressDPadCenter()

    /** Waits until an app of [packageName] is in front, and returns whether it came. */
    fun waitForApp(packageName: String, timeoutMs: Long = 10_000): Boolean =
        device.wait(Until.hasObject(By.pkg(packageName).depth(0)), timeoutMs) == true

    val foregroundPackage: String? get() = device.currentPackageName

    /** The Dock, or null when the Launcher's Dock is not on screen. */
    fun dock(timeoutMs: Long = 5_000): UiObject2? =
        device.wait(Until.findObject(By.res(LAUNCHER, "dock")), timeoutMs)

    /** The labels of the Dock's tiles that are on screen, left to right. */
    fun dockLabels(): List<String> =
        requireNotNull(dock()) { "The Dock is not on screen" }
            .children.sortedBy { it.visibleBounds.left }.map { it.text }

    /** The label of the Dock tile that has focus, or null when none has. */
    fun focusedTile(): String? =
        dock()?.children?.firstOrNull { it.isFocused }?.text

    /**
     * Watches the screen for [timeoutMs] and returns whether the tile labelled [label] kept focus all along.
     * Leaving Home, or Home being rebuilt, takes focus off it.
     */
    fun tileKeepsFocus(label: String, timeoutMs: Long = 2_000): Boolean {
        val focusedTile = By.res(LAUNCHER, "dock").hasChild(By.text(label).focused(true))
        return device.wait(Until.gone(focusedTile), timeoutMs) != true
    }

    /** Moves focus right along the Dock until the tile labelled [label] has it. */
    fun focusTile(label: String) {
        repeat(DockApp.entries.size + 2) {
            if (focusedTile() == label) return
            pressRight()
            device.waitForIdle()
        }
        error("Could not move focus to the $label tile; focus is on ${focusedTile()}")
    }

    /** The Launcher's Inputs screen, or null when it is not on screen. */
    fun inputsScreen(timeoutMs: Long = 5_000): UiObject2? =
        device.wait(Until.findObject(By.res(LAUNCHER, "inputs_screen")), timeoutMs)

    /** The rows of the inputs list; an empty list has no size, so it is not on screen at all. */
    private fun inputRows(): List<UiObject2> =
        device.findObject(By.res(LAUNCHER, "inputs"))?.children.orEmpty()

    /** The names the Inputs screen lists, top to bottom. */
    fun inputNames(): List<String> =
        inputRows().sortedBy { it.visibleBounds.top }.map { it.text }

    /** The message the Inputs screen shows in place of inputs, or null when it shows none. */
    fun inputsMessage(): String? =
        device.findObject(By.res(LAUNCHER, "no_inputs"))?.text

    /** The name of the input that has focus on the Inputs screen, or null when none has. */
    fun focusedInput(): String? =
        inputRows().firstOrNull { it.isFocused }?.text

    /** Moves focus down the Inputs screen until the input named [name] has it. */
    fun focusInput(name: String) {
        repeat(inputNames().size) {
            if (focusedInput() == name) return
            device.pressDPadDown()
            device.waitForIdle()
        }
        if (focusedInput() != name) error("Could not move focus to the input $name; focus is on ${focusedInput()}")
    }

    /** Waits until [text] is on screen, and returns whether it came. */
    fun waitForText(text: String, timeoutMs: Long = 10_000): Boolean =
        device.wait(Until.hasObject(By.text(text)), timeoutMs) == true
}
