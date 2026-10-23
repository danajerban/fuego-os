package io.github.danajerban.fuegoos

import android.app.Activity
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView

/** The Inputs screen: the TV's HDMI inputs by name. */
class InputsActivity : Activity() {
    private lateinit var list: ViewGroup
    private lateinit var noInputs: View

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_inputs)
        list = findViewById(R.id.inputs)
        noInputs = findViewById(R.id.no_inputs)
    }

    override fun onStart() {
        super.onStart()
        showInputs()
    }

    private fun showInputs() {
        val inputs = hdmiInputs(this)
        val inflater = LayoutInflater.from(this)
        list.removeAllViews()
        inputs.forEach { input ->
            (inflater.inflate(R.layout.input_row, list, false) as TextView).also {
                it.text = input.name
                list.addView(it)
            }
        }
        noInputs.visibility = if (inputs.isEmpty()) View.VISIBLE else View.GONE
        list.getChildAt(0)?.requestFocus()
    }
}
