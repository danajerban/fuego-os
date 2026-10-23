package io.github.danajerban.fuegoos

import android.graphics.Bitmap
import android.graphics.PointF
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

/** [colours] (0xRRGGBB) written out for a test's message. */
fun hex(colours: List<Int>) = colours.joinToString { "%06X".format(it) }

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

    /** Where the Dock's glass band is on screen, as far as it is on screen at all. */
    fun dockBand(): Rect =
        requireNotNull(device.findObject(By.res(LAUNCHER, "dock_band"))) { "No Dock band on screen" }.visibleBounds

    /** The clock's time and date as on screen (Home's or the Idle Screen's), or null when no clock shows. */
    fun clockText(): Pair<String, String>? {
        val time = device.findObject(By.res(LAUNCHER, "clock_time")) ?: return null
        val date = device.findObject(By.res(LAUNCHER, "clock_date")) ?: return null
        return time.text to date.text
    }

    /** Waits until the clock shows [time] and [date], and returns whether it did within [timeoutMs]. */
    fun waitForClock(time: String, date: String, timeoutMs: Long = 5_000): Boolean {
        val end = SystemClock.uptimeMillis() + timeoutMs
        while (SystemClock.uptimeMillis() < end) {
            if (clockText() == time to date) return true
            SystemClock.sleep(100)
        }
        return false
    }

    /** Where the clock's time is on screen. */
    fun clockTimeBounds(): Rect =
        requireNotNull(device.findObject(By.res(LAUNCHER, "clock_time"))) { "No clock on screen" }.visibleBounds

    /** The colours on screen (0xRRGGBB) inside [area], every other pixel each way. */
    fun coloursIn(area: Rect): List<Int> {
        val screen = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
            .copy(Bitmap.Config.ARGB_8888, false)
        return (area.top until area.bottom step 2).flatMap { y ->
            (area.left until area.right step 2).map { x -> screen.getPixel(x, y) and 0xFFFFFF }
        }
    }

    /** The screen's width in pixels. */
    fun screenWidth(): Int = device.displayWidth

    /** Where the glass focus highlight is drawn on screen, scale included. */
    fun focusGlass(): Rect =
        requireNotNull(device.findObject(By.res(LAUNCHER, "focus_glass"))) { "No glass highlight on screen" }
            .visibleBounds

    /** The colour on screen in the artwork above the Dock and the clock, as 0xRRGGBB. */
    fun artworkColour(): Int = screenColours(listOf(PointF(0.5f, 0.08f))).single()

    /** The colours on screen at [points], given as fractions of the screen's width and height, as 0xRRGGBB. */
    fun screenColours(points: List<PointF>): List<Int> {
        val screen = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
            .copy(Bitmap.Config.ARGB_8888, false)
        return points.map { screen.getPixel((it.x * screen.width).toInt(), (it.y * screen.height).toInt()) and 0xFFFFFF }
    }

    /**
     * Waits until the screen shows [colours] (0xRRGGBB) at [points], each within a small tolerance, and
     * returns whether it did within [timeoutMs].
     */
    fun waitForColours(points: List<PointF>, colours: List<Int>, timeoutMs: Long = 5_000): Boolean {
        val end = SystemClock.uptimeMillis() + timeoutMs
        while (SystemClock.uptimeMillis() < end) {
            if (screenColours(points).zip(colours).all { (seen, colour) -> closeColours(seen, colour) }) return true
            SystemClock.sleep(100)
        }
        return false
    }

    /**
     * The colours on screen (0xRRGGBB) in a patch at the middle of where the tile labelled [label] draws its
     * icon: centred across the tile, between a fifth and a third of the way down, above where its label is.
     */
    fun tileIconColours(label: String): List<Int> {
        val tile = tileBounds(label)
        val screen = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
            .copy(Bitmap.Config.ARGB_8888, false)
        val xs = (tile.centerX() - tile.width() / 16)..(tile.centerX() + tile.width() / 16)
        val ys = (tile.top + tile.height() / 5)..(tile.top + tile.height() / 3)
        return ys.flatMap { y -> xs.map { x -> screen.getPixel(x, y) and 0xFFFFFF } }
    }

    /**
     * Waits until the icon patch of the tile labelled [label] (see [tileIconColours]) shows what [shows]
     * looks for, and returns whether it did within [timeoutMs]: icons load after Home's first frame.
     */
    fun waitForTileIcon(label: String, timeoutMs: Long = 5_000, shows: (List<Int>) -> Boolean): Boolean {
        val end = SystemClock.uptimeMillis() + timeoutMs
        while (SystemClock.uptimeMillis() < end) {
            if (shows(tileIconColours(label))) return true
            SystemClock.sleep(100)
        }
        return false
    }

    /**
     * The colours on screen (0xRRGGBB) at the four corners of the box around everything of [colour] on the
     * tile labelled [label]: for a square icon of that colour, the corners of the square.
     */
    fun tileIconCorners(label: String, colour: Int): List<Int> {
        val tile = tileBounds(label)
        val screen = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
            .copy(Bitmap.Config.ARGB_8888, false)
        val box = Rect(Int.MAX_VALUE, Int.MAX_VALUE, Int.MIN_VALUE, Int.MIN_VALUE)
        for (y in tile.top until tile.bottom) for (x in tile.left until tile.right) {
            if (closeColours(screen.getPixel(x, y) and 0xFFFFFF, colour)) {
                box.set(minOf(box.left, x), minOf(box.top, y), maxOf(box.right, x), maxOf(box.bottom, y))
            }
        }
        check(box.left <= box.right) { "No $label icon on screen" }
        return listOf(box.left to box.top, box.right to box.top, box.left to box.bottom, box.right to box.bottom)
            .map { (x, y) -> screen.getPixel(x, y) and 0xFFFFFF }
    }

    /** Whether [a] and [b] (0xRRGGBB) look the same, give or take a little. */
    fun sameColour(a: Int, b: Int) = closeColours(a, b)

    /** Whether most of [patch] is [colour] (0xRRGGBB): a solid icon of that colour fills it. */
    fun mostly(patch: List<Int>, colour: Int) = patch.count { closeColours(it, colour) } * 2 > patch.size

    /** Whether some of [patch] is white: one of the Launcher's white line icons crosses it. */
    fun hasWhiteLines(patch: List<Int>) = patch.count { closeColours(it, 0xFFFFFF) } * 20 > patch.size

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

    /** The Launcher's Inputs screen, or null when it is not on screen. */
    fun inputsScreen(timeoutMs: Long = 5_000): UiObject2? =
        device.wait(Until.findObject(By.res(LAUNCHER, "inputs_screen")), timeoutMs)

    /** Watches the screen for [timeoutMs] and returns whether the Inputs screen stayed on it all along. */
    fun inputsStays(timeoutMs: Long = 2_000): Boolean =
        device.wait(Until.gone(By.res(LAUNCHER, "inputs_screen")), timeoutMs) != true

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
