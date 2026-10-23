# Contributing to fuego-os

Thanks for helping. fuego-os is at the design stage: there is no code yet. The plan is in [the spec](https://github.com/danajerban/fuego-os/issues/1), and [GLOSSARY.md](GLOSSARY.md) defines its words (Bloat, Debloat, Snapshot, Restore, Home Takeover, Launcher, Idle Screen). Please use them.

## The pieces (planned)

- **The script:** a shell script on the Mac that drives `adb`. Commands: `probe`, `apply` (with a dry-run flag) and `restore`.
- **The package lists:** the known-Bloat list and the must-keep list, kept in the repo as data. The must-keep list always wins.
- **The Launcher:** an Android app in Kotlin with plain Android Views. No Compose, no image-loading or analytics libraries, no INTERNET permission, nothing running while it is off screen except its screensaver (the Idle Screen) while the TV is idle.

## Rules that don't bend

- ADB only: no root, no firmware changes, no `pm uninstall`, nothing on the system partition.
- Disable with `pm disable-user --user 0` only, and only packages on the reviewed known-Bloat list. Unknown packages are reported, never disabled.
- Read back every change. The script never claims a change it did not make.
- The Snapshot is written once and never overwritten. `restore` must keep working.
- Install the Launcher before the Stock Launcher is touched.

## Adding a package to the known-Bloat list

Open an issue first, with the package name, what it does, the `probe` output that shows it, and why the TV can run without it. A package that might affect the remote, casting, HDMI inputs, Wi-Fi, Play or system updates stays off the list. The list format and the check every change must pass are in [lists/README.md](lists/README.md).

## Testing (planned)

- **The script** runs against a fake TV: `probe`, `apply`, `apply` again, then `restore`, with checks on the fake TV's state and the script's report. Run them with `script/tests/run` (plain bash, nothing to install), and check the script with `shellcheck script/fuego script/tests/*`. Every `adb` call goes through `FUEGO_ADB`, which the tests point at the fake TV (`script/tests/fake-adb`); the script must also run on the Mac's own bash 3.2.
- **The Launcher** runs UI tests on an Android TV (API 34) emulator: Home, D-pad focus, tiles, Inputs, Settings, the Idle Screen.
  With JDK 17 and the Android SDK, from `launcher/`: `./gradlew assembleRelease` builds the shrunk APK and fails if the merged manifest has the INTERNET permission, a receiver or an unlisted service; `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest` runs the UI tests on one booted emulator. The tests install tiny fake Dock apps (the `fakeapp` module, one per Dock app's package name) to stand in for the real ones, plus fake HDMI inputs and a fake TV input player for the Inputs screen, since the emulator has neither. Real HDMI switching can only be checked on the TV.
- **The real TV** is the only way to check casting, HDMI switching, Wi-Fi after the Home Takeover and the remote's Netflix and YouTube buttons. If you changed one of those and couldn't try it on a TV, say so in the pull request.

## Pull requests

- One change per pull request. Say what it changes and why, and link the issue.
- Match the code around it.
- Add or update tests from the outside (commands in, TV state out; key presses in, screen out).
- For a change you can see, add before and after screenshots.
- Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).
- Leave the version alone: it changes when a release is made.

## Releases

For maintainers, once there is code: tag a commit `vX.Y.Z` and push the tag. The release will carry the Launcher APK and the script bundle, with notes grouped by label (see `.github/release.yml`).
