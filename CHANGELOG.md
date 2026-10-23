# Changelog

All notable changes to this project are listed here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The plan ([the spec](https://github.com/danajerban/fuego-os/issues/1)), the glossary, research notes, and the repository's community files.
- The four package lists (Keep, Must-Keep, Known-Bloat, Takeover Packages) under `lists/`, with a check that the Must-Keep List wins and no Takeover Package is Known-Bloat.
- The script's base (`script/fuego`): `check` names the tools the Mac is missing, `pair` and `connect` reach the TV over Wireless debugging, and an unreachable TV gets the Settings path to turn Wireless debugging back on ([TV setup steps](docs/tv-setup.md)). Script tests run against a fake TV with `script/tests/run`.
- `probe`: a read-only report of the TV's chip, RAM, storage and Android build, every package tagged with the lists it is on, a section flagging packages on none of the lists, and baseline measurements (available memory, Home draw time). An unreachable TV gets the Wireless debugging steps.
- The Launcher's base: a Home screen with a Dock of Netflix, YouTube, Stremio, Spotify and Settings tiles (missing apps hidden, Back does nothing), a manifest with no INTERNET permission, receivers or services, and UI tests on an Android TV emulator.
- Contributor and agent guide (`CLAUDE.md`, with `AGENTS.md` pointing to it), decision records under `docs/adr/`, and glossary terms for the words the code and tickets now use.
- CI on every pull request and push to `main`: shellcheck 0.11.0, the script tests (also on macOS bash 3.2), the list check, the Launcher build and manifest checks (with a test that adding INTERNET fails the build), and the Launcher's UI tests on an Android TV API 34 emulator. Every action is pinned to a commit SHA.
- `apply` and `restore`: the first `apply` saves the Snapshot on the Mac (never overwritten), Debloat disables only the Known-Bloat List, animation scales go to 0.5, every write is read back, and a summary with before/after measurements is printed. `apply --dry-run` writes nothing anywhere. `restore` puts package states and animation scales back to the Snapshot. The measurements now include the Launcher's memory.
- The Launcher's Inputs tile, between Spotify and Settings: it lists the TV's HDMI ports by the names set in TV Settings (hidden inputs left out, "No HDMI inputs found" when there are none), and choosing one switches the TV to it through the TV input player.
- The Launcher's look: full-screen artwork behind a frosted glass Dock, a new picture on every Home visit (the owner's JPEG and PNG pictures in name order when the Artwork Folder has any, else four bundled pictures), and a glass highlight and tile scale-up that follow D-pad focus in 120 ms. The blur and glass are adapted from CleanYourTV (MIT). `launcher/measure_budgets.sh` measures the cold and warm Home Draw Time and the memory against their budgets.
- The Home Takeover: `apply --launcher APK` installs the Launcher, makes it the Home activity as its own step, and only after the owner's yes to a Wi-Fi warning disables the Takeover Packages (setup wizard first). A Home press must then give the Launcher focus, or the takeover is rolled back; a TV that leaves the network gets the reconnect-and-`restore` steps. Every `apply` redoes the takeover if a TV update undid it. `restore` re-enables the Takeover Packages, hands Home back to the Snapshot's Home activity and uninstalls the Launcher, also when it is already gone. The first `apply` also saves a full copy of the TV's global, secure and system settings beside the Snapshot. adb no longer reads the owner's input.
- The Idle Screen: the Launcher's screensaver (`io.github.danajerban.fuegoos/.IdleScreen`), the Launcher's only service. It shows the same artwork as Home at half brightness and cross-fades to the next picture every minute; the first key press only wakes the TV. The manifest check now fails the build on any other service.
