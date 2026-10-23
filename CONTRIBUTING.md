# Contributing to fuego-os

Thanks for helping. v0.3.0 is released and running on the owner's Fuego 2K: the script, the package lists and the Launcher are tested against the Fake TV and an Android TV emulator, and the real-TV run is recorded in [ticket #14](https://github.com/danajerban/fuego-os/issues/14) and [docs/research/fuego-2k-packages.md](docs/research/fuego-2k-packages.md). The plan is in [the spec](https://github.com/danajerban/fuego-os/issues/1), [GLOSSARY.md](GLOSSARY.md) defines its words (Bloat, Debloat, Snapshot, Restore, Home Takeover, Launcher, Idle Screen), and [docs/adr/](docs/adr/) records the decisions already made and why. Please use the words, and build on the decisions.

## The pieces

- **The script** (`script/fuego`): a shell script on the Mac that drives `adb`. Its commands are `check`, `pair`, `connect`, `probe`, `apply` and `restore`; `script/fuego help` says what each does.
- **The package lists** (`lists/`): the Keep List, Must-Keep List, Known-Bloat List and Takeover Packages, kept in the repo as data. The Must-Keep List always wins.
- **The Launcher** (`launcher/`): an Android app in Kotlin with plain Android Views. No Compose, no image-loading or analytics libraries, no INTERNET permission, nothing running while it is off screen except its screensaver (the Idle Screen) while the TV is idle.

## Rules that don't bend

- ADB only: no root, no firmware changes, no `pm uninstall`, nothing on the system partition.
- Disable with `pm disable-user --user 0` only, and only packages on the reviewed Known-Bloat List. Unlisted Packages are reported, never disabled.
- Read back every change. The script never claims a change it did not make.
- The Snapshot is written once and never overwritten. `restore` must keep working.
- Install the Launcher before the Stock Launcher is touched.

## Adding a package to the Known-Bloat List

Open an issue first, with the package name, what it does, the `probe` output that shows it, and why the TV can run without it. A package that might affect the remote, casting, HDMI inputs, Wi-Fi, Play or system updates stays off the list. The list format and the check every change must pass are in [lists/README.md](lists/README.md).

## Testing

- **The script** runs against the Fake TV, with checks on the Fake TV's state and the script's report. Run the tests with `script/tests/run` (plain bash, nothing to install; `script/tests/run probe` runs only the test files whose name contains `probe`), and check every shell file with `shellcheck script/fuego script/tests/* lists/*.sh launcher/*.sh`. Every `adb` call goes through `FUEGO_ADB`, which the tests point at the Fake TV (`script/tests/fake-adb`), and every download through `FUEGO_FETCH`, which they point at the Fake GitHub (`script/tests/fake-github`), so no test touches the network; the script must also run on the Mac's own bash 3.2.
- **The package lists** are checked with `lists/check.sh`, and the check itself is tested with `lists/check_test.sh` (see [lists/README.md](lists/README.md)).
- **The Launcher** runs UI tests on an Android TV (API 34) emulator: Home, D-pad focus, tiles, Inputs, Settings, the Idle Screen.
  With JDK 17 and the Android SDK, from `launcher/`: `./gradlew assembleRelease` builds the shrunk APK and fails if the merged manifest has the INTERNET permission, a receiver or an unlisted service (`./manifest_check_test.sh` proves it on copies with INTERNET or a second service added); `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest` runs the UI tests on one booted emulator. The tests install the Fake Dock Apps (the `fakeapp` module, one per Dock app's package name) to stand in for the real ones, plus the Fake TV Inputs (HDMI inputs and a TV input player, which the emulator lacks) for the Inputs tests.
- **CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs all of the above on every pull request and every push to `main`: shellcheck (0.11.0, the Homebrew release), the script tests (on Linux and on macOS's own bash 3.2), the list check, the Launcher build with its manifest checks, and the UI tests on an Android TV API 34 emulator.
- **The Launcher's budgets** (Dock drawn within 200 ms of Home when warm and 800 ms cold, at most 40 MB of memory): install a release build on the emulator or the TV, then run `ANDROID_SERIAL=<device> launcher/measure_budgets.sh [runs]`. It needs one Keep List app installed to leave Home for, and prints the median and worst of each. A busy Mac slows the emulator, so compare runs taken under the same load. The emulator does not count graphics memory (the owner's pictures are a hardware bitmap of about 8 MB at 1080p, Ember about 0.5 MB), so the memory budget only counts on the TV. Record each run, with its date, device and build, in [docs/budgets.md](docs/budgets.md).
- **The real TV** is the only way to check casting, HDMI switching, Wi-Fi after the Home Takeover and the remote's Netflix and YouTube buttons. If you changed one of those and couldn't try it on a TV, say so in the pull request.

## Pull requests

- One change per pull request. Say what it changes and why, and link the issue.
- Match the code around it.
- Add or update tests from the outside (commands in, TV state out; key presses in, screen out).
- For a change you can see, add before and after screenshots.
- Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).
- Leave the version alone: it changes when a release is made.

## Releases

For maintainers: set the Launcher's `versionName`, tag the commit `vX.Y.Z` and push the tag. The Release workflow publishes the signed Launcher APK with its `.apk.idsig`, the script bundle and `SHA256SUMS`, with notes grouped by label (see `.github/release.yml`). A pull request that changes the workflow runs it as a dry run, signed with a throwaway key and published nowhere. The signing secrets and how the key is made and kept are in [docs/releasing.md](docs/releasing.md).
