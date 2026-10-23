# Glossary

## The TV and its packages

**TV**: The one Fuego 2K Smart TV (Google TV, Android TV OS 14) this project targets. Single user. Performance is the top priority.

**Owner**: The one person who uses the TV and runs the script from their Mac.

**Keep List**: The apps the owner chose to keep: Netflix, YouTube, Stremio, Spotify.

**Must-Keep List**: Everything that is never disabled: the Keep List apps plus the system parts they, the remote, HDMI inputs, casting and security updates depend on.

**Bloat**: Any preinstalled app or service on neither the Keep List nor the Must-Keep List that the TV can run without.

**Known-Bloat List**: The reviewed set of Bloat that Debloat actually disables. Bloat not on it is reported, never touched.

**Unlisted Package**: An installed package on none of the four lists (Keep List, Must-Keep List, Known-Bloat List, Takeover Packages). Reported for review, never disabled.

**Debloat**: Disabling the Known-Bloat List for the TV's user only, so a factory reset brings it back. It never deletes anything from the system partition.

## Taking over Home

**Stock Launcher**: The Google TV home screen that ships on the TV, the source of the ads and recommendation rows.

**Launcher**: The app that draws the home screen and opens when Home is pressed.

**Home Takeover**: Making the Launcher, not the Stock Launcher, what the remote's Home button opens. A separate step from installing the Launcher.

**Takeover Packages**: The Stock Launcher and the setup wizard. Only the Home Takeover disables them, because the setup wizard otherwise brings the Stock Launcher back.

**Check Step**: The part of `apply`, after the Home Takeover, that walks the owner through testing casting, HDMI inputs, Wi-Fi and the remote's Netflix and YouTube buttons, and records the answers.

**Casting Fallback**: Re-enabling the setup wizard alone when the owner reports casting broken after the Home Takeover. The Stock Launcher stays disabled.

## Changing and undoing

**Snapshot**: The record of everything the script changes, taken once before the first change and never overwritten.

**Restore**: Putting the TV back to the Snapshot.

**Dry-Run**: A run of `apply` that lists what would change and writes nothing, on the TV or the Mac.

**Read-Back**: Reading a value from the TV right after writing it, to confirm the write took. A mismatch is a failure.

**Speed Settings**: The window, transition and animator animation scales at 0.5×.

**Measurements**: The numbers `probe` reports and `apply` prints before and after: available memory, Home Draw Time and the Launcher's memory.

**Home Draw Time**: How long Home takes to draw when the owner comes back to it from another screen, as the TV's activity manager times it. The script measures it once the Launcher is Home, coming back from the Launcher's Inputs screen.

## The Launcher

**Dock**: The Launcher's row of tiles: Netflix, YouTube, Stremio, Spotify, Inputs, Settings.

**Tile**: One entry in the Dock. An app's tile is hidden while that app is not on the TV.

**Inputs**: The Dock tile that lists the TV's HDMI inputs by name and switches to the one chosen.

**Artwork**: The full-screen pictures behind the Dock and on the Idle Screen: the owner's pictures when there are any, otherwise Ember.

**Artwork Folder**: The place in the Launcher's own storage on the TV where the script copies the owner's pictures.

**Ember**: The Launcher's own artwork, a dark plum gradient with purple, crimson and orange glows, drawn in code: still on Home, slowly moving on the Idle Screen.

**Idle Screen**: The Launcher's dimmed artwork, set as the TV's screensaver in place of Google's ambient mode.

## Testing

**Fake TV**: A stand-in for the TV in the script's tests. It holds package states, the Home activity, focus and settings, and answers the same `adb` calls a real TV does.

**ADB Boundary**: The single point through which the script talks to the TV, which tests point at the Fake TV.

**Download Boundary**: The single point through which the script downloads anything (the Launcher from the latest release), which tests point at the Fake GitHub.

**Fake GitHub**: A stand-in for the project's GitHub Releases in the script's tests. It holds the releases and their files, and answers downloads as `curl` does.

**Fake Dock App**: A tiny test app carrying the package name of one Dock app, installed on the emulator so the Launcher's tests can open it.

**Fake TV Inputs**: Test apps standing in for the TV's HDMI inputs and its TV input player, installed on the emulator (which has neither) so the Launcher's tests can list inputs and open one.
