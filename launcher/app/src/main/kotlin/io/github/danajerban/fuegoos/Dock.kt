package io.github.danajerban.fuegoos

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.provider.Settings

/**
 * A tile in the Dock: its label, its icon, and the intent it opens, or null when the TV can't open it.
 * The icon is either one of ours ([ownIcon], a drawable) or the icon of the app [packageName].
 */
class DockTile(
    val label: Int,
    val ownIcon: Int? = null,
    val packageName: String? = null,
    val intent: (Context) -> Intent?,
)

/** The Dock's tiles, left to right. A tile whose intent is null is hidden. */
val dockTiles = listOf(
    appTile(R.string.tile_netflix, "com.netflix.ninja"),
    appTile(R.string.tile_youtube, "com.google.android.youtube.tv"),
    appTile(R.string.tile_stremio, "com.stremio.one"),
    appTile(R.string.tile_spotify, "com.spotify.tv.android"),
    DockTile(R.string.tile_inputs, ownIcon = R.drawable.tile_icon_inputs) { context ->
        Intent(context, InputsActivity::class.java)
    },
    DockTile(R.string.tile_settings, ownIcon = R.drawable.tile_icon_settings) { context ->
        Intent(Settings.ACTION_SETTINGS).takeIf { it.resolveActivity(context.packageManager) != null }
    },
)

/**
 * A tile that opens the TV app [packageName], or is hidden when it isn't installed.
 * Each package must also be listed under `<queries>` in the manifest, or Android hides it from us.
 */
private fun appTile(label: Int, packageName: String) = DockTile(label, packageName = packageName) { context ->
    context.packageManager.run {
        getLeanbackLaunchIntentForPackage(packageName) ?: getLaunchIntentForPackage(packageName)
    }
}

/**
 * The launcher icon of the installed app [packageName], or null when it isn't installed or has none. An
 * app with only a TV banner has no icon: a banner is a wide logo that turns to a smudge at icon size, and
 * Android's stand-in icon would look broken, so such a tile shows its label alone.
 *
 * Decoding an icon can take tens of milliseconds on the TV: call it off the main thread.
 */
fun appIcon(packageManager: PackageManager, packageName: String): Drawable? {
    val app = try {
        packageManager.getApplicationInfo(packageName, 0)
    } catch (e: PackageManager.NameNotFoundException) {
        return null
    }
    return if (app.icon == 0) null else app.loadIcon(packageManager)
}
