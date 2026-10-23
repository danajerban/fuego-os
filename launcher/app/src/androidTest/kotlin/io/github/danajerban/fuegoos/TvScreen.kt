package io.github.danajerban.fuegoos

import org.junit.rules.ExternalResource

/**
 * The emulator's screen set to the TV's: 1280x720 at density 213, about 960 by 540 dp, as `wm` reads on
 * the TV. Puts the emulator's own size and density back afterwards.
 */
class TvScreen : ExternalResource() {
    override fun before() {
        Shell.run("wm size 1280x720")
        Shell.run("wm density 213")
    }

    override fun after() {
        Shell.run("wm size reset")
        Shell.run("wm density reset")
    }
}
