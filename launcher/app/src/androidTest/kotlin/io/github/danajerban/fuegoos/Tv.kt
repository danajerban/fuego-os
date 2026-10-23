package io.github.danajerban.fuegoos

import android.graphics.Bitmap
import android.graphics.Rect
import android.os.SystemClock
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import kotlin.math.abs

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

    /** Where the tile labelled [label] is drawn on screen, scale included. */
    fun tileBounds(label: String): Rect =
        requireNotNull(dock()?.findObject(By.text(label))) { "No $label tile on screen" }.visibleBounds

    /** Where the glass focus highlight is drawn on screen, scale included. */
    fun focusGlass(): Rect =
        requireNotNull(device.findObject(By.res(LAUNCHER, "focus_glass"))) { "No glass highlight on screen" }
            .visibleBounds

    /** The colour on screen in the artwork above the Dock, as 0xRRGGBB. */
    fun artworkColour(): Int {
        val screen = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
            .copy(Bitmap.Config.ARGB_8888, false)
        return screen.getPixel(screen.width / 2, screen.height / 5) and 0xFFFFFF
    }

    /**
     * Waits until the artwork shows one of [colours] (by name), and returns its name, or null when none
     * shows within [timeoutMs].
     */
    fun waitForArtwork(colours: Map<String, Int>, timeoutMs: Long = 5_000): String? {
        val end = SystemClock.uptimeMillis() + timeoutMs
        while (SystemClock.uptimeMillis() < end) {
            val seen = artworkColour()
            colours.entries.firstOrNull { closeColours(it.value, seen) }?.let { return it.key }
            SystemClock.sleep(100)
        }
        return null
    }

    private fun closeColours(a: Int, b: Int) =
        listOf(16, 8, 0).all { shift -> abs((a shr shift and 0xFF) - (b shr shift and 0xFF)) <= 24 }

    /** Waits out a focus move: its animation must finish within 150 ms, so twice that is plenty. */
    fun waitForFocusToSettle() {
        SystemClock.sleep(300)
        device.waitForIdle()
    }
}
