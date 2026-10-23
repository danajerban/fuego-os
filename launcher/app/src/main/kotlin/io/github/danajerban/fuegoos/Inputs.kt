package io.github.danajerban.fuegoos

import android.content.Context
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager

/** An HDMI input of the TV: the name the owner knows it by, and its TV input ID. */
class HdmiInput(val name: CharSequence, val id: String)

/**
 * The TV's HDMI ports, as the TV input framework lists them now, in input ID order (port order on TVs
 * that number their inputs). Devices behind a port (HDMI-CEC adds one per device) are left out: the
 * owner picks the port.
 */
fun hdmiInputs(context: Context): List<HdmiInput> =
    context.getSystemService(TvInputManager::class.java)?.tvInputList.orEmpty()
        .filter { it.type == TvInputInfo.TYPE_HDMI && it.parentId == null }
        .sortedBy { it.id }
        .map { HdmiInput(it.loadLabel(context), it.id) }
