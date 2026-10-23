package io.github.danajerban.fuegoos

import android.app.Activity
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import android.window.OnBackInvokedDispatcher

/** The home screen: what Home opens once the Launcher is the TV's Home app. */
class HomeActivity : Activity() {
    private lateinit var tileViews: List<TextView>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_home)
        val dock = findViewById<ViewGroup>(R.id.dock)
        val inflater = LayoutInflater.from(this)
        tileViews = dockTiles.map { tile ->
            (inflater.inflate(R.layout.dock_tile, dock, false) as TextView).also {
                it.setText(tile.label)
                dock.addView(it)
            }
        }
        DockFocus(dock, findViewById(R.id.focus_glass))
        // Back on Home does nothing: there is nowhere further back to go.
        onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) {}
    }

    override fun onResume() {
        super.onResume()
        // Apps can be installed or removed while the Launcher is away, so check on every visit.
        dockTiles.zip(tileViews).forEach { (tile, view) ->
            val intent = tile.intent(this)
            view.visibility = if (intent == null) View.GONE else View.VISIBLE
            view.setOnClickListener { startActivity(intent) }
        }
        if (tileViews.none { it.isFocused }) tileViews.firstOrNull { it.visibility == View.VISIBLE }?.requestFocus()
    }
}
