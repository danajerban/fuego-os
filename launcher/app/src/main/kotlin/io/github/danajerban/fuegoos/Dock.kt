package io.github.danajerban.fuegoos

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.drawable.BitmapDrawable
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

/**
 * [icon] drawn once at [size] pixels square and clipped to a rounded square, antialiased, so the apps'
 * icons look alike in the Dock whatever shape they come in (a hard square PNG, an adaptive icon).
 * Off the main thread, like [appIcon].
 */
fun roundedIcon(resources: Resources, icon: Drawable, size: Int): Drawable {
    val drawn = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    icon.setBounds(0, 0, size, size)
    icon.draw(Canvas(drawn))
    val rounded = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = BitmapShader(drawn, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP) }
    val radius = size * ICON_CORNER
    Canvas(rounded).drawRoundRect(0f, 0f, size.toFloat(), size.toFloat(), radius, radius, paint)
    drawn.recycle()
    return BitmapDrawable(resources, rounded)
}

/** An app icon's corner radius, as a fraction of its size. */
private const val ICON_CORNER = 0.22f
