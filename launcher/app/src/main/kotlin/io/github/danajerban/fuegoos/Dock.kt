package io.github.danajerban.fuegoos

import android.content.Context
import android.content.Intent
import android.provider.Settings

/** A tile in the Dock: its label, and the intent it opens, or null when the TV can't open it. */
class DockTile(val label: Int, val intent: (Context) -> Intent?)

/** The Dock's tiles, left to right. A tile whose intent is null is hidden. */
val dockTiles = listOf(
    appTile(R.string.tile_netflix, "com.netflix.ninja"),
    appTile(R.string.tile_youtube, "com.google.android.youtube.tv"),
    appTile(R.string.tile_stremio, "com.stremio.one"),
    appTile(R.string.tile_spotify, "com.spotify.tv.android"),
    // The Inputs tile goes here, between Spotify and Settings.
    DockTile(R.string.tile_settings) { context ->
        Intent(Settings.ACTION_SETTINGS).takeIf { it.resolveActivity(context.packageManager) != null }
    },
)

/**
 * A tile that opens the TV app [packageName], or is hidden when it isn't installed.
 * Each package must also be listed under `<queries>` in the manifest, or Android hides it from us.
 */
private fun appTile(label: Int, packageName: String) = DockTile(label) { context ->
    context.packageManager.run {
        getLeanbackLaunchIntentForPackage(packageName) ?: getLaunchIntentForPackage(packageName)
    }
}
