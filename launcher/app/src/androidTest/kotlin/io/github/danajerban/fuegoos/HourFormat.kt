package io.github.danajerban.fuegoos

import org.junit.rules.ExternalResource

/** The TV's 12/24-hour setting, set by a test and put back afterwards. */
class HourFormat : ExternalResource() {
    private lateinit var before: String

    override fun before() {
        before = Shell.run("settings get system $SETTING").trim()
    }

    override fun after() {
        if (before == "null") Shell.run("settings delete system $SETTING") else Shell.run("settings put system $SETTING $before")
    }

    /** Sets the TV to show the time in 24 hours, or in 12 when [hours] is 12. */
    fun use(hours: Int) {
        Shell.run("settings put system $SETTING $hours")
    }

    private companion object {
        const val SETTING = "time_12_24"
    }
}
