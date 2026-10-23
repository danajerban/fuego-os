# ADB only: no root, no firmware changes

fuego-os changes the TV only through what ADB allows a normal user, and everything it does is reversible. A custom ROM was ruled out: there is no public firmware for this TV and no known bootloader unlock, and unlocking would likely drop Widevine to L3 and fail Play Integrity (Netflix HD lost), with a real risk of bricking the TV. Sources: [fuego-tv-platform.md](../research/fuego-tv-platform.md) §2 and the spec's problem statement.
