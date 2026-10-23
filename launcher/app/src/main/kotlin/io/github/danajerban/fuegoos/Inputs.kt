package io.github.danajerban.fuegoos

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.tv.TvContract
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager

/** The TV input player: Google TV's app that shows an HDMI input full screen, without the Stock Launcher. */
private const val TV_INPUT_PLAYER = "com.google.android.tv.inputplayer"

/** An HDMI input of the TV: the name the owner knows it by, and its TV input ID. */
class HdmiInput(val name: CharSequence, val id: String) {
    /**
     * Switches the TV to this input through the TV input player. Without the player, any app that plays
     * passthrough inputs will do; with none at all, nothing happens.
     */
    fun switchTo(context: Context) {
        val play = Intent(Intent.ACTION_VIEW, TvContract.buildChannelUriForPassthroughInput(id))
        for (intent in listOf(Intent(play).setPackage(TV_INPUT_PLAYER), play)) {
            try {
                context.startActivity(intent)
                return
            } catch (e: ActivityNotFoundException) {
                continue
            }
        }
    }
}

/**
 * The TV's HDMI ports, as the TV input framework lists them now, in input ID order (port order on TVs
 * that number their inputs). Devices behind a port (HDMI-CEC adds one per device) are left out: the
 * owner picks the port. Names and hidden inputs follow what the owner set in TV Settings > Inputs.
 */
fun hdmiInputs(context: Context): List<HdmiInput> =
    context.getSystemService(TvInputManager::class.java)?.tvInputList.orEmpty()
        .filter { it.type == TvInputInfo.TYPE_HDMI && it.parentId == null && !it.isHidden(context) }
        .sortedBy { it.id }
        .map { HdmiInput(it.loadCustomLabel(context) ?: it.loadLabel(context), it.id) }
