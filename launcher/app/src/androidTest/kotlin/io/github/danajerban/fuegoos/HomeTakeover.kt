package io.github.danajerban.fuegoos

import org.junit.rules.ExternalResource

/**
 * The Home Takeover on the emulator: makes the Launcher the Home app and disables the emulator's stock
 * launcher, which otherwise keeps answering Home through its higher intent-filter priority (as the
 * Stock Launcher does on the TV). Hands Home back afterwards.
 */
class HomeTakeover : ExternalResource() {
    override fun before() {
        Shell.run("cmd role add-role-holder --user 0 android.app.role.HOME $LAUNCHER")
        Shell.run("pm disable-user --user 0 $STOCK_LAUNCHER")
    }

    override fun after() {
        Shell.run("pm enable --user 0 $STOCK_LAUNCHER")
        Shell.run("cmd role add-role-holder --user 0 android.app.role.HOME $STOCK_LAUNCHER")
    }

    private companion object {
        const val STOCK_LAUNCHER = "com.google.android.tvlauncher"
    }
}
