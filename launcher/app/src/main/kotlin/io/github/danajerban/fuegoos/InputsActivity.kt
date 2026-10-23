package io.github.danajerban.fuegoos

import android.app.Activity
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager
import android.os.Bundle
import android.os.Handler
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView

/** The Inputs screen: the TV's HDMI inputs by name. Choosing one switches the TV to it. */
class InputsActivity : Activity() {
    private lateinit var list: ViewGroup
    private lateinit var noInputs: View
    private val tvInputManager by lazy { getSystemService(TvInputManager::class.java) }

    /** Inputs can come and go while the screen is open, for example while the TV is still starting up. */
    private val inputChanges = object : TvInputManager.TvInputCallback() {
        override fun onInputAdded(inputId: String) = showInputs()
        override fun onInputRemoved(inputId: String) = showInputs()
        override fun onInputUpdated(inputId: String) = showInputs()
        override fun onTvInputInfoUpdated(inputInfo: TvInputInfo) = showInputs()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_inputs)
        list = findViewById(R.id.inputs)
        noInputs = findViewById(R.id.no_inputs)
    }

    override fun onStart() {
        super.onStart()
        tvInputManager?.registerCallback(inputChanges, Handler(mainLooper))
        showInputs()
    }

    override fun onStop() {
        tvInputManager?.unregisterCallback(inputChanges)
        super.onStop()
    }

    private fun showInputs() {
        val inputs = hdmiInputs(this)
        val inflater = LayoutInflater.from(this)
        list.removeAllViews()
        inputs.forEach { input ->
            (inflater.inflate(R.layout.input_row, list, false) as TextView).also {
                it.text = input.name
                it.setOnClickListener { input.switchTo(this) }
                list.addView(it)
            }
        }
        noInputs.visibility = if (inputs.isEmpty()) View.VISIBLE else View.GONE
        list.getChildAt(0)?.requestFocus()
    }
}
