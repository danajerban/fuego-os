# The Snapshot is written once, on the Mac, with every field from the start

The first non-dry-run `apply` writes the Snapshot on the owner's Mac, and no later run rewrites it. A second run can then never erase the way back, and the Snapshot survives anything that happens on the TV (spec, user stories 11 to 13; CleanFrame's "snapshot once, never overwrite" practice in [launcher-repos.md](../research/launcher-repos.md)).

Because it is never rewritten, the Snapshot records every field `apply` will ever change from the first ticket that writes it (#4): each listed package's enabled state, the Home activity, the three animation scales, the screensaver settings that replace Google's ambient mode with the Idle Screen, and whether the Launcher was installed. A field added by a later ticket would be missing on any TV that had already run `apply`.

Beside the Snapshot, the first `apply` also saves a full copy of the TV's global, secure and system settings, under the same write-once rule. The copies are a record for the owner to consult; `restore` reads only the Snapshot's own fields, so what it puts back is exactly what `apply` changed.
