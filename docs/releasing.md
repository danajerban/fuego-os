# Releasing

For the owner. A pushed tag `vX.Y.Z` runs [`.github/workflows/release.yml`](../.github/workflows/release.yml), which publishes a GitHub Release with:

- `fuego-os-launcher-vX.Y.Z.apk`: the Launcher, built with R8 and signed with the release key;
- `fuego-os-launcher-vX.Y.Z.apk.idsig`: apksigner's v4 signature of the APK, for incremental installs; `fuego apply` doesn't need it;
- `fuego-os-vX.Y.Z.tar.gz`: the script, the package lists beside it, the TV setup steps, the README and the licence;
- `SHA256SUMS`: the SHA-256 checksum of all three.

`fuego apply` downloads the APK from the latest release and installs it only if it matches its line in `SHA256SUMS`. With the Launcher already on the TV, it installs the release only when the tag's version is higher than the installed `versionName`, so a rerun never reinstalls the same Launcher ([launcher-updates.md](research/launcher-updates.md)). The notes are generated from the merged pull requests, grouped by label as [`.github/release.yml`](../.github/release.yml) says.

## The signing key

Android installs an update to the Launcher only when it is signed with the same key as the copy on the TV. Lose the key and the next Launcher can't replace the installed one: it has to be uninstalled first (`fuego restore`, then `fuego apply`). So the key is made once, kept in your macOS keychain, and given to GitHub as two Actions secrets. It is never committed, and the workflow never prints it.

| Secret | What it holds |
| --- | --- |
| `RELEASE_KEYSTORE_BASE64` | The PKCS12 keystore, base64-encoded. It holds one key, under the alias `fuego-os`. |
| `RELEASE_KEYSTORE_PASSWORD` | The keystore's password (in PKCS12 it is also the key's). |

Only the tag build reads them. Pull requests and manual runs sign with a throwaway key (below).

### Make the key (once)

On the Mac, with JDK 17's `keytool` (`brew install openjdk@17`) and `gh` signed in:

```sh
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
cd "$(mktemp -d)"

# 1. Choose the keystore password. -w last makes `security` prompt for it, so it stays out of the
#    shell history.
security add-generic-password -a fuego-os -s fuego-os-release-password -w

# 2. Make the key, reading the password back from the keychain.
FUEGO_RELEASE_PASSWORD=$(security find-generic-password -a fuego-os -s fuego-os-release-password -w) \
  keytool -genkeypair -keystore fuego-os-release.p12 -storetype PKCS12 \
  -storepass:env FUEGO_RELEASE_PASSWORD -alias fuego-os -keyalg RSA -keysize 4096 \
  -validity 10000 -dname "CN=fuego-os"

# 3. Keep the keystore in the keychain too, base64-encoded.
security add-generic-password -a fuego-os -s fuego-os-release-keystore -w "$(base64 -i fuego-os-release.p12)"

# 4. Give both to GitHub, straight from the keychain.
security find-generic-password -a fuego-os -s fuego-os-release-keystore -w | tr -d '\n' |
  gh secret set RELEASE_KEYSTORE_BASE64 --repo danajerban/fuego-os
security find-generic-password -a fuego-os -s fuego-os-release-password -w | tr -d '\n' |
  gh secret set RELEASE_KEYSTORE_PASSWORD --repo danajerban/fuego-os

# 5. Remove the file: the keychain holds the copy.
rm fuego-os-release.p12
```

Step 3 puts the encoded keystore on a command line for a moment; on a Mac only you use, that is fine. Keep a second copy somewhere safe as well (a password manager, or an encrypted backup of your keychain): the keychain item is the only way to sign updates to the Launcher already on the TV.

To get the keystore back as a file (to rotate the secrets, say):

```sh
security find-generic-password -a fuego-os -s fuego-os-release-keystore -w | base64 --decode > fuego-os-release.p12
```

## Making a release

1. In `launcher/app/build.gradle.kts`, set `versionName` to `X.Y.Z` and raise `versionCode` by one. The workflow stops if the tag and `versionName` differ.
2. In `CHANGELOG.md`, move the Unreleased entries under `## [X.Y.Z]` with today's date.
3. Merge that to `main`, then tag the merge commit and push the tag:

   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

4. The Release workflow builds, signs, bundles, writes `SHA256SUMS` and runs `gh release create --generate-notes`. Check the release page, then try `fuego apply --dry-run`: it names the release it would install from.

## Dry run

A pull request that changes the workflow runs it as a dry run, and so does **Run workflow** on the Release workflow's page in the Actions tab (or `gh workflow run release.yml --ref BRANCH`, once the workflow is on `main`). A dry run does everything a release does but publish: it makes a throwaway key in the job, signs with it, and keeps the APK, bundle and `SHA256SUMS` as the workflow artifact `release-v0.0.0-dry-run`. It reads no secrets and creates no tag or release.
