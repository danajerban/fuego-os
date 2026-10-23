package io.github.danajerban.fuegoos

import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** The home screen: what Home opens once the Launcher is the TV's Home app. */
class HomeActivity : Activity() {
    private lateinit var tileViews: List<TextView>
    private lateinit var artwork: HomeArtwork
    private lateinit var iconLoader: ExecutorService
    private lateinit var clockView: ClockView

    /** For each Dock app, the install time of the version whose icon its tile shows. Touched only by [iconLoader]. */
    private val iconVersions = HashMap<String, Long>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_home)
        val dock = findViewById<ViewGroup>(R.id.dock)
        val inflater = LayoutInflater.from(this)
        tileViews = dockTiles.map { tile ->
            (inflater.inflate(R.layout.dock_tile, dock, false) as TextView).also {
                it.setText(tile.label)
                // Ours are small vectors, cheap to draw now. An app's icon comes later (see loadAppIcons):
                // until then a clear stand-in keeps its label where it will be.
                showIcon(it, tile.ownIcon?.let { icon -> getDrawable(icon) } ?: ColorDrawable(Color.TRANSPARENT))
                dock.addView(it)
            }
        }
        iconLoader = Executors.newSingleThreadExecutor()
        clockView = findViewById(R.id.clock)
        DockFocus(dock, findViewById(R.id.focus_glass))
        artwork = HomeArtwork(findViewById(R.id.artwork), findViewById(R.id.dock_band))
        // Back on Home does nothing: there is nowhere further back to go.
        onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) {}
    }

    override fun onStart() {
        super.onStart()
        artwork.show()
    }

    override fun onStop() {
        super.onStop()
        artwork.hide()
    }

    override fun onDestroy() {
        iconLoader.shutdownNow()
        super.onDestroy()
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
        loadAppIcons()
        clockView.start()
    }

    override fun onPause() {
        clockView.stop()
        super.onPause()
    }

    /**
     * Loads the Dock apps' icons off the main thread, so Home's first frame never waits for them, and shows
     * each on its tile. An app's icon is loaded again only when the app was installed or updated since.
     */
    private fun loadAppIcons() {
        val packageManager = packageManager
        val iconSize = resources.getDimensionPixelSize(R.dimen.dock_tile_icon)
        val appTiles = dockTiles.zip(tileViews).mapNotNull { (tile, view) -> tile.packageName?.let { it to view } }
        iconLoader.execute {
            appTiles.forEach { (packageName, view) ->
                val version = try {
                    packageManager.getPackageInfo(packageName, 0).lastUpdateTime
                } catch (e: PackageManager.NameNotFoundException) {
                    return@forEach
                }
                if (iconVersions[packageName] == version) return@forEach
                iconVersions[packageName] = version
                val icon = appIcon(packageManager, packageName)?.let { roundedIcon(resources, it, iconSize) }
                view.post { showIcon(view, icon) }
            }
        }
    }

    /** Shows [icon] above [tile]'s label, or the label alone when it is null. */
    private fun showIcon(tile: TextView, icon: Drawable?) {
        val size = resources.getDimensionPixelSize(R.dimen.dock_tile_icon)
        icon?.setBounds(0, 0, size, size)
        tile.setCompoundDrawables(null, icon, null, null)
    }
}
