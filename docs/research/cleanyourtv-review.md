# CleanYourTV review: fork, borrow, or write fresh?

Date: 2026-10-23. Target: single-user Google TV, Android TV OS 14, non-root, ~2 GB RAM, laggy. Apps: Netflix, YouTube, Stremio, Spotify.

Source read: shallow clone of `https://github.com/Gathin23/cleanyourtv` at commit `30626a8` (2026-10-23 00:22 +0530), into `/private/tmp/claude-501/cyt-review/repo`. Nothing was built, installed or run.

## Repo facts

| Claim | Verified | Source |
|---|---|---|
| Owner/URL | `Gathin23/cleanyourtv` | `gh search repos`, `gh api repos/Gathin23/cleanyourtv` |
| Stars | 23,790 (earlier "~23.7k" is right) | `gh api` |
| License | MIT (GitHub shows "Other" because the file adds an OFL note for the Outfit font) | `LICENSE` |
| Created / last push | created 2026-10-17, last push 2026-10-22 | `gh api` |
| Velocity | PR #1027 merged in 6 days, by a "maintainer-bot" | `git log -1` |

The repo is 6 days old with ~1,000 PRs. Expect fast churn. Upstream merges will be hard to follow.

## Performance findings (launcher/)

- **UI stack:** plain Java Views. No Compose, Kotlin, Flutter, RN or WebView. `launcher/app/build.gradle`.
- **Dependencies:** only `androidx.recyclerview:1.3.2` and `androidx.dynamicanimation:1.0.0` (JUnit is test-only). No Glide/Coil, Firebase, analytics, ads or network libs. R8 minify and shrinkResources are on.
- **APK size:** README says "about 471 KB". Not verified: we did not build it.
- **Network:** the manifest has no `INTERNET` permission, only network/Wi-Fi state (for a status pill) and `ACCESS_FINE_LOCATION` (for the Wi-Fi name). grep finds no URL or HTTP code in the Java sources. So there is no telemetry or network call at start. `AndroidManifest.xml`.
- **Background work:** no WorkManager, AlarmManager, wake locks or `BOOT_COMPLETED`. Receivers (package changes, time tick) are registered in `MainActivity` and removed in its lifecycle. A minute tick runs on a `Handler`. The CPU/RAM stats poller only runs when `show_stats` is on (off by default). Two optional accessibility services (`HomeKeyService`, `InputKeyService`) filter key events only. A `ClockDream` screensaver and a `ThemeProvider` are also there.
- **Blur/glass:** no live blur (no RenderEffect or RenderScript). `HeroArt.java` shrinks the focused app's banner to a 48×27 bitmap and stretches it with bilinear filtering (~5 KB). `GlassView.java` draws gradient, sheen and rim strokes into a hardware layer, so springs only move a cached texture. The scrim is one stretched 480×270 bitmap. Wallpapers decode as RGB_565 by default (`wallpaper_true_color=false`).
- **Top shelf caveat:** the "cinematic" shelf shows a *blurred colour wash* of the app banner, not sharp full-screen artwork. A Home+ look with crisp key art would need new code: pre-rendered local images per app, plus a pre-blurred copy for the dock.
- **Taking over Home:** `MainActivity` declares the HOME intent filter. Disabling the stock launcher is done over ADB (`tools/disable.sh`, `restore.sh`). `docs/TROUBLESHOOTING.md` covers disabled `launcherx`, the `setupwraith` crash-loop and Wi-Fi loss, and the `stock_home_redirect` accessibility fallback for firmware that re-enables the stock home. This is the most valuable part of the repo for us.
- **Inputs:** there is an Inputs pill plus `InputsRequestActivity` (VIEW_INPUTS).
- **Size and quality:** about 10.8k lines of Java. `MainActivity` alone is 3,148 lines. Well commented, with JVM tests. About 2k lines are festival and novelty code (Diya, Marigold, Bell, PetalShower, Festival, RaceWeekend, Sky/Sun) plus vendor shims (Coocaa, Yandex, Xiaomi). Module cards (`Cards`, 864 lines), the app library and themes go beyond a 4-app dock. Rough estimate: we would delete 60–70% of it, and most of what is left sits inside the god-class `MainActivity`.

## Not verified

- Real RAM (PSS) on a TV. `tools/bench.py` can measure it, but the repo has no recorded number for the launcher. The tv-detox "~30 MB" figure was not checked here.
- APK size, and how the app behaves on Android TV 14 or Google TV.

## Verdict

**Borrow pieces, write fresh.** The performance approach is sound and matches ours: Views, almost no dependencies, no network, pre-rendered tiny bitmaps. But trimming a 3k-line `MainActivity` that changes daily costs more than writing ~1.5k lines. Borrow these: the HeroArt downscale trick, the GlassView hardware-layer pattern, the HOME manifest setup, the disable/restore scripts and the launcherx/setupwraith troubleshooting notes (MIT, keep attribution).

**Views over Compose** on a 2 GB TV:
1. No Compose runtime, so a smaller APK and less dex to load.
2. Faster cold start: no Compose init or JIT warm-up for lambdas and recomposition.
3. Mature D-pad focus handling in Views. Compose-for-TV focus still needs more tuning.
4. Hardware layers and `ViewPropertyAnimator` give cheap fixed-texture motion. CleanYourTV shows this already works on 1 GB sets.
