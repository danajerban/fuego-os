# fuego-os

Makes one Fuego 2K Google TV (Android TV OS 14) fast and free of Bloat over ADB, without root. Two pieces that share nothing at runtime: a Mac script that drives `adb`, and our own Launcher (an Android TV app). The plan is the spec, `gh issue view 1 --repo danajerban/fuego-os`; each slice of it is a ticket (#2 to #15).

## Read first

- [GLOSSARY.md](GLOSSARY.md): the words to use in code, tests, docs and messages (Bloat, Snapshot, Home Takeover, Fake TV...).
- [CONTRIBUTING.md](CONTRIBUTING.md): the rules that don't bend, how to run every test suite, and what a pull request needs.
- [docs/adr/](docs/adr/): decisions already made, with their reasons. Read the matching one before changing anything it covers.
- Your ticket: `gh issue view <n> --repo danajerban/fuego-os`. [docs/research/](docs/research/) holds the evidence behind package IDs and takeover pitfalls.

## Layout

- `script/fuego`: the Mac script, one file with subcommands. `script/tests/`: the Fake TV (`fake-adb`, its state layout in its header), the Fake GitHub (`fake-github`), helpers (`lib.sh`), `*.test.sh`, and the runner `run`.
- `lists/`: the four package lists as data; format and check in [lists/README.md](lists/README.md).
- `launcher/`: the Gradle project. `app/` is the Launcher; `fakeapp/` builds the Fake Dock Apps its UI tests install.
- `docs/tv-setup.md`: the owner's Wireless debugging steps; the script's messages link to it.
- `docs/releasing.md`: how a release is made and the signing key kept. `docs/budgets.md`: every recorded run of `launcher/measure_budgets.sh`.

## Rules for code

The TV-safety rules are in CONTRIBUTING.md under "Rules that don't bend"; every change that writes to the TV follows them. On top of those:

- Every `adb` call goes through `adb_call` in `script/fuego` (the ADB Boundary, `$FUEGO_ADB`). The test runner fails a test that reaches a real `adb`. Every download goes through `fetch_call` (the Download Boundary, `$FUEGO_FETCH`), and a test that reaches a real `curl` fails too.
- Shell runs on the Mac's `/bin/bash` 3.2 ([ADR 0007](docs/adr/0007-script-runs-on-bash-3-2.md)): no associative arrays, `mapfile` or `${x,,}`. Every shell file passes `shellcheck`.
- A new `adb` call the script makes needs the Fake TV taught to answer it exactly as a real TV does, with a test in `script/tests/fake-tv.test.sh`.
- The Launcher is Kotlin with plain Android Views ([ADR 0005](docs/adr/0005-own-launcher-in-kotlin-and-views.md)). Its merged manifest has no INTERNET permission, no receivers, and no service except the Idle Screen's dream; the Gradle build fails otherwise.
- Tests drive each piece from the outside ([ADR 0008](docs/adr/0008-test-through-two-seams.md)): commands in, Fake TV state and report out; key presses in, screen out. Build test-first.

## Decisions already made

Settled; build on them rather than reopening them.

- ADB only, no root ([0001](docs/adr/0001-adb-only-no-root.md)). Debloat is `pm disable-user --user 0` on the Known-Bloat List only; the Must-Keep List wins ([0002](docs/adr/0002-disable-only-reviewed-packages.md)).
- The Home Takeover disables both Takeover Packages, guarded by a Wi-Fi warning, a focus check with rollback, the Check Step and the Casting Fallback ([0003](docs/adr/0003-home-takeover-disables-both-takeover-packages.md)).
- The Snapshot lives on the Mac, is written once, and records every field `apply` changes; `restore` reads only those fields, never the settings copies saved beside it ([0004](docs/adr/0004-snapshot-written-once-on-the-mac.md)).
- Speed Settings: animation scales 0.5×; background process limit and Play auto-updates never written ([0006](docs/adr/0006-speed-settings.md)).
- Launcher app ID `io.github.danajerban.fuegoos`, API 34 only. The Artwork Folder is the Launcher's `getExternalFilesDir("artwork")` (`/sdcard/Android/data/io.github.danajerban.fuegoos/files/artwork/`).
- Code borrowed from CleanYourTV (MIT) keeps its attribution in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and in the source file.

## Toolchain

Export in every shell that builds or tests the Launcher:

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17 PATH=/opt/homebrew/opt/openjdk@17/bin:$PATH ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
```

`adb` is `/opt/homebrew/bin/adb`. The SDK has `platforms;android-34`, `build-tools;34.0.0`, `build-tools;36.0.0` (AGP 9.4 needs it for the Launcher), `emulator` and `platform-tools`. Build with the committed `launcher/gradlew`. `shellcheck` comes from Homebrew.

## Emulator

The Launcher's UI tests run on the Android TV API 34 AVD `tv34`. Several agents may share the Mac, so each uses its own port and touches only its own emulator:

```sh
$ANDROID_HOME/emulator/emulator -avd tv34 -read-only -port <PORT> -no-window -no-audio -no-snapshot &
export ANDROID_SERIAL=emulator-<PORT>
adb -s $ANDROID_SERIAL wait-for-device   # then poll `adb shell getprop sys.boot_completed` until it prints 1
adb -s emulator-<PORT> emu kill          # when done: your own port only
```

The owner's TV may be paired with this Mac over Wireless debugging, so `adb devices` lists it (possibly twice). Never run `adb` against it: always pass `-s` with your own emulator's serial, and never write to the TV without the owner's yes. Casting, HDMI switching, Wi-Fi after the takeover and the remote's buttons are checked only by the owner on the TV (casting, Wi-Fi and the remote's buttons were checked on 2026-10-23, ticket #14); say so when a change touches them.

## Tests

How to run each suite is in CONTRIBUTING.md under "Testing" (script tests, shellcheck, Launcher build and UI tests) and in lists/README.md under "The check". Run the Launcher's UI tests with `ANDROID_SERIAL` set to your own emulator.

## Commits

- Small commits with plain imperative messages ("Add probe command").
- Leave AI attribution and `Co-Authored-By` lines out of commits and PR bodies.
- A line under Unreleased in CHANGELOG.md; the version stays as it is.
- Push or open pull requests only when the owner asks.
