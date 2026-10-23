# The Launcher's budgets: measured numbers

Each run of `launcher/measure_budgets.sh`, newest first. The budgets: the Dock drawn within 200 ms of Home when warm and 800 ms cold, and at most 40 MB of memory. How to run it is in [CONTRIBUTING.md](../CONTRIBUTING.md) under "Testing".

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
