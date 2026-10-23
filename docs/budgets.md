# The Launcher's budgets: measured numbers

Each run of `launcher/measure_budgets.sh`, newest first. The budgets: the Dock drawn within 200 ms of Home when warm and 800 ms cold, and at most 40 MB of memory. How to run it is in [CONTRIBUTING.md](../CONTRIBUTING.md) under "Testing".

## 2026-10-23: tv34 emulator, the clock and six tiles that fit

- **Device:** the `tv34` AVD as below, started the same way, at its own 1920x1080 and density 320, on the same Mac shared with other work.
- **Build:** the release build (`assembleRelease`, shrunk) of commit `2c040dc`, signed with the debug key to install it. The Artwork Folder was empty, so Home showed Ember. YouTube and the Fake Dock Apps for Netflix, Stremio and Spotify were installed; the script left Home for the fake Netflix.
- **Runs:** 9.

| Budget | Median | Worst | Runs | Budget |
|---|---|---|---|---|
| Cold Home Draw Time | 266 ms | 353 ms | 266, 245, 277, 274, 252, 228, 253, 353, 280 | 800 ms |
| Warm Home Draw Time | 60 ms | 250 ms | 89, 250, 52, 31, 70, 60, 38, 65, 42 | 200 ms |
| Memory (total PSS) on Home | 29 MB | 29 MB | 29 each | 40 MB |

The draw times are within budget; one warm run of the nine went over 200 ms (as one of main's runs did in the run before this one: the emulator's noise). The memory is within budget.

**Against main under the same load:** main's release build (commit `fae8f93`), measured just before over 9 runs, gave a cold median of 332 ms (worst 803), a warm median of 85 ms (worst 173) and 25 MB. The clock costs about 4 MB more: its large bold text, its shadow and the date formats. An earlier version of this change, which set the clock's text before Home's first frame, gave 378 ms cold and 138 ms warm against main's 264 ms and 77 ms just before it; the clock now starts once the Dock's first frame is drawn, and shows a frame later.

## 2026-10-23: tv34 emulator, Dock icons and clearer glass

- **Device:** the `tv34` AVD as below, started the same way, on the same Mac shared with other work.
- **Build:** the release build (`assembleRelease`, shrunk) of commit `cbdc0a2`, signed with the debug key to install it. The Artwork Folder was empty, so Home showed Ember. YouTube (the emulator's own) and the Fake Dock Apps for Netflix, Stremio and Spotify were installed, so Home loaded four app icons; the script left Home for the fake Netflix.
- **Runs:** 9.

| Budget | Median | Worst | Runs | Budget |
|---|---|---|---|---|
| Cold Home Draw Time | 261 ms | 308 ms | 207, 261, 247, 272, 280, 233, 308, 266, 257 | 800 ms |
| Warm Home Draw Time | 66 ms | 96 ms | 96, 61, 64, 67, 66, 75, 71, 30, 54 | 200 ms |
| Memory (total PSS) on Home | 25 MB | 26 MB | 25 each but one 26 | 40 MB |

All three are within budget on the emulator.

**Against main under the same load:** main's release build (commit `fae8f93`), measured just before with the same apps installed over 9 runs, gave a cold median of 313 ms (worst 422), a warm median of 95 ms (worst 170) and 25 MB. The icons load on a background thread after Home's first frame, so the change should not slow Home; the lower numbers here are within the emulator's run-to-run noise, not a speed-up.

## 2026-10-23: tv34 emulator, the Ember gradient

- **Device:** the `tv34` AVD as in the run below, started the same way, on the same Mac shared with other work.
- **Build:** the release build (`assembleRelease`, shrunk) of commit `94a7ce2`, signed with the debug key to install it. The Artwork Folder was empty, so Home showed Ember. Timed as below, leaving Home for YouTube.
- **Runs:** 9.

| Budget | Median | Worst | Runs | Budget |
|---|---|---|---|---|
| Cold Home Draw Time | 298 ms | 378 ms | 373, 364, 362, 266, 298, 283, 281, 265, 378 | 800 ms |
| Warm Home Draw Time | 100 ms | 191 ms | 105, 110, 91, 191, 100, 70, 69, 107, 62 | 200 ms |
| Memory (total PSS) on Home | 24 MB | 24 MB | 24 each | 40 MB |

All three are within budget on the emulator.

**Against main under the same load:** main's release build (commit `55c457c`, bundled pictures), measured just before over 5 runs, gave a cold median of 341 ms, a warm median of 95 ms and 23 MB. An earlier version of this change, which rendered Ember on the GPU into a full-size hardware bitmap, gave 390 ms cold and 147 ms warm over 9 runs, because that rendering held up Home's first frame; Ember is now drawn on the CPU at a quarter size instead.

**The gap in the memory number:** as below, graphics memory is not counted. Home's Ember is a hardware bitmap of about 0.5 MB (a quarter of 1920x1080 each way, stretched by the view), against about 8 MB for a 1080p picture, so the estimate on Home without owner pictures is about 25 MB. Owner pictures are still full-size, about 8 MB.

## 2026-10-23: tv34 emulator (ticket #9)

- **Device:** the `tv34` AVD (Android TV, API 34, `google/sdk_google_atv64_arm64/emu64a:14/UTT1.240131.001.F1/11825476`), 1920x1080, started with `-read-only -no-window -no-audio -no-snapshot` on an Apple silicon Mac shared with other work.
- **Build:** the release build (`assembleRelease`, shrunk) of commit `d918fab`, signed with the debug key to install it. The Launcher was installed but not the TV's Home; `launcher/measure_budgets.sh` times it with `am start -W -n .HomeActivity`, leaving Home for YouTube.
- **Runs:** 5.

| Budget | Median | Worst | Runs | Budget |
|---|---|---|---|---|
| Cold Home Draw Time | 341 ms | 461 ms | 461, 341, 266, 350, 296 | 800 ms |
| Warm Home Draw Time | 82 ms | 115 ms | 93, 44, 51, 115, 82 | 200 ms |
| Memory (total PSS) on Home | 23 MB | 23 MB | 23 each | 40 MB |

All three are within budget on the emulator.

**The gap in the memory number:** the emulator's `dumpsys meminfo` reports `Graphics: 0`, so the artwork, a hardware bitmap of about 8 MB at 1080p, is not counted. With it, the Launcher's memory on Home is estimated at about 32 MB against the 40 MB budget. That estimate is not a measurement.

**What counts:** these are emulator numbers. The real numbers, on the TV with its own chip and graphics memory, are for ticket #14.
