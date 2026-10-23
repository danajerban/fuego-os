#!/usr/bin/env bash
# Tests the Launcher's merged-manifest check from the outside: a copy of launcher/ with a changed
# manifest in, the Gradle result out. It shows that adding the INTERNET permission fails the build
# that CI runs. Needs JDK 17 and the Android SDK (ANDROID_HOME), like any Launcher build.
# Run from anywhere: launcher/manifest_check_test.sh
# Works on macOS /bin/bash 3.2.

set -u

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/fuego-manifest-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

# A copy of launcher/ without its build outputs, so a test never touches the real tree.
fresh() {
  d="$work/$1"
  mkdir -p "$d"
  (cd "$here" && tar --exclude=build --exclude=.gradle --exclude=.kotlin -cf - .) | (cd "$d" && tar -xf -)
  echo "$d"
}

# Adds a uses-permission line right after the <manifest> tag of the Launcher's own manifest.
add_permission() {
  dir=$1 permission=$2
  manifest="$dir/app/src/main/AndroidManifest.xml"
  awk -v p="$permission" '
    { print }
    /^<manifest / { printf "    <uses-permission android:name=\"%s\" />\n", p }
  ' "$manifest" >"$manifest.new" && mv "$manifest.new" "$manifest"
  grep -qF "android:name=\"$permission\"" "$manifest"
}

# run_check NAME DIR EXPECTED_EXIT [EXPECTED_TEXT]
run_check() {
  name=$1 dir=$2 want_exit=$3 want_text=${4:-}
  out=$("$dir/gradlew" -p "$dir" --console=plain --continue \
    :app:checkDebugLauncherManifest :app:checkReleaseLauncherManifest 2>&1)
  got_exit=$?
  if [ "$got_exit" -ne "$want_exit" ]; then
    echo "FAIL $name: exit $got_exit, want $want_exit"
    printf '%s\n' "$out" | tail -n 30 | sed 's/^/    /'
    failed=$((failed + 1))
    return
  fi
  if [ -n "$want_text" ] && ! printf '%s\n' "$out" | grep -qF -- "$want_text"; then
    echo "FAIL $name: output lacks \"$want_text\""
    printf '%s\n' "$out" | tail -n 30 | sed 's/^/    /'
    failed=$((failed + 1))
    return
  fi
  echo "ok   $name"
  passed=$((passed + 1))
}

d=$(fresh unchanged)
run_check "the Launcher's manifest as it is passes" "$d" 0

d=$(fresh internet)
add_permission "$d" android.permission.INTERNET
run_check "adding the INTERNET permission fails the build" "$d" 1 "has the INTERNET permission"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
