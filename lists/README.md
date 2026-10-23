# Package lists

The four package lists the script reads. [GLOSSARY.md](../GLOSSARY.md) defines each one.

| File | List | What the script does with it |
|---|---|---|
| `keep.txt` | Keep List | Nothing directly: every entry is also on the Must-Keep List |
| `must-keep.txt` | Must-Keep List | Never disables it. It wins over every other list |
| `known-bloat.txt` | Known-Bloat List | Debloat disables these, and only these |
| `takeover.txt` | Takeover Packages | Only the Home Takeover disables them |

A package on none of the lists is reported by `probe`, never disabled.

## Format

One entry per line, three fields separated by `|`, with no spaces around the `|`:

```
package|confirmed_on_tv|reason
com.google.android.katniss|false|Voice search (Katniss): the owner does not use voice
```

- `package`: the Android package name.
- `confirmed_on_tv`: `true` once `probe` output from the TV shows the package, `false` until then.
- `reason`: one line saying why the package is on this list.

Lines starting with `#` and blank lines are ignored.

Every entry starts as `false`: the IDs come from the research notes in `docs/research/` (or, where a comment says so, from general knowledge) and must be confirmed against `probe` output before the first release.

## The check

From the repo root:

```sh
lists/check.sh        # checks the lists; exits 1 and names each problem
lists/check_test.sh   # tests the check itself
```

The check fails when:

- a package is on both the Must-Keep List and the Known-Bloat List,
- a Takeover Package is on the Known-Bloat List,
- a Keep List app is missing from the Must-Keep List,
- an entry has a malformed package name, a `confirmed_on_tv` other than `true` or `false`, or no reason,
- a list file is missing.

Both scripts need only macOS `/bin/bash` (3.2) and standard tools.

## Proposing a Known-Bloat entry

Open an issue first, with:

1. the package name,
2. what it does,
3. the `probe` output that shows it on the TV,
4. why the TV can run without it.

A package that might affect the remote, casting, HDMI inputs, Wi-Fi, Play or system updates stays off the list.

Once the issue is agreed, the pull request adds one line to `known-bloat.txt` with `confirmed_on_tv` set to `true` (the `probe` output shows it), links the issue, and passes `lists/check.sh`.
