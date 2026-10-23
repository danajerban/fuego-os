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

    /** Moves focus right along the Dock until the tile labelled [label] has it. */
    fun focusTile(label: String) {
        repeat(DockApp.entries.size + 2) {
            if (focusedTile() == label) return
            pressRight()
            device.waitForIdle()
        }
        error("Could not move focus to the $label tile; focus is on ${focusedTile()}")
    }

    fun idle() = device.waitForIdle()
}
