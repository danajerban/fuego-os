# Android / Google TV launchers: taking over Home without root

Researched 2026-10-23 for one Google TV (Android TV OS 14, non-root, ADB only) whose owner keeps the Google account, Play Store, Netflix, YouTube, Stremio, HDMI inputs, Chromecast casting and the screensaver. Sources are repos (read-only shallow clones and `gh api`), issue trackers, AOSP source, Google Play listings and developer.android.com. Nothing was installed or run on a TV. XDA returned HTTP 403 to the fetcher, so XDA threads are cited only where another primary source quotes the same commands.

## Bottom line

- **Taking over Home on Google TV 12–14 without root means disabling two packages, not one:** `com.google.android.apps.tv.launcherx` (the home screen) and `com.google.android.tungsten.setupwraith` (the setup wizard, which also answers HOME). `cmd package set-home-activity` alone prints `Success` and changes nothing while launcherx is enabled.
- **Disabling setupwraith has real costs for this owner.** On Google's own hardware (Chromecast with Google TV, Google TV Streamer) it **breaks casting**. On several TVs it **deletes the saved Wi-Fi network**. Disabling launcherx also removes the YouTube button, the remote's settings/dashboard panel, and the Accounts & profiles page.
- **The safer route for an owner who wants casting:** keep both packages enabled. Our launcher then takes the screen back with an accessibility service, as in tv-detox's open issue #66, Projectivy's "Override" option and ATV Launcher Pro's "Home Button Redirect". The cost is a brief flash of the Google TV home screen.
- **[CleanYourTV](https://github.com/Gathin23/cleanyourtv) (MIT, 23.7k stars, active 2026-10-22) already ships an Apple TV-style home with a dock, top shelf and glass highlight.** It is the closest thing to what we want and is worth forking or studying before we write our own.
- **Stremio's continue-watching can be read** from its account API (`api.strem.io`, `datastoreGet` on `libraryItem`). That API is the one Stremio's own clients use. It is not documented for third parties.

---

## 1. Ansub/tv-detox

| Item | Finding (source) |
|---|---|
| What it is | A prompt for Claude Code or Codex that debloats an Android TV over ADB, plus a tiny home screen (`com.ansub.tvhome`). The home screen is one screen of plain Java with no libraries and no Gradle, and the README says it uses about 30 MB of RAM. It shows your apps, the HDMI inputs, a clock and a network icon. (README) |
| Packages it disables | The installer turns off only known launchers: `com.google.android.tvlauncher`, `launcherx`, `com.google.android.leanbacklauncher`, `com.mitv.tvhome` and `com.amazon.tv.launcher`. It skips anything matching setup, systemui, tvinput or PERSISTENT. `setupwraith` is disabled only with `YES_SETUP=1`. (`install.sh` `LAUNCHERS`, `is_launcher`) The cleanup itself is left to the AI or user, guided by `candidates.sh` (verdicts never/keep/safe/review) and `docs/debloat.md`. |
| Google TV handling | **Since v1.4.1, on Google TV it does not disable launcherx unless you set `GOOGLE_TV=1`**, because some Chromecasts boot-looped and needed a factory reset. With launcherx kept on, "Home keeps opening Google TV's". (README warnings; `install.sh` lines 111–130; PR #32) |
| How it sets Home | `cmd role add-role-holder --user 0 android.app.role.HOME com.ansub.tvhome` on SDK 29 and later, then `cmd package set-home-activity com.ansub.tvhome/.MainActivity`. Each disabled package is written to `/data/local/tmp/tvhome-disabled.txt` before it is disabled. It waits 15 s, because "Restarting before then can undo it", and runs set-home-activity again. (`install.sh` lines 65–108) |
| Revert | `sh undo.sh <TV_IP>` enables everything on that list plus setupwraith, then re-grants launcherx's notification listener (`cmd notification allow_listener …TvNotificationListenerService`, see issue #16). It keeps tvhome installed if anything fails to come back, and otherwise uninstalls tvhome and presses HOME. (`undo.sh`) |
| Last commit / licence | 2026-10-22 ("README: OnePlus TVs…", #65), v1.5.3; MIT. |
| Open issues that matter | #66 opt-in accessibility "Home button" for Google TV (see §2). #16 TCL A11: after disabling launcherx, Home → `setupwraith/.RecoveryActivity`, giving a black-screen loop. #21 Acer GTV 14: that loop crashed `system_server` about once a minute, and Acer's Settings re-enables setupwraith at boot. #14 Xiaomi stick: boot loop on the Google TV logo, factory reset needed. #52 HDMI tiles missing after boot (no `TvInputCallback`). |

## 2. Becoming Home on Google TV 12–14 without root

**The commands everyone converges on.** They appear in the FLauncher fork README (tested on Chromecast with Google TV), [Projectivy issue #415](https://github.com/spocky/miproja1/issues/415) (TCL, Android 14) and [cretezy.com](https://cretezy.com/2026/ad-free-android-tv):

```sh
adb shell cmd package set-home-activity <pkg>/<activity>
adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
# revert
adb shell pm enable com.google.android.tungsten.setupwraith
adb shell pm enable com.google.android.apps.tv.launcherx
```

**Why both, and in which order** (CleanYourTV `docs/TROUBLESHOOTING.md`, `examples/google-chromecast-gtv-4k/debloat.txt`):
- While launcherx is enabled, `set-home-activity` "prints `Success` and changes nothing". The launcherx home activity cannot be disabled from the shell.
- setupwraith answers HOME too: `.MainActivity` at priority 4 and `.RecoveryActivity` at priority 1. Android ignores `android:priority` on HOME filters for non-system apps, so we cannot outrank it. `pm disable-user` on just `.RecoveryActivity` is refused (`SecurityException: Shell cannot change component state`). setupwraith also "re-enables launcherx" (FLauncher README).
- Install and launch the new launcher first. Disable setupwraith **before** launcherx. A reboot while `.RecoveryActivity` had focus factory-reset a Xiaomi MiTV-MOSR4.
- Check the result with `dumpsys activity activities | grep mFocusedApp`. `resolve-activity` and `cmd role get-role-holders` can both name the new launcher while HOME still lands on `RecoveryActivity`.
- With file-based encryption, Home starts before the first unlock. If the TV has no `FallbackHome`, the launcher must be direct-boot-aware or boot never finishes.

**What the remote's Home button does afterwards**
- With both packages disabled, Home opens the new launcher, through reboots too (tv-detox TCL notes; Sony report in #11).
- With launcherx left enabled, Home opens Google TV. On a Chromecast, "Google TV handles Home before accessibility services ever see it". tv-detox #66 therefore uses an accessibility service that watches for `launcherx…home.HomeActivity` and opens our launcher over it. It reads no keys, is limited to launcherx events, and fires at most once every 3 s. It was tested on a Chromecast HD running Android 14.

**What still works / what breaks with launcherx and setupwraith disabled**

| Area | Result (source) |
|---|---|
| Settings app | `com.android.tv.settings` is a separate package and keeps working. tv-detox and CleanYourTV both open it from tiles. |
| Remote settings/dashboard button | **Breaks:** launcherx's side panel (picture mode, sound, profile) is gone. The closest replacements are a shortcut panel and the full TV Settings app. (CleanYourTV issue #345) |
| Accounts & profiles | **Empty:** that page lives in launcherx. You have to re-enable launcherx to switch profiles. (CleanYourTV TROUBLESHOOTING, TCL GTV 14) |
| HDMI inputs | **Work** through `com.google.android.tv.inputplayer/.player.PassthroughPlayerActivity`. `com.android.tv` can be a "Hello World!" stub on Google TV 14. (tv-detox #5) |
| **Casting** | **Breaks on Chromecast with Google TV and Google TV Streamer:** mediashell loads its factory credentials from a `CastInfoProvider` inside setupwraith, so phones report "Untrusted device". The workaround is to re-enable setupwraith after each boot and restart the receiver. A Mi Box S still casts with setupwraith off. (CleanYourTV TROUBLESHOOTING, Chromecast list) |
| **Wi-Fi** | **Can be lost:** a network saved during setup belongs to setupwraith and is deleted when it is disabled. Check `dumpsys wifi | grep -o 'cname=[^ ]*'` first, and re-join in Settings if it names setupwraith. (CleanYourTV; cretezy.com) |
| YouTube button | **Dead:** it sends BUTTON_3 (190), which launcherx handled. It can be remapped with an accessibility key mapper such as Key Mapper (FOSS) or Button Mapper. (FLauncher README; CleanYourTV Chromecast list) |
| Notifications | Android TV has no notification panel of its own; launchers provide it. launcherx's listener grant can be lost and needs re-granting on revert. (tv-detox #16, `undo.sh`) |
| Screensaver | If `dreamx` is disabled, `screensaver_components` must be repointed. Keep it on, since the TV is likely OLED. (CleanYourTV list; tv-detox #50) |
| Google TV setup, "For you", Live tab | The setup wizard must be re-enabled before any factory reset. Losing the launcherx-only tabs is our **inference**; no source tested it. |
| Firmware updates | They can re-enable packages or undo the takeover. TCL's AppBootPolicy and XGIMI's key receiver both re-enable launcherx. (Projectivy #415; CleanYourTV TROUBLESHOOTING) |

## 3. Existing launchers

| Launcher | Licence / source | Ads, telemetry | Android 14 | RAM | Toward glass / tvOS look |
|---|---|---|---|---|---|
| **Projectivy** (`com.spocky.projengmenu`) | Closed source. [spocky/miproja1](https://github.com/spocky/miproja1) holds only the issue tracker and APKs. v4.72, 2026-10-03. | Play: no "Contains ads" label, has in-app purchases. Data safety lists optional analytics on device IDs, approximate location, crash logs and app interactions, with no sharing. | Yes, but TCL A14 needs autostart fixes (#415), and one QM7K needed a factory reset after the full disable set. | Not published | Strong: wallpaper blur, adaptive colours, icon packs, video wallpapers. Not a dock or top shelf. |
| **FLauncher** | GPL-3.0, Flutter. Original on [GitLab](https://gitlab.com/flauncher/flauncher) (active 2026-09-22); [osrosal fork](https://github.com/osrosal/flauncher) last released 2025-07. | "No ads". No telemetry is mentioned. | Not stated | Not published (a Flutter engine adds a baseline cost) | Weak: wallpapers, categories, row/grid. Forkable, but GPL. |
| **ATV Launcher Pro** (`ca.dstudio.atvlauncher.pro`, DStudio Canada) | Closed source, $2.99 one-time. Updated 2026-10-16. | Play: no ads label. Collects crash logs and approximate location, with no sharing. The free edition was ad-supported per a 2024 review, and its listing now returns 404. | Unverified; it added a "Home Button Redirect" (Android Authority, 2026) | Not published | Medium: 12 row styles including a "macOS Dock" style, a layout editor and widgets. |
| **Wolf Launcher** | Closed source. Not on Play; distributed via the Troypoint/Downloader list. It targets Fire TV. | Unknown | Unknown | Unknown | Not relevant. **An untrusted APK source; skip it.** |
| **tv-detox** `com.ansub.tvhome` | MIT, plain Java | None; only network-state permissions | Tested on Google TV 14 (TCL) | ~30 MB (README claim) | Minimal gradient tiles |
| **CleanYourTV** `com.gathin.tvhome` | MIT, Java, APK about 471 KB | "No network permission, no background services" | Many GTV 14 lists, including Chromecast and Streamer | Has `tools/bench.py` to measure PSS | **Closest to our goal:** black home, a 4-app dock in a rounded band, a top shelf with glow from the artwork colour, a floating glass highlight, frosted Inputs/Wi-Fi/Settings buttons, push-over-Wi-Fi themes, a clock screensaver, and remote-key keepers. It uses no real blur, by design, so it runs on 1 GB TVs. |

None of these publish RAM numbers we could verify. To measure on our TV: `adb shell dumpsys meminfo <pkg> | grep TOTAL`.

## 4. Building our own

- **Compose for TV:** `androidx.tv:tv-material` 1.1.0 and `tv-foundation` 1.0.0 have both been stable since 2026-05-06. tv-foundation's TV lazy layouts were deprecated in 1.0.0-alpha11 and removed in alpha12, so use standard Compose `LazyRow` and `LazyColumn`. ([release notes](https://developer.android.com/jetpack/androidx/releases/tv)) Real blur (`Modifier.blur` / `RenderEffect`) needs API 31 or later and costs GPU time on TV SoCs. Home+ and CleanYourTV both fake glass, with pre-rendered blur or none.
- **Minimum manifest** (tv-detox `AndroidManifest.xml`, CleanYourTV manifest):
  - Give the main activity `MAIN` + `HOME` + `DEFAULT`, with `singleTask`, `stateNotNeeded`, `clearTaskOnLaunch` and `excludeFromRecents`.
  - Add a `MAIN` + `LEANBACK_LAUNCHER` entry with a banner, so the launcher also appears in the apps row. tv-detox #66 adds this because a HOME-only app "doesn't appear in any app list".
  - Declare `<uses-feature android.software.leanback required=false>` and `touchscreen required=false`.
  - Add `<queries>` for `MAIN`+`LEANBACK_LAUNCHER` and `MAIN`+`LAUNCHER`, which Android 11+ package visibility requires, plus `<package com.google.android.tv.inputplayer>`.
  - Make the HOME activity direct-boot-aware.
- **Listing apps:** call `PackageManager.queryIntentActivities` for both categories, with no `QUERY_ALL_PACKAGES`. (tv-detox `MainActivity.java`)
- **HDMI inputs:** `TvInputManager.getTvInputList()`, filtered by `TYPE_HDMI`, `getParentId()==null` and `!isHidden()`, with labels from `loadCustomLabel()`/`loadLabel()`. tv-detox does this with **no permission declared**. Open an input with `ACTION_VIEW` on `TvContract.buildChannelUriForPassthroughInput(id)`, trying inputplayer first. Register a `TvInputCallback`, because inputs can register after Home starts (tv-detox #52).
- **Watch Next / Continue Watching rows from the TV provider:** this needs `READ_TV_LISTINGS`, which is `dangerous` (a runtime prompt or `pm grant`). Without the `signature|privileged` permission `ACCESS_ALL_EPG_DATA`, a query returns only your own rows plus rows marked `searchable`, and any `selection` argument throws `SecurityException`. (AOSP `TvProvider.java` `createSqlParams()`, `TvProvider/AndroidManifest.xml`) Whether Stremio or Netflix write rows there on this TV is **unverified**. Test with `adb shell content query --uri content://android.media.tv/watch_next_program`.
- **Stremio continue-watching** ([stremio-core](https://github.com/Stremio/stremio-core), MIT, active 2026-10-22):
  - Log in with `POST https://api.strem.io/api/login`, or use device-link sign-in via `https://link.stremio.com/api/v2/create` and `read`, so nobody types a password on the TV.
  - Then call `POST /api/datastoreGet` with `{authKey, collection:"libraryItem", ids:[], all:true}`.
  - An item is in continue-watching when `type != "other" && (!removed || temp) && state.timeOffset > 0`. Progress is `timeOffset / duration`, and `state.video_id` names the episode.
  - Deep links take the form `stremio:///detail/{type}/{id}/{videoId}`.
  - Sources: `src/types/api/request.rs`, `src/types/library/library_item.rs`, `src/constants.rs`, `src/deep_links/mod.rs`.
  - Caveats: this is a private client API with no published third-party terms. Whether the Android TV Stremio app accepts `stremio:///` intents is **unverified**.

## Open questions for the owner

1. Is the TV a Chromecast or Google TV Streamer, or a TV set? Casting breaks with setupwraith off on Google's own hardware.
2. Which costs are acceptable: a brief Google TV flash on Home (accessibility redirect, nothing disabled), or losing casting, the dashboard panel and profiles (disable both packages)?
3. Fork CleanYourTV (MIT, already close to the look) or start fresh in Compose for TV?
