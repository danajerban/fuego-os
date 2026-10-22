# Security Policy

fuego-os changes a TV over ADB, so problems in it matter. Thank you for reporting them privately.

## Supported versions

There are no releases yet. Once there are, only the latest release gets security fixes.

## What to report

For example:

- the script disabling a package that is not on the known-Bloat list, or one on the must-keep list;
- the script leaving ADB, Wireless debugging or a pairing open in a way it should not;
- `restore` failing to bring back what the Snapshot recorded;
- the Launcher reaching the network or doing work while it is off screen, other than its screensaver;
- the Snapshot or `probe` output exposing something private.

Report these to their own projects instead: Android, Google TV, the TV's firmware, and `adb` itself.

## How to report

Please don't open a public issue. Use GitHub's private reporting: the repository's **Security** tab, then **Report a vulnerability**. Say which version or commit it is, your TV's Android build, and how to make it happen.

If you can't use that, open an issue that only asks for a private contact, with no details in it.

## What happens next

The maintainer will reply as soon as they can. Once a fix is ready, it ships in a new release, and the release notes credit you unless you'd rather not be named.
