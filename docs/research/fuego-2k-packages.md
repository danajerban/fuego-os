# Fuego 2K: packages, Home and tuners on the real TV

Read on the owner's TV on 2026-10-23 with `fuego probe` (v0.1.0) and read-only `adb shell` commands, for ticket #14. The evidence behind the entries the lists gained from this TV.

## The TV

| | |
|---|---|
| Model | FUEGO 2K SMART TV (`nagata`, product `FUEGO_2K_ATV3`) |
| Chip | MediaTek T56 (board and hardware `mt5867`) |
| RAM | 1414 MB, 584 MB available at idle before any change |
| Storage | 1.8 GB free of 4.0 GB |
| Android | 14, build `UKNV.260529.001` |
| Maker | ODM Express Luck (`com.google.android.tv.reference_plus.ODM.EXPRESSLUCK`), Google TV reference-plus device |
| Packages | 150 installed, 1 disabled by the maker (TalkBack) |

## Home, screensaver and updater

- **HOME handlers** (`cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.HOME`): `com.google.android.apps.tv.launcherx/.home.HomeActivity` (priority 2), `com.google.android.tungsten.setupwraith/.RecoveryActivity` (1), `com.express.at.factory.factorymanager/.FallbackHome` (-999), `com.android.tv.settings/.system.FallbackHome` (-1000). Both Takeover Packages are as the research expected. The factory manager's fallback Home is new: if the Launcher ever fails after the Home Takeover, Home may land on a factory screen instead of Settings' fallback.
- **Screensaver**: `screensaver_components` and `screensaver_default_component` are `com.google.android.apps.tv.dreamx/.service.Backdrop`, `screensaver_enabled=1`, `screensaver_activate_on_sleep=1`, `screensaver_activate_on_dock=1`. The setting names `apply` writes are the ones the TV uses.
- **System updater**: `cmd package resolve-activity -a android.settings.SYSTEM_UPDATE_SETTINGS` resolves to `com.google.android.gms/.update.SystemUpdatePanoActivity`. Play Services delivers system updates; it was already on the Must-Keep List. No package name contains ota, update, upgrade or fota.

## What runs and how much memory it holds

Resident memory (`ps -A -o RSS,NAME`) at idle on the Stock Launcher, for the packages the review looked at:

| Process | RSS |
|---|---|
| `com.google.android.apps.tv.dreamx:smarthome` | 147 MB |
| `com.google.android.katniss:search` | 141 MB |
| `com.google.android.katniss:interactor` | 140 MB |
| `com.google.android.apps.tv.dreamx` | 85 MB |
| `tv.anoki.acr.anokiacroptin` | 74 MB |
| `com.express.at.factory.factorymanager` | 59 MB |
| `com.express.bt.autopair` | 57 MB |
| `com.mediatek.wwtv.mediaplayer` | 54 MB |

RSS counts shared pages, so the sum overstates what disabling frees; `probe`'s available-memory line before and after `apply` is the real measure.

Boot receivers (`dumpsys package`):

- `tv.anoki.acr.anokiacroptin`: `.AnokiReceiver` and WorkManager's reschedule receiver on `BOOT_COMPLETED`. A native `vendor.anoki.acrservice@1.0-service` runs beside it. Anoki sells contextual TV advertising to TV makers ([BusinessWire](https://www.businesswire.com/news/home/20250612878384/en/Anoki-Announces-Plans-to-Bring-Streamlined-FAST-Solution-for-OEMs-to-the-Ventura-TV-Operating-System)); ACR (automatic content recognition) recognises what is on screen.
- `fusion.android.tv.demo`: `.receiver.BootBroadcastReceiver` on `BOOT_COMPLETED`, `SCREEN_ON` and `USER_PRESENT`, with activities named `FteEnterActivity`, `RemoteEnterActivity`, `ConsoleButtonActivity` and `ForeGroundActivity`: a store demo mode that wakes at every screen-on.

## Tuners and inputs

`dumpsys tv_input` lists MediaTek tuner services for antenna (`TunerInputService`), cable (`CableInputService`), satellite (`SatelliteInputService`) and analog (`AnalogInputService`), all in `com.mediatek.tvinput`, and three HDMI ports. `ro.vendor.mtk.system.dvbs.existed=1`: the TV has a satellite (DVB-S) tuner. The same package carries the HDMI inputs, so it stays on the Must-Keep List even though the owner uses no tuner. Google's Live Channels (`com.google.android.tv`) and `com.google.android.tvrecommendations` are not installed; their Known-Bloat lines stay unconfirmed.

## How each Unlisted Package was classed

Vendor packages have almost no public documentation: searches for the expressluck, cvte, anoki, fusion and mediatek wwtv IDs found no page naming them. Roles below come from the TV itself where stated, otherwise from the package name and its overlays, and are marked.

**Known-Bloat List (added)**

| Package | Why | Evidence |
|---|---|---|
| `tv.anoki.acr.anokiacroptin` | ACR for ad targeting, starts at boot | boot receivers and 74 MB above; Anoki's business (web) |
| `fusion.android.tv.demo` | Store demo, wakes at screen-on | its receivers and activities above |
| `com.google.android.feedback` | Sends bug reports to Google | general Android knowledge |
| `com.expressluck.tvhelpmanual` | The maker's e-manual | name only |
| `com.google.android.apps.tv.dreamx` | Google's screensaver, which the Idle Screen replaces | the screensaver settings and 232 MB above |
| `com.mediatek.wwtv.mediaplayer` | USB file player the owner does not use | name, 54 MB above |
| `com.amazon.amazonvideo.livingroom`, `com.disney.disneyplus`, `com.wbd.stream`, `com.iqiyi.i18n.tv`, `com.google.android.youtube.tvmusic`, `com.google.android.videos`, `com.google.android.play.games` | Preinstalled apps the owner does not use (Prime Video, Disney+, Max, iQIYI, YouTube Music, the Google TV film store, Play Games) | the owner's answer |

**Must-Keep List (added)**: the TV stack HDMI depends on (`com.mediatek.wwtv.tvcenter`, `com.mediatek.tvinput`, `com.mediatek.tv.service`, `com.android.providers.tv`), the remote (`com.mediatek.hotkey.dispatcher`, `com.mediatek.autopair`, `com.express.bt.autopair`, `com.android.bluetooth`), the keyboard (`com.google.android.inputmethod.latin`), WebView, `com.android.shell` (adb runs through it) and the factory manager (a fallback Home, running, role unknown).

**Left unlisted on purpose**, so never disabled: the other factory and test packages (`com.cvte.tv.at`, `com.express.fac.test`, `com.at.factory.androidtvaidlservice`, `com.expressluck.facmenu`, `mediatek.factorymenu.ui`), `com.mediatek.androidbox`, `com.mediatek.wwtv.setupwizard`, `com.mediatek.wwtv.webview`, `com.mediatek.bootlogoservice`, `com.dolby.android.audio.service`, `com.android.tv.feedbackconsent`, `com.google.android.partnersetup`, and the core Android, Mainline, overlay and provider packages. Their roles are unknown or the gain is too small for the risk on a TV without recovery images ([fuego-tv-platform.md](fuego-tv-platform.md)).

## adb lists the TV twice

After `adb pair` and `adb connect IP:PORT`, adb's mDNS auto-connect also attached the same TV as `adb-<serial>-<id>._adb-tls-connect._tcp`, so `adb devices` listed it twice and every command without `-s` failed with `more than one device/emulator`. After a TV restart, only the mDNS entry was listed until `connect`. The TV also advertises `_adb._tcp` on port 5555.
