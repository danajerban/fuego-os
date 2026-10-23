package io.github.danajerban.fuegoos

import android.graphics.Bitmap
import android.os.SystemClock
import org.junit.rules.ExternalResource
import java.io.ByteArrayOutputStream

/**
 * The owner's pictures in the Launcher's artwork folder, copied there over adb the way the script does.
 * The folder is emptied before and after each test.
 *
 * The Launcher makes the folder itself the first time Home shows. A folder made over adb belongs to the
 * shell user and the Launcher can't read it, so pictures can only be added once Home has been shown.
 */
class OwnerPictures : ExternalResource() {
    override fun before() = clear()

    override fun after() = clear()

    /** Adds a picture of one solid [colour] (0xRRGGBB), as PNG or JPEG by its [name]'s extension. */
    fun add(name: String, colour: Int) {
        val picture = Bitmap.createBitmap(64, 36, Bitmap.Config.ARGB_8888)
            .apply { eraseColor(colour or 0xFF000000.toInt()) }
        val format = if (name.endsWith(".png", ignoreCase = true)) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG
        val bytes = ByteArrayOutputStream().also { picture.compress(format, 95, it) }.toByteArray()
        addFile(name, bytes)
    }

    fun addFile(name: String, bytes: ByteArray) {
        waitForFolder()
        Shell.run("tee $FOLDER/$name", bytes.inputStream())
        // readable by all, as `adb push` leaves it: the file belongs to the shell user, not the Launcher
        Shell.run("chmod 644 $FOLDER/$name")
    }

    private fun waitForFolder() {
        val end = SystemClock.uptimeMillis() + 5_000
        while (Shell.run("ls -d $FOLDER").trim() != FOLDER) {
            check(SystemClock.uptimeMillis() < end) { "The Launcher has not made its artwork folder; show Home first" }
            SystemClock.sleep(100)
        }
    }

    private fun clear() {
        Shell.run("find $FOLDER -mindepth 1 -delete")
    }

    private companion object {
        const val FOLDER = "/sdcard/Android/data/$LAUNCHER/files/artwork"
    }
}
