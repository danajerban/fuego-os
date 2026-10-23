# fuego-os

Makes one Fuego 2K Google TV (Android TV OS 14) fast and free of Bloat, over ADB, without root.

> **Status: pre-release.** The script, the package lists and the Launcher are built and tested against a fake TV and an Android TV emulator, but nothing here has been tried on the TV yet, the package IDs on the lists are still to be confirmed with `probe`, and no release has been made. The plan is in [the spec](https://github.com/danajerban/fuego-os/issues/1); the words it uses are in [GLOSSARY.md](GLOSSARY.md), and the decisions behind it in [docs/adr/](docs/adr/).

> **Not affiliated with Fuego, Google, Netflix, YouTube, Stremio or Spotify.** Use it at your own risk.

## What it is

Two pieces:

- **A Mac script** that talks to the TV over ADB:
  - `probe`: reads facts from the TV (chip, RAM, storage, Android build, package list with the lists each package is on), flags packages on none of the lists, measures available memory and, once the Launcher is Home, Home Draw Time, and changes nothing.
  - `apply`: takes a Snapshot (once, never overwritten), runs Debloat against the reviewed Known-Bloat List, sets the Speed Settings, installs the Launcher, performs the Home Takeover, sets the Idle Screen as the screensaver, then asks you to check casting, HDMI inputs, Wi-Fi and the remote's buttons (the Check Step). It has a dry-run flag and is safe to run again: a rerun updates the Launcher when a newer release is out and redoes the Home Takeover if a TV update undid it.
  - `restore`: puts the TV back to the Snapshot.
- **A Launcher** of our own: Kotlin with plain Android Views. A glass dock (Netflix, YouTube, Stremio, Spotify, Inputs, Settings) over full-screen artwork, in the style of Home+, and an Idle Screen that replaces Google's ambient mode as the TV's screensaver. No internet permission, and nothing runs while it is off screen except that screensaver.

## Why ADB only

There is no public firmware for this TV, and unlocking it would cost Netflix HD and risk bricking it. So fuego-os uses only what ADB allows a normal user: no root, no firmware changes, nothing deleted from the system partition. Everything is reversible.

## What it changes, and what it keeps

**Changes:**
- disables Bloat for the TV's user only (`pm disable-user --user 0`), and only packages on the reviewed Known-Bloat List;
- disables the Stock Launcher (`com.google.android.apps.tv.launcherx`) and the setup wizard (`setupwraith`) once the Launcher is Home;
- sets window, transition and animator animation scales to 0.5×;
- turns off Google's ambient mode and sets the Launcher's Idle Screen as the screensaver.

**Keeps:** Netflix, YouTube, Stremio, Spotify, Play Services and the Google Services Framework, the Play Store, the remote service, location, the cast receiver, TV Settings and the TV input player are on the Must-Keep List, which always wins. The system updater joins it once its package name on this TV is known. Packages on neither list are reported, never disabled. The background process limit and Play auto-updates are left alone.

**Known risks** reported on other Google TVs, not yet checked on this one: casting breaking when the setup wizard is disabled, saved Wi-Fi being lost, boot loops on some brands, and Wireless debugging turning off after a reboot. The plan for each is in [the spec](https://github.com/danajerban/fuego-os/issues/1).

## Quick start

You need a Mac and `adb` (`brew install --cask android-platform-tools`).

1. **Download** `fuego-os-vX.Y.Z.tar.gz` and `SHA256SUMS` from the [latest release](https://github.com/danajerban/fuego-os/releases/latest), check the bundle and unpack it:

   ```sh
   cd ~/Downloads
   shasum -a 256 -c SHA256SUMS --ignore-missing
   tar -xzf fuego-os-v*.tar.gz
   cd fuego-os-v*/
   script/fuego check
   ```

2. **Set up the TV**: turn on Developer options and Wireless debugging, then pair and connect the Mac, as [docs/tv-setup.md](docs/tv-setup.md) shows step by step:

   ```sh
   script/fuego pair IP:PAIRING-PORT CODE
   script/fuego connect IP:PORT
   ```

3. **Look before changing anything**: `script/fuego probe` reports the TV and every package with the lists it is on. Changes nothing.
4. **Apply**: `script/fuego apply --dry-run` lists what would change; `script/fuego apply` saves the Snapshot, runs Debloat, sets the Speed Settings, installs the Launcher, takes over Home after your yes, sets the Launcher's Idle Screen as the screensaver and asks you to try casting, the HDMI inputs, Wi-Fi and the remote's buttons (`--skip-checks` leaves that for the next run). The Launcher APK comes from the latest release and is installed only if it matches its checksum in that release's `SHA256SUMS`; `--launcher APK` installs a local APK instead. `--pictures FOLDER` copies the JPEG and PNG pictures in a folder on your Mac to the TV as the Launcher's artwork; other files are skipped and listed.
5. **Undo**: `script/fuego restore` puts the TV back to the Snapshot (see [How to undo](#how-to-undo)).

## How to undo

- `restore` puts package states, animation scales and the screensaver back as the Snapshot recorded them, hands Home back to the app that held it before (the Stock Launcher) and uninstalls the Launcher, unless it was on the TV before the first `apply`. It works even if the Launcher was already uninstalled.
- The Snapshot is a text file on the Mac, at `~/Library/Application Support/fuego-os/snapshot` (set `FUEGO_STATE_DIR` to keep it elsewhere). Keep it: it is the way back. The first `apply` also saves a full copy of the TV's settings beside it (`snapshot-settings-global`, `-secure` and `-system`), a record for you to consult that `restore` does not read. Your answers to the Check Step go in a separate `checks` file beside it, so the Snapshot is never rewritten.
- If casting breaks after the Home Takeover, answer "no" to the casting check: `apply` turns the setup wizard back on (the Casting Fallback) and leaves it on in later runs unless you say yes to disabling it again.
- A factory reset also undoes everything: Debloat applies to the TV's user only, and the Launcher is an ordinary app.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems privately, as [SECURITY.md](SECURITY.md) explains. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Credits

- [CleanYourTV](https://github.com/Gathin23/cleanyourtv) (MIT): the Launcher's blur trick and cached glass are adapted from it, with attribution kept. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- [Home+](https://github.com/pbalazaar/home-plus): the inspiration for the look, and for how this repo is organised.
- [CleanFrame](https://github.com/nthnclrk/CleanFrame): the inspiration for the Snapshot, guarded apply and Restore flow.

## License

fuego-os is released under the [MIT License](LICENSE). Third-party code keeps its own licence; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
