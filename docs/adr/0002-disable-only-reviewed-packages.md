# Debloat disables, for the TV's user only, and only the Known-Bloat List

Debloat uses `pm disable-user --user 0` and nothing else: no `pm uninstall`, nothing on the system partition. A disabled package comes back with `pm enable` or a factory reset, so the TV can always be put back. Only packages on the reviewed Known-Bloat List are disabled; the Must-Keep List wins over every other list, and Unlisted Packages are reported, never disabled.

The reason is that a wrong guess is costly on this kind of TV: disabling the remote service breaks the remote, and disabling fused location has been reported to boot-loop the TV ([fuego-tv-platform.md](../research/fuego-tv-platform.md) §3). A Fuego update can also add packages nobody has reviewed (spec, user story 8).
