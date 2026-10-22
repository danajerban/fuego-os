# Glossary

**TV**: The one Fuego 2K Smart TV (Google TV, Android TV OS 14) this project targets. Single user. Performance is the top priority.

**Keep List**: The apps the owner chose to keep: Netflix, YouTube, Stremio, Spotify.

**Must-Keep List**: Everything that is never disabled: the Keep List apps plus the system parts they, the remote, HDMI inputs, casting and security updates depend on.

**Bloat**: Any preinstalled app or service on neither the Keep List nor the Must-Keep List that the TV can run without.

**Known-Bloat List**: The reviewed set of Bloat that Debloat actually disables. Bloat not on it is reported, never touched.

**Debloat**: Disabling the Known-Bloat List for the TV's user only, so a factory reset brings it back. It never deletes anything from the system partition.

**Stock Launcher**: The Google TV home screen that ships on the TV, the source of the ads and recommendation rows.

**Launcher**: The app that draws the home screen and opens when Home is pressed.

**Dock**: The Launcher's row of tiles: Netflix, YouTube, Stremio, Spotify, Inputs, Settings.

**Home Takeover**: Making the Launcher, not the Stock Launcher, what the remote's Home button opens. A separate step from installing the Launcher.

**Takeover Packages**: The Stock Launcher and the setup wizard. Only the Home Takeover disables them, because the setup wizard otherwise brings the Stock Launcher back.

**Snapshot**: The record of everything the script changes, taken once before the first change and never overwritten.

**Restore**: Putting the TV back to the Snapshot.

**Idle Screen**: The Launcher's dimmed artwork, set as the TV's screensaver in place of Google's ambient mode.
