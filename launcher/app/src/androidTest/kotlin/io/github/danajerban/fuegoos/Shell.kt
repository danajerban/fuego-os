package io.github.danajerban.fuegoos

import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry
import java.io.InputStream

/** Runs commands as the adb shell user, the way the owner's Mac script talks to the TV. */
object Shell {
    private val automation get() = InstrumentationRegistry.getInstrumentation().uiAutomation

    fun run(command: String): String =
        ParcelFileDescriptor.AutoCloseInputStream(automation.executeShellCommand(command))
            .use { it.readBytes().decodeToString() }

    /** Runs [command] with [input] as its standard input. */
    fun run(command: String, input: InputStream): String {
        val (stdout, stdin) = automation.executeShellCommandRw(command)
        ParcelFileDescriptor.AutoCloseOutputStream(stdin).use { input.copyTo(it) }
        return ParcelFileDescriptor.AutoCloseInputStream(stdout).use { it.readBytes().decodeToString() }
    }
}
