# fuego-os

Makes one Fuego 2K Google TV (Android TV OS 14) fast and free of Bloat, over ADB, without root.

> **Status: pre-release, design stage.** There is no code yet and nothing here has been tried on the TV. The plan is in [the spec](https://github.com/danajerban/fuego-os/issues/1); the words it uses are in [GLOSSARY.md](GLOSSARY.md).

> **Not affiliated with Fuego, Google, Netflix, YouTube, Stremio or Spotify.** Use it at your own risk.

## What it is

Two pieces:

- **A Mac script** that talks to the TV over ADB:
  - `probe`: reads facts from the TV (chip, RAM, storage, Android build, package list with the lists each package is on), flags packages on none of the lists, measures available memory and Home draw time, and changes nothing.
  - `apply`: takes a Snapshot (once, never overwritten), runs Debloat against a reviewed known-Bloat list, installs the Launcher, performs the Home Takeover, applies light speed settings, then checks the result. It has a dry-run flag and is safe to run again.
  - `restore`: puts the TV back to the Snapshot.
- **A Launcher** of our own: Kotlin with plain Android Views. A glass dock (Netflix, YouTube, Stremio, Spotify, Inputs, Settings) over full-screen artwork, in the style of Home+, and an Idle Screen that replaces Google's ambient mode as the TV's screensaver. No internet permission, and nothing runs while it is off screen except that screensaver.

## Why ADB only

There is no public firmware for this TV, and unlocking it would cost Netflix HD and risk bricking it. So fuego-os uses only what ADB allows a normal user: no root, no firmware changes, nothing deleted from the system partition. Everything is reversible.

## What it changes, and what it keeps

**Changes (planned):**
- disables Bloat for the TV's user only (`pm disable-user --user 0`), and only packages on the reviewed known-Bloat list;
- disables the Stock Launcher (`com.google.android.apps.tv.launcherx`) and the setup wizard (`setupwraith`) once the Launcher is Home;
- sets window, transition and animator animation scales to 0.5×;
- turns off Google's ambient mode and sets the Launcher's Idle Screen as the screensaver.

**Keeps:** Netflix, YouTube, Stremio, Spotify, Play Services, the Play Store, the remote service, location, the cast receiver, TV Settings, the TV input player and the system updater are on a must-keep list that always wins. Packages on neither list are reported, never disabled. The background process limit and Play auto-updates are left alone.

**Known risks** reported on other Google TVs, not yet checked on this one: casting breaking when the setup wizard is disabled, saved Wi-Fi being lost, boot loops on some brands, and Wireless debugging turning off after a reboot. The plan for each is in [the spec](https://github.com/danajerban/fuego-os/issues/1).

## Quick start

> **Not yet available.** There is nothing to download or run yet. This section will hold the steps once the first release (`v0.1.0`) is out: turning on Developer options and Wireless debugging, pairing the Mac, then `probe`, `apply` and `restore`.

Releases will carry the Launcher APK and the script bundle.

## How to undo

- `restore` puts back everything the Snapshot recorded, hands Home back to the Stock Launcher and uninstalls the Launcher. It works even if the Launcher was already uninstalled.
- The Snapshot is a text file on the Mac, at `~/Library/Application Support/fuego-os/snapshot` (set `FUEGO_STATE_DIR` to keep it elsewhere). Keep it: it is the way back.
- A factory reset also undoes everything: Debloat applies to the TV's user only, and the Launcher is an ordinary app.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems privately, as [SECURITY.md](SECURITY.md) explains. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Credits

- [CleanYourTV](https://github.com/Gathin23/cleanyourtv) (MIT): the Launcher plans to borrow its blur trick, cached glass, HOME manifest setup and its disable/restore notes, with attribution kept. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- [Home+](https://github.com/pbalazaar/home-plus): the inspiration for the look, and for how this repo is organised.
- [CleanFrame](https://github.com/nthnclrk/CleanFrame): the inspiration for the Snapshot, guarded apply and Restore flow.

## License

fuego-os is released under the [MIT License](LICENSE). Third-party code keeps its own licence; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
