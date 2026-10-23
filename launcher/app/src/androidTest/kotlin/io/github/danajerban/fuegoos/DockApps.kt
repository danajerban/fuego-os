package io.github.danajerban.fuegoos

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.rules.ExternalResource

/**
 * A Dock app as the TV knows it: its package, the fake APK that stands in for it on the emulator, and the
 * colour (0xRRGGBB) of that fake's icon, a plain square (see the fakeapp module's build file).
 */
enum class DockApp(val packageName: String, val fakeApk: String, val fakeIconColour: Int) {
    NETFLIX("com.netflix.ninja", "fakeapp-netflix-release.apk", 0xE50914),
    YOUTUBE("com.google.android.youtube.tv", "fakeapp-youtube-release.apk", 0xFF0033),
    STREMIO("com.stremio.one", "fakeapp-stremio-release.apk", 0x7B5BF5),
    SPOTIFY("com.spotify.tv.android", "fakeapp-spotify-release.apk", 0x1DB954),
}

/**
 * Sets which Dock apps are installed on the emulator for a test, and puts the emulator back afterwards.
 *
 * An app the emulator ships (YouTube on the Android TV image) is hidden with `pm uninstall --user 0` and
 * brought back with `install-existing`. Any other app is installed from its fake APK.
 */
class DockApps : ExternalResource() {
    private lateinit var installedBefore: Set<DockApp>

    override fun before() {
        installedBefore = DockApp.entries.filter { isInstalled(it) }.toSet()
    }

    override fun after() {
        DockApp.entries.forEach { app ->
            if (app in installedBefore) install(app) else uninstall(app)
        }
    }

    /** Makes exactly [apps] installed and every other Dock app missing. */
    fun installOnly(vararg apps: DockApp) {
        DockApp.entries.forEach { app ->
            if (app in apps) install(app) else uninstall(app)
        }
    }

    fun install(app: DockApp) {
        if (isInstalled(app)) return
        Shell.run("cmd package install-existing --user 0 ${app.packageName}")
        if (isInstalled(app)) return
        installFakeApk(app.fakeApk, app.packageName)
    }

    fun uninstall(app: DockApp) = uninstallPackage(app.packageName)

    private fun isInstalled(app: DockApp): Boolean = isPackageInstalled(app.packageName)
}

/** Installs [packageName] from [fakeApk], one of the fake APKs the UI tests carry as assets. */
fun installFakeApk(fakeApk: String, packageName: String) {
    val apk = InstrumentationRegistry.getInstrumentation().context.assets
        .open(fakeApk).use { it.readBytes() }
    val output = Shell.run("pm install --user 0 -S ${apk.size}", apk.inputStream())
    check(isPackageInstalled(packageName)) { "Could not install $fakeApk: $output" }
}

fun uninstallPackage(packageName: String) {
    if (!isPackageInstalled(packageName)) return
    val output = Shell.run("pm uninstall --user 0 $packageName")
    check(!isPackageInstalled(packageName)) { "Could not uninstall $packageName: $output" }
}

fun isPackageInstalled(packageName: String): Boolean =
    Shell.run("pm list packages --user 0 $packageName").lines()
        .any { it.trim() == "package:$packageName" }
