# The Home Takeover disables the Stock Launcher and the setup wizard

To make the Launcher what Home opens, the script sets it as the Home activity and then disables both Takeover Packages (`launcherx` and `setupwraith`). Setting the Home activity alone prints `Success` and changes nothing while `launcherx` is enabled, and `setupwraith` also answers Home and re-enables `launcherx` ([android-tv-launchers.md](../research/android-tv-launchers.md) §2).

## Considered options

- **Keep both packages enabled and redirect Home with an accessibility service** (tv-detox #66, Projectivy's "Override"): nothing is disabled, but the Stock Launcher keeps running and briefly shows on Home. The spec leaves this as follow-up work, only if the Check Step shows casting or the remote's shortcut buttons broken.

## Consequences

Disabling `setupwraith` breaks casting on Google's own hardware and can delete a Wi-Fi network saved during setup ([android-tv-launchers.md](../research/android-tv-launchers.md) §2). So the script installs the Launcher first, makes the takeover a separate step, asks for the owner's yes to a Wi-Fi warning (on a no, Home goes back to the app that held it before), checks which app has focus after a Home press and rolls back if it isn't the Launcher, then runs the Check Step and offers the Casting Fallback.
