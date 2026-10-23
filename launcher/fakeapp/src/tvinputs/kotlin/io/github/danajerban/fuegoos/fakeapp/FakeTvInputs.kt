package io.github.danajerban.fuegoos.fakeapp

import android.app.Activity
import android.content.ComponentName
import android.content.pm.ResolveInfo
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager
import android.media.tv.TvInputService
import android.os.Bundle
import android.os.Parcel
import android.os.Parcelable
import android.text.TextUtils

/** A fake TV input. It never plays anything: the Launcher only lists inputs and hands them to the input player. */
abstract class FakeTvInputService : TvInputService() {
    override fun onCreateSession(inputId: String): Session? = null
}

class Hdmi1Input : FakeTvInputService()

class Hdmi2Input : FakeTvInputService()

class CecDeviceInput : FakeTvInputService()

class TunerInput : FakeTvInputService()

/**
 * Makes the fake inputs look like a TV's own: HDMI 1 and HDMI 2 become HDMI ports, and the CEC device
 * an HDMI device behind HDMI 1. The tuner stays a tuner.
 *
 * Android lists every app's TV input as a tuner; only the TV's system can add HDMI inputs. But an
 * app may update the info of its own inputs, so this builds HDMI input info and hands it over.
 */
class ConnectInputsActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val tvInputManager = getSystemService(TvInputManager::class.java)
        val hdmi1 = hdmiInput(Hdmi1Input::class.java, R.string.fake_hdmi_1, parentId = null)
        tvInputManager.updateTvInputInfo(hdmi1)
        tvInputManager.updateTvInputInfo(hdmiInput(Hdmi2Input::class.java, R.string.fake_hdmi_2, parentId = null))
        tvInputManager.updateTvInputInfo(hdmiInput(CecDeviceInput::class.java, R.string.fake_cec_device, hdmi1.id))
        finish()
    }

    /**
     * The info of an HDMI input served by [service], with its label as a string resource of this app, the
     * way a TV's own HDMI inputs carry theirs. TvInputInfo has no public way to set the type, so this
     * writes the parcel the framework reads it from, in Android 14's field order (TvInputInfo.writeToParcel).
     */
    private fun hdmiInput(service: Class<out TvInputService>, label: Int, parentId: String?): TvInputInfo {
        val tuner = TvInputInfo.Builder(this, ComponentName(this, service)).build()
        val parcel = Parcel.obtain()
        try {
            tuner.writeToParcel(parcel, 0)
            parcel.setDataPosition(0)
            val resolveInfo = ResolveInfo.CREATOR.createFromParcel(parcel)

            parcel.setDataPosition(0)
            parcel.setDataSize(0)
            resolveInfo.writeToParcel(parcel, 0)
            parcel.writeString(tuner.id)
            parcel.writeInt(TvInputInfo.TYPE_HDMI)
            parcel.writeByte(1) // isHardwareInput
            TextUtils.writeToParcel(null, parcel, 0) // label
            parcel.writeParcelable(null as Parcelable?, 0) // iconUri
            parcel.writeInt(label)
            repeat(3) { parcel.writeParcelable(null as Parcelable?, 0) } // icon, iconStandby, iconDisconnected
            parcel.writeString(null) // setupActivity
            parcel.writeByte(0) // canRecord
            parcel.writeByte(0) // canPauseRecording
            parcel.writeInt(0) // tunerCount
            parcel.writeParcelable(null as Parcelable?, 0) // hdmiDeviceInfo
            parcel.writeByte(0) // isConnectedToHdmiSwitch
            parcel.writeInt(0) // hdmiConnectionRelativePosition
            parcel.writeString(parentId)
            parcel.writeBundle(null) // extras

            parcel.setDataPosition(0)
            return TvInputInfo.CREATOR.createFromParcel(parcel)
        } finally {
            parcel.recycle()
        }
    }
}
