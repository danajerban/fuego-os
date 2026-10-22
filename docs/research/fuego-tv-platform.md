# Fuego TV platform: hardware, ROM options, and the non-root path

Researched 2026-10-23 through web search and fetches of the pages cited below. No device was touched. Claims marked **(unverified)** come from general knowledge or community reports that I could not trace to a primary source in this pass.

Input facts (from the owner): FUEGO 2K SMART TV, Google TV, Android TV OS 14, build `UKNV.260529.001`, kernel 5.15.192, security patch 2026-06-01, device name `GoogleTV8164`, Netflix ESN prefix `NFANDROID2-PRV-REFPLUSCJNODM2KT56GTV-EXPRE...`.

## Bottom line

- **Hardware can't be identified from public sources.** The ESN string, the build ID and `GoogleTV8164` return no indexed matches. Read it off the TV with ADB (commands below).
- **A custom ROM isn't realistic.** No public firmware, no unlock path, and unlocking would cost Widevine L1 and Netflix HD. Treat it as a no.
- **The non-root path is the right one:** network ADB, `pm disable-user --user 0` on Bloat, a replacement Launcher, and a few developer-option tweaks.
- **Netflix, YouTube and Stremio don't depend on the Stock Launcher.** They depend on Play Services and the Play Store, which must stay enabled.

## 1. SoC, RAM and storage

**Unknown from public sources.** Searches for the exact ESN substring, `GoogleTV8164`, `UKNV` and Fuego plus Google TV in Albania found nothing relevant.

What the strings hint at (all speculation):

- Netflix ESNs on Android embed a manufacturer and model token. `REFPLUS` and `CJNODM` look like an ODM or reference-design code, and `2K` plus `GTV` match a 1080p Google TV SKU. I could not tie `REFPLUS` or `KT56` to a MediaTek, Realtek or Amlogic board.
- Most budget 2K/FHD Google TV panels from Chinese ODMs use MediaTek TV SoCs **(unverified)**. The SoCs the search did return for Android TV 14 were MT9676 and MT9689 (projectors), not budget 2K panels ([androidtv-guide.com](https://androidtv-guide.com/streaming-gaming/android-tv-14)).
- **RAM floor:** Google TV requires at least 2 GB of RAM. Android TV (non-Google-TV) dropped to 1 GB for 1080p. Source: an AOSP change reported by [9to5Google, 2024-11-07](https://9to5google.com/2024/11/07/google-android-tv-ram-requirement/) and [Android Authority](https://www.androidauthority.com/android-tv-minimum-ram-3497217/). So expect **2 GB** on a cheap 2K Google TV. I found no official storage minimum; 8 GB is typical **(unverified)**.

How to read it (read-only):

```sh
adb shell getprop ro.board.platform         # SoC family, e.g. mt5xxx / mt9xxx / rtd28xx / amlogic codename
adb shell getprop ro.hardware
adb shell getprop ro.soc.manufacturer; adb shell getprop ro.soc.model   # set on Android 12+ devices
adb shell getprop ro.product.vendor.device; adb shell getprop ro.product.vendor.manufacturer
adb shell getprop ro.config.low_ram         # "true" = Android Go-style low-RAM config
adb shell cat /proc/cpuinfo                 # CPU cores / "Hardware" line
adb shell cat /proc/meminfo | head -3       # MemTotal = RAM
adb shell df -h /data                       # user storage
adb shell getprop | grep -i -E 'widevine|drm|mtk|rtk|amlogic'
```

## 2. Custom ROM or firmware replacement: verdict **no**

- **No firmware to start from.** Google TV builds aren't published as downloadable images. Even large vendors like Dune HD say they can't distribute firmware files because "it is not allowed by Google policy" ([Dune HD ATV14 page](https://dune-hd.com/firmware/atv14.html)). For a no-name ODM panel there are no kernel sources, device trees or a ROM community.
- **Bootloader unlock is unlikely to exist,** and unlocking usually drops Widevine from L1 to L3. Netflix then serves low-resolution playback (480p on L3 in the OnePlus case). Some devices keep L1 (Pixel 3 XL), but you can't count on that. Sources: [OnePlus 7 Pro report](https://ie.electronic.partners/news/youll-lose-hd-netflix-on-the-oneplus-7-pro-if-you-unlock-the-bootloader/), [androidayuda on Netflix and root](https://en.androidayuda.com/netflix-blocks-app-root-devices/).
- **Netflix certification is separate from L1.** Netflix checks its own device certification, keyed to the ESN, on top of Widevine ([Xataka](https://www.xatakandroid.com/tutoriales/como-saber-tu-android-tv-esta-certificado-para-ver-netflix-otras-plataformas)). A modified OS also loses Play Integrity, so the Netflix app can be refused ([Netflix help](https://help.netflix.com/he/node/23939)).
- **Brick risk is high.** Recovering a TV SoC that won't boot needs vendor USB-burn tools and images you don't have **(unverified, general knowledge)**.

## 3. The non-root path on Google TV 12 to 14

**Enable ADB:** Settings > System > About > tap *Android TV OS build* 7 times, then Developer options > enable network (wireless) debugging. Since Android 11, wireless debugging uses `adb pair ip:port` with a pairing code, then auto-connects ([Android adb docs](https://developer.android.com/tools/adb)). Community reports say Android 14 TVs can drop wireless ADB after a reboot, so re-toggle it, and `adb tcpip 5555` doesn't persist ([getchannels forum](https://community.getchannels.com/t/adbtuner-a-channel-tuning-application-for-networked-google-tv-android-tv-devices/36822?page=95)). Turn debugging off when finished ([It's FOSS](https://itsfoss.com/news/debloat-smart-tv/)).

**Commands:**

- `pm disable-user --user 0 <pkg>`: reversible with `pm enable <pkg>`. Prefer this, as the Glossary's Debloat definition already says.
- `pm uninstall -k --user 0 <pkg>`: removes it for user 0 only. Restore with `cmd package install-existing <pkg>` **(unverified on this TV)**. Both survive in `/data` and are undone by a factory reset, because the system partition is untouched.
- Get the real package list first: `adb shell pm list packages -s` (system) and `pm list packages -d` (disabled).

**Package triage** (names to verify against `pm list packages`; ODM names will differ):

| Package | Role | Verdict |
|---|---|---|
| `com.google.android.gms`, `com.google.android.gsf` | Play Services | **Keep.** YouTube sign-in, Netflix, DRM and casting all need them ([cobanov prompt](https://tv.cobanov.dev/en/prompt.txt)) |
| `com.android.vending` | Play Store | **Keep** (same source) |
| `com.google.android.tv.remote.service` | Remote | **Keep.** Disabling it breaks the remote (same source) |
| `com.android.location.fused` | Location | **Keep.** Reported boot loop when disabled (same source) |
| `com.google.android.apps.tv.launcherx` | Stock Launcher | Disable **only after** a replacement Launcher is installed and set as default ([cobanov](https://tv.cobanov.dev/en/prompt.txt), [arktronic](https://til.arktronic.com/2025/04/05/google-tv-customization.html)) |
| `com.google.android.tungsten.setupwraith` | Setup wizard / fallback home | Disable together with launcherx. It acts as a fallback and re-enables the Stock Launcher ([lemmy thread](https://lemmy.kde.social/comment/2572384), [cobanov](https://tv.cobanov.dev/en/prompt.txt)) |
| `com.google.android.tvrecommendations` | Recommendation rows | Usually safe once the Stock Launcher is gone **(unverified)** |
| `com.google.android.katniss` | Assistant / voice search | Safe if you don't use voice. Breaks the mic button **(unverified)** |
| `com.google.android.apps.mediashell` (cast receiver) | Chromecast built-in | **Keep.** Casting is on the Keep List |
| `com.google.android.apps.tv.dreamx` / ambient | Screensaver | **Keep.** The screensaver is on the Keep List. To save RAM, switch it to a lighter screensaver instead of disabling it **(package name unverified)** |
| ODM OTA updater (name varies) | Firmware updates | Leave enabled. Disabling it stops security fixes ([It's FOSS](https://itsfoss.com/news/debloat-smart-tv/)) |

**Pitfalls:**

- **Order matters.** Disabling the Stock Launcher before a replacement exists can send Home to a factory test app ([It's FOSS](https://itsfoss.com/news/debloat-smart-tv/)). After that, Home asks which Launcher to use; pick "Always" ([lemmy](https://lemmy.kde.social/comment/2572384)).
- **Hard-wired remote buttons.** On Chromecast with Google TV, the YouTube button stopped working with launcherx disabled, while the Netflix button still worked. The fix is Button Mapper ([lemmy](https://lemmy.kde.social/comment/2572384)). Google Home features and casting may misbehave without launcherx ([Reddit via mirror](https://reddit.birdcat.cafe/r/AndroidTV/comments/1ealihc/best_launcher/leq7py2/?context=3)), so test casting.
- **Updates.** A Google TV update reportedly broke Projectivy's launcher-override mode (Android Authority, 3649445; returned 403, date not confirmed). That's a reason to disable launcherx rather than rely on override. Whether OTAs re-enable disabled packages is **unverified**: re-check `pm list packages -d` after each update.
- **Factory reset** restores everything, so keep the debloat as a re-runnable script.
- **Android 14** blocks installing APKs with `targetSdkVersion < 23` (bypass: `adb install --bypass-low-target-sdk-block`). `killBackgroundProcesses()` can only kill the caller's own app, so "task killer" apps are useless ([Android 14 behavior changes](https://developer.android.com/about/versions/14/behavior-changes-all)).

## 4. Performance levers without root

- **Animation scales:** `settings put global window_animation_scale 0.5`, plus `transition_animation_scale` and `animator_duration_scale` (0 or 0.5) **(standard developer-options settings; not re-verified here)**.
- **Background process limit:** Developer options > "Background process limit" (e.g. at most 2). It resets on reboot **(unverified)**. Android 14 already stops cached apps from doing background work shortly after they become cached ([behavior changes](https://developer.android.com/about/versions/14/behavior-changes-all)). The developer-options toggle "Suspend execution for cached apps" (the cached app freezer) is usually on by default **(unverified)**.
- **Apps Only Mode** (Google account settings) removes most recommendation rows. It also turns off Assistant search and Watchlist, and you must turn it off to install apps ([How-To Geek](https://www.howtogeek.com/695447/how-to-disable-recommendations-on-google-tv/)). It's a no-ADB alternative to replacing the Launcher.
- **Ambient / screensaver:** the Google TV ambient screensaver streams photos and cards. Picking a simpler screensaver or a shorter timeout keeps the Keep List intact.
- **Energy modes** (Android TV 14): Low / Optimized / Increased standby modes ([9to5Google](https://9to5google.com/2024/05/15/android-14-for-tvs/), [TechRadar](https://www.techradar.com/televisions/android-tvs-next-free-update-promises-faster-performance-better-accessibility-and-more-energy-saving-options)). These affect standby, not foreground speed. Low may break waking the TV by casting.
- **SmartTube vs YouTube:** SmartTube runs on Android 4.3+ and is tested on Google TV devices ([SmartTubeNext README fork](https://github.com/Resshi/SmartTubeNext)). It's sideloaded, not from Play, and it's widely reported to be lighter, with no ads **(the speed claim is unverified)**. It needs a separate sign-in and can break when YouTube changes its API.
- **Stremio on 2 GB:** no official requirements found. Community reports describe catalog-screen freezes on 1.5 to 2 GB TVs and call 2 GB the practical minimum ([community roundup](https://sftp.thewrap.com/post/stremio-android-tv-crashes-fixes)). Keep the add-on count low and avoid 4K streams on a 2K panel.

## 5. Do Netflix, YouTube and Stremio work with the Stock Launcher disabled?

**Yes, with the Google account still present.** Each is a standalone app that depends on Play Services and the Play Store, not on launcherx ([cobanov](https://tv.cobanov.dev/en/prompt.txt) lists those as must-keep; [arktronic](https://til.arktronic.com/2025/04/05/google-tv-customization.html) runs Jellyfin through Projectivy with launcherx disabled). Known breakages are around the edges: a dedicated YouTube remote button (needs remapping), Assistant or voice if katniss goes too, and possibly some Google Home or cast flows ([lemmy](https://lemmy.kde.social/comment/2572384)). Netflix DRM is tied to Widevine and the ESN, which a launcher change doesn't touch. No source reported Netflix HD loss from debloating alone. **Verify on the TV:** Netflix playback, YouTube sign-in, casting from a phone, and each remote shortcut button after disabling.

## Open questions

- Actual SoC, RAM and OTA package name: run the `getprop` / `meminfo` / `pm list packages` commands above.
- Whether this TV's remote has hard-wired YouTube or Netflix buttons routed through launcherx.
