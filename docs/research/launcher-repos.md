# Launcher repos: CleanFrame and Home+

Researched 2026-10-23 by reading each repo (README, docs, source, issues, PRs, releases) via a read-only shallow clone and `gh api`. Nothing was built, run or installed.

## Bottom line

**Neither project targets Google TV or Android TV.** Both URLs exist, but:

- **CleanFrame** is a web launcher for a **Samsung The Frame (Tizen)**.
- **Home+** is a native launcher for **rooted LG webOS** TVs.

So neither one says anything about `com.google.android.apps.tv.launcherx`, ADB debloating, or Android accessibility remaps. CleanFrame's README says this directly: "Android TV, Google TV, LG webOS and Roku need their own implementations" (README, "Put it on a TV" table). For an Android version, CleanFrame points to [Ansub/tv-detox](https://github.com/Ansub/tv-detox) as "a different implementation". We did not research that repo, and it is the next one to read for Google TV.

---

## CleanFrame — github.com/nthnclrk/CleanFrame

| Item | Finding (source) |
|---|---|
| What it is | A personal home-screen web app (`.wgt`) for Samsung The Frame, plus an optional one-shot native helper that reassigns the Home button. It is not a debloat script. (README; `scripts/native-home/README.md`) |
| Stack | ES5 JavaScript/HTML/CSS Tizen web app (`app/`), Python and Node dev/check scripts, and a C# .NET 6 native helper (`scripts/native-home/Control.cs`). (repo languages; `docs/development.md`) |
| How it becomes Home | The app manifest alone doesn't make it Home. The helper runs once as the SDK user (UID 901) through an "undocumented package-name command-execution workaround". It calls `app_operation_set_current_app` for `http://tizen.org/appcontrol/operation/main` and writes the vconf keys `db/appfw/home_appid`, `startup_appid`, `booting_appid_backup` and `db/first_screen/type`, plus `db/menu/smart_hub/ontvsetting/auto_start`=1. It is based on splitcipher/couchroot's S90D work. (`docs/agent-tv-setup-guide.md` Stage 7; `Control.cs` lines 9–45) |
| Packages disabled | None. It keeps `com.samsung.tv.csfs` as an explicit "Samsung Home" escape. (`docs/interaction-behaviour.md`) |
| Root | No. It "does not request root or change security policy." (`scripts/native-home/README.md`) |
| Min OS / tested | Manifest declares `required_version="6.5"`, but only Tizen 9.0 has been tested: QA55LS03DAWXXY (LS03D), firmware 2130.0, ARMv7. (`docs/development.md`; `docs/tv-status.md`) |
| Revert | `python3 scripts/native-home/run.py restore` writes back the exact original values from a private `original.json`. Restore **before** uninstalling, or Home points to a missing app. A firmware update can make the guarded helper refuse to run, including when asked to restore. (setup guide, "Recovery") |
| Last commit / licence | 2026-10-20; MIT (fonts and photos keep their own terms). |
| Breakage issues | Issue #1: LS03B/Tizen 6.5 reports the native Home route as unverified. PR #2: Tizen 6.5 (Chromium 85) has no CSS `inset`, so layouts collapse. Netflix and YouTube launch, and Home from Netflix works. Power-on after streaming and Art Mode are still unconfirmed. Netflix swallows repeated Back. |

**Best practices it documents:**
- Installing the app and taking over Home are separate steps, and you can stop after installing.
- Before any write: verify model and firmware, take an original snapshot once and never overwrite it, back up the recovery files outside the project, and show the owner the commands to approve.
- Use the native setters with readback. If an apply fails, restore automatically.
- Test apply, then restore, then reapply.
- Command or SDK success doesn't count as physical proof. Record passes, failures and unknowns separately.
- No global Back interception. Focus never launches an app. The interface has a 1920×1080 logical stage, uses only transform and opacity for focus, and pre-renders its glass and blur.

---

## Home+ — github.com/pbalazaar/home-plus

| Item | Finding (source) |
|---|---|
| What it is | A tvOS-style launcher with a "Liquid Glass" look for **rooted LG webOS**, with a root background service. (README) |
| Stack | A native C app (SDL2, OpenGL ES 2), a QML UI, a Node.js luna service, and a boot script `init.d/50-homeplus`. (repo languages; README, "What it does") |
| How it becomes Home | The service watches for LG's home screen and opens Home+ instead, so LG's screen flashes briefly. To avoid the flash, use lginputhook with a keybind on button `773` → launch Home+. On web-app home TVs there is also a "No Flash" mode that replaces LG's home page in memory. (README, "Home button") |
| Packages disabled | None. It replaces nothing on disk. |
| Root / install | Root plus the Homebrew Channel are required. Install the `.ipk` from Releases with webOS Dev Manager or `ares-install`. On first start it gets root from the Homebrew Channel and links its boot script. (README, "Requirements", "Install") |
| Tested | LG C3 OLED, webOS 9.2.1 (firmware 23.20.59) only. |
| Revert | Settings → Remove Home+ undoes everything. A manual SSH method is also documented. Keybinds fall back to LG's home if Home+ is gone, and the Homebrew Channel failsafe skips boot scripts after a crash. (README, "Removing Home+") |
| Last commit / licence | 2026-10-22 (v0.18.0 commit; latest release v0.17.0); MIT. |
| Issues | None open or closed. |

**Look:**
- A glass dock of app tiles with a Top Shelf. When an app is focused, its artwork fills the screen.
- Continue Watching (Stremio, Trakt, Jellyfin, Plex) and TMDB "Popular on" rows.
- Glass edges with refraction, spring motion, and a focus tick sound.
- Tile styles: Default, Dark, Clear or Tinted (10 colours).
- A tvOS-style Control Center opens from the clock, with Inputs listing HDMI port names, Sound output, Picture mode and similar controls.
- A Recents app switcher.

## Features worth borrowing (for an Android/Google TV launcher)

- **Snapshot and restore:** CleanFrame's flow (exact original snapshot → guarded apply with readback → tested restore → reapply) maps directly onto `pm disable-user` of launcherx plus `cmd package set-home-activity`.
- **Explicit escape:** a visible "open stock home/settings" action.
- **Fallback when uninstalled:** Home+'s Home-key remap falls back to stock if the launcher is missing.
- **One-step removal:** Home+'s "Remove" action undoes everything it set up.
- **QR/device-code sign-in:** no typing passwords on the TV.
- **Continue Watching row:** pulled from Trakt, Plex and Jellyfin.
- **OLED care:** pixel shift, idle dimming and blanking.
- **Inputs tile:** HDMI inputs with names.
- **Cheap focus effects:** pre-rendered blur, and focus done with transform and opacity only.
