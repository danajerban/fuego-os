# Updating the Launcher on a rerun of apply

Researched 2026-10-23 for Q2: when `fuego apply` reruns, the Launcher (`io.github.danajerban.fuegoos`) is already on the TV and no `--launcher` is given, should apply (A) do nothing, (B) install a newer release if there is one, or (C) always reinstall? Sources are Android 14 AOSP source (`android14-release` branches on android.googlesource.com, read as plain text), developer.android.com, docs.github.com, and the local `adb` 37.0.1's own help text. Nothing was installed or run on a TV or an emulator.

## Bottom line

- **Recommend B, comparing versions by name.** A release's tag is `v` plus the Launcher's `versionName` (the release workflow refuses a tag that differs), so apply reads the TV's `versionName` from `dumpsys package` and installs the latest release only when its tag is a higher `X.Y.Z`.
- **An update does not reset Home or the Idle Screen.** In Android 14's source, a replace keeps the package's preferred activities, the HOME role is re-checked and kept for a holder that still has a Home activity, and nothing writes `screensaver_components` on a package change. Apply also runs the Home Takeover and the Idle Screen after the Launcher, and those two steps already read back Home and the screensaver and set them again when they are wrong.
- **What can go wrong is refused, not half done.** A different signing key fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. An older APK fails with `INSTALL_FAILED_VERSION_DOWNGRADE` unless `-d` is given and the build or app is debuggable. Either way the installed Launcher stays.
- **The Fake TV needs to learn versions:** a `version=` line in the fake APK, `dumpsys package <pkg>` answering `versionName=`, and `install -r` refusing a downgrade. The exact strings should be copied from the `tv34` emulator first.

---

## 1. Reading the installed version over adb

| Command | What Android 14 prints (source) |
|---|---|
| `adb shell dumpsys package io.github.danajerban.fuegoos` | A `Package [<name>] (<id>):` block holding `  versionCode=<n> minSdk=<n> targetSdk=<n>` and, on its own line, `  versionName=<name>`. Both come from `Settings.dumpPackageLPr` ([Settings.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/Settings.java), the `pw.print("  versionCode=")` and `pw.print("  versionName=")` lines). |
| `adb shell pm list packages --show-versioncode <filter>` | `package:<name> versionCode:<longVersionCode>`, one line per match. Help text: "--show-versioncode: also show the version code" ([PackageManagerShellCommand.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/PackageManagerShellCommand.java), `runListPackages`). The filter is a substring match, so other packages can match too. |

developer.android.com's [adb page](https://developer.android.com/tools/adb) lists `pm list packages` options but documents neither `--show-versioncode` nor any output format, and doesn't cover `dumpsys package`. So neither format is a documented contract. Both are plain `print` calls in the AOSP source above.

**Which is steadier to parse:** `pm list packages --show-versioncode` is one fixed line per package and is the easier to parse, but it gives only the `versionCode`. Our releases don't publish the `versionCode` anywhere outside the APK (§3), so the value apply can compare against a release is the `versionName`, which only `dumpsys package` prints. The `versionName=` line appears once in the package's block. A user-installed app has no second "Hidden system packages" entry, but that is my reading of the dump code, not something tried on a TV.

## 2. `adb install -r` on an installed app

| Fact | Source |
|---|---|
| `adb install -r` means "replace existing application"; `-d` means "allow version code downgrade (debuggable packages only)". | `adb help` of Android Debug Bridge 37.0.1 on this Mac. |
| `pm install`: "-r: Reinstall an existing app, keeping its data"; "-d: Allow version code downgrade". | [developer.android.com/tools/adb](https://developer.android.com/tools/adb), `pm install` |
| In Android 14's `pm install`, `-r` is ignored (`case "-r": // ignore`) because replacing is the default (`replaceExisting = true`); `-R` turns it off. | `PackageManagerShellCommand.java`, `doCreateSession` options |
| A replace of a non-system app deletes the old package with `DELETE_KEEP_DATA`, so the app's data stays. | [ReconcilePackageUtils.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/ReconcilePackageUtils.java) (`deleteFlags = PackageManager.DELETE_KEEP_DATA ...`) |
| A new APK signed with a different key fails: `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, "New package has a different signature: <pkg>". | [InstallPackageHelper.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/InstallPackageHelper.java), signature check in `preparePackageLI` |
| A lower `versionCode` fails: `INSTALL_FAILED_VERSION_DOWNGRADE`, "Downgrade detected: Update version code <new> is older than current <old>". A downgrade is allowed only if `-d` is given and the platform build or the installed app is debuggable. | `InstallPackageHelper.java` (`"Downgrade detected: "`), [PackageManagerServiceUtils.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/PackageManagerServiceUtils.java) (`checkDowngrade`, `isDowngradePermitted`) |
| An equal `versionCode` is not a downgrade (the check is "older than"), so reinstalling the same APK succeeds. | `checkDowngrade` |
| A running app is stopped: the old package is killed unless the install asks not to (`--dont-kill` / `INSTALL_DONT_KILL_APP`, which in its help text is for "installing a new feature split"). | `ReconcilePackageUtils.java` (`killApp`, `DELETE_DONT_KILL_APP`); `PackageManagerShellCommand.java` help |

Our own [releasing.md](../releasing.md) says the same about keys: lose the release key and the next Launcher "can't replace the installed one".

**What the TV shows while the Launcher is killed:** the Launcher is Home and often has focus when apply runs. I didn't trace in the source how the activity manager brings Home back after its process is killed during an update. Treat it as unverified, and check it on the TV (ticket #14) or the emulator.

## 3. GitHub's latest release

| Fact | Source |
|---|---|
| `GET /repos/{owner}/{repo}/releases/latest`: "The latest release is the most recent non-prerelease, non-draft release, sorted by the created_at attribute", where `created_at` "is the date of the commit used for the release". | [docs.github.com, Get the latest release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release) |
| The response has `tag_name` and `assets[]`, each with a `browser_download_url`. `GET /repos/{owner}/{repo}/releases/tags/{tag}` fetches one release by tag. | same page |
| Unauthenticated: "60 requests per hour", counted per originating IP. Over the limit, the answer is `403` or `429` with `x-ratelimit-remaining: 0`. | [docs.github.com, Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) |
| Whether downloads from `github.com/.../releases/download/...` count against that limit | Not stated on the pages I read. |

One apply makes one API call (`latest_release_tag`). Downloads go to `github.com/$GITHUB_REPO/releases/download/<tag>/<asset>`, not to the API. The `created_at` ordering means a tag made later on an older commit would not be "latest". That doesn't matter for us, since tags go on merge commits on `main` in order.

**How our releases carry the version** ([releasing.md](../releasing.md), [`.github/workflows/release.yml`](../../.github/workflows/release.yml), `launcher/app/build.gradle.kts`):
- The tag is `vX.Y.Z`. The workflow stops unless `build.gradle.kts` has `versionName = "X.Y.Z"`.
- `versionCode` is raised by one by hand at each release. It is published nowhere but inside the APK. Today it is `versionCode = 1`, `versionName = "0.0.0"`.
- So the TV's `versionName` equal to the tag without its `v` means "this release is on the TV". A rising `versionName` and a rising `versionCode` go together only because the release steps say so. Nothing checks it.

## 4. Does an update reset Home or the Idle Screen?

### Preferred Home activity (PackageManagerService)

- The preferred activities of a package are cleared in `removePackageDataLIF` only inside `if ((flags & PackageManager.DELETE_KEEP_DATA) == 0)` ([RemovePackageHelper.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/RemovePackageHelper.java), `clearPackagePreferredActivitiesLPw`). A replace deletes the old package with `DELETE_KEEP_DATA` and for all users (§2). It skips the per-user path that clears them unconditionally (`clearPackageStateForUserLIF` in [DeletePackageHelper.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/DeletePackageHelper.java), reached only for a single-user delete). **So an update keeps the Launcher's preferred Home activity.**
- At resolve time a preferred activity can still be dropped. In [ComputerEngine.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/pm/ComputerEngine.java), the `findPreferredActivityBody` code removes a "dangling preferred activity" whose component no longer exists, and turns an "always" choice back into "last chosen" when the set of Home activities changes ("Result set changed, dropping preferred activity"). **An update that keeps `.HomeActivity` under the same name keeps both the component and the set.** Renaming or removing it would drop the choice. After the Home Takeover, the set is just the Launcher, because disabled components don't answer the Home intent.

### HOME role (RoleManager)

- `RoleService` listens for `PACKAGE_ADDED`, `PACKAGE_CHANGED` and `PACKAGE_REMOVED`. It ignores a `PACKAGE_REMOVED` with `EXTRA_REPLACING` ("Package is being upgraded - we're about to get ACTION_PACKAGE_ADDED") and then re-runs its default grants ([RoleService.java](https://android.googlesource.com/platform/packages/modules/Permission/+/refs/heads/android14-release/service/java/com/android/role/RoleService.java), `onStart`).
- Those grants keep every current holder that still qualifies and remove the ones that don't ("Removing package that no longer qualifies for the role") ([RoleControllerServiceImpl.java](https://android.googlesource.com/platform/packages/modules/Permission/+/refs/heads/android14-release/PermissionController/src/com/android/permissioncontroller/role/service/RoleControllerServiceImpl.java), `onGrantDefaultRoles`).
- To qualify for HOME, an app needs an activity answering `MAIN` + `HOME`, and HOME's preferred activity is that same filter ([roles.xml](https://android.googlesource.com/platform/packages/modules/Permission/+/refs/heads/android14-release/PermissionController/res/xml/roles.xml), `android.app.role.HOME`). **An updated Launcher that still has its Home activity stays the HOME role holder.**

### Screensaver (DreamManagerService)

- `DreamManagerService` registers no package receiver. Its only receivers are for charging, dock state and user switch ([DreamManagerService.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/dreams/DreamManagerService.java), `onBootPhase` and fields).
- `getDreamComponentsForUser` reads `Settings.Secure.SCREENSAVER_COMPONENTS` each time, skips components that fail `validateDream` ("Dream ... does not exist", or a missing `BIND_DREAM_SERVICE`), and falls back to the default dream in memory. It doesn't write the setting back. The setting is written only by `setDreamComponentsForUser`, reached from the binder `setDreamComponents` call. **So an update leaves `screensaver_components` pointing at `.IdleScreen`.** If the TV goes idle in the moment the package is being replaced, that one dream could be the default instead. That is my reading, not tested.
- **Not confirmed:** Google TV's own Settings or ambient-mode app might rewrite the screensaver on package changes. Their source isn't public, so I couldn't check. AOSP's `DreamManagerService` is what the source above shows, and the TV's vendor build may differ.

### Apply already repairs both

Apply runs `apply_launcher`, then `apply_home_takeover`, then `apply_idle_screen` (`script/fuego`, the `apply` flow). The Home Takeover reads what Home opens and the HOME role holder, and sets the Home activity again when either is wrong. The Idle Screen sets `screensaver_components` and `screensaver_enabled` through `set_setting`, with a Read-Back. So even if a vendor component reset either one on update, the same apply run would put it back and report it.

## 5. The three options for this repo

| Option | For | Against |
|---|---|---|
| A. Do nothing | No download, no network needed on a rerun. That is today's code (`outcome unchanged "... already installed"`). | The owner can never get a new Launcher release without `--launcher` or `restore`. A rerun of apply then means "bring the TV to the current fuego-os" for everything except the Launcher. |
| **B. Install a newer release** | Brings the TV up to date with one API call (the call apply already makes when the Launcher is missing). Leaves the TV alone when it is current. Data, Home and the Idle Screen stay (§2, §4). | Needs a version read (one new adb call) and a version comparison in Bash 3.2. |
| C. Always reinstall | No version logic. | It downloads and installs every run and kills the Launcher while it is Home, for nothing. It fails with a downgrade when the TV has a newer APK from `--launcher`, so a plain rerun reports `failed`. |

## Recommendation: B

On a rerun with the Launcher installed and no `--launcher`:

1. Read the TV's `versionName`: `adb shell dumpsys package io.github.danajerban.fuegoos`, filtered on the Mac to the first `versionName=` line (one plain command per `adb shell`, as the Fake TV expects).
2. Look up the latest release's tag, as `latest_release_tag` already does.
3. Compare `X.Y.Z` numerically, field by field (Bash 3.2: split on `.`, no associative arrays).
   - Tag higher: download, check `SHA256SUMS`, `install -r`, and report `installed` with both versions.
   - Equal: `unchanged` "... already the latest release (vX.Y.Z)".
   - TV higher (a build given earlier with `--launcher`): `unchanged` and say so.
   - No release or no network: `unchanged` "... installed; couldn't check for a newer release (why)". Not `failed`: the Launcher is still there and the rest of apply goes on.
   - A Dry-Run says `would install ... vA -> vB` and downloads nothing, as it does now.
4. The `INSTALL_FAILED_UPDATE_INCOMPATIBLE` failure message should point to the key note in releasing.md (`fuego restore`, then `fuego apply`).
5. `--launcher APK` still always installs, as it does now. A downgrade there fails with Android's message, which is the right answer.

Reasons: it is the only option where a rerun of apply brings the Launcher up to date without the owner doing anything extra. It touches the TV only when there is something new. And per the AOSP source above, an update keeps the Home choice, the HOME role and the screensaver. Apply's later steps also check and repair them in the same run anyway.

What the owner checks on the TV (ticket #14): that Home still opens the Launcher and the Idle Screen still starts after an update, since §2's "what the screen shows while the Launcher is killed" and the vendor's screensaver handling aren't confirmed from source.

## Tests and Fake TV changes this needs

Per CLAUDE.md, each new adb call is taught to the Fake TV exactly as a real TV answers it, with a test in `script/tests/fake-tv.test.sh`. Capture the exact outputs from the `tv34` emulator first, on your own port, with two builds of the Fake Dock App or the Launcher: `dumpsys package <pkg>` around `versionName=`, and `adb install -r` of a lower `versionCode` and of a differently signed APK.

- **Fake APK:** add `version=<versionName> <versionCode>` (and maybe `key=<name>` for the signature) to the text format `install()` reads. Document it in the header.
- **Fake TV state:** `versions/<package>` holding `<versionName> <versionCode>` (and the key). Add it to the state layout in `fake-adb`'s header, and to `fake_tv_new` / a helper in `lib.sh`.
- **`dumpsys package <pkg>`:** a new case answering a `Package [<pkg>] (<hash>):` block with the `versionCode=... minSdk=34 targetSdk=34` and `versionName=` lines, laid out as the emulator prints them. An unknown package prints what the emulator prints for it.
- **`install -r`:** refuse a lower `versionCode` with the emulator's exact `INSTALL_FAILED_VERSION_DOWNGRADE` line, and a different key with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Keep the package's state, Home activities and app folders on a replace. Kill its process and drop its focus (`stop_package`), as Android does.
- **`fake-tv.test.sh`:** the fake reports the installed version from `dumpsys package`; a newer APK replaces it and keeps the Home choice; an older one and a differently keyed one are refused and change nothing.
- **Fake GitHub:** nothing new. `latest` and `releases/<tag>/` already cover it.
- **`apply` tests:** a newer release is installed and the report names both versions; the same release gives `unchanged` and downloads nothing (Fake GitHub `calls` shows only the API call); a TV newer than the release is left alone; offline or no release gives `unchanged` with the reason, and the rest of apply runs; a Dry-Run says `would install` and writes nothing; after an update, Home and `screensaver_components` are unchanged and apply reports them `unchanged`.
