# Helpers for the script's tests, sourced by script/tests/run inside each test's subshell.
#
# Every test starts with:
#   - a fresh fake TV in $FAKE_TV, paired and connected, holding the state below;
#   - FUEGO_ADB pointing at the fake TV, so the script's adb boundary talks to it;
#   - an empty HOME at $TEST_DIR/mac, standing in for the owner's Mac;
#   - an adb on PATH that fails the test if anything calls it instead of FUEGO_ADB;
#   - a fake GitHub in $FAKE_GITHUB with no release published, and FUEGO_FETCH pointing at it, so
#     the script's download boundary talks to it;
#   - a curl on PATH that fails the test if anything downloads outside FUEGO_FETCH.
#
# Fake TV state is plain files (see fake-adb for the layout). Use the fake_tv_* helpers below to
# shape it, and to read it back in assertions. The fake GitHub's layout is in fake-github, and the
# fake_github_* helpers shape it.

# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by the tests

FUEGO="$REPO/script/fuego"

# The fake TV's network address. The pairing port and the connect port differ, as on a real TV.
FAKE_TV_HOST=192.168.1.50
FAKE_TV_PAIR_ADDRESS="$FAKE_TV_HOST:37099"
FAKE_TV_ADDRESS="$FAKE_TV_HOST:41234"
FAKE_TV_PAIRING_CODE=482913

test_setup() {
  export HOME="$TEST_DIR/mac"
  mkdir -p "$HOME" "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/adb" <<EOF
#!/bin/bash
echo "real adb called with: \$*" >> "$TEST_DIR/real-adb-calls"
exit 99
EOF
  chmod +x "$TEST_DIR/bin/adb"
  cat > "$TEST_DIR/bin/curl" <<EOF
#!/bin/bash
echo "real curl called with: \$*" >> "$TEST_DIR/real-curl-calls"
exit 99
EOF
  chmod +x "$TEST_DIR/bin/curl"
  # Waiting for the TV (after a Home press) takes no time in tests.
  printf '#!/bin/sh\nexit 0\n' > "$TEST_DIR/bin/sleep"
  chmod +x "$TEST_DIR/bin/sleep"
  export PATH="$TEST_DIR/bin:$PATH"
  export FUEGO_ADB="$TESTS/fake-adb"
  export FUEGO_FETCH="$TESTS/fake-github"
  fake_tv_new
  fake_github_new
}

test_teardown() {
  if [ -f "$TEST_DIR/real-adb-calls" ]; then
    fail "adb was called outside the FUEGO_ADB boundary: $(cat "$TEST_DIR/real-adb-calls")"
  fi
  if [ -f "$TEST_DIR/real-curl-calls" ]; then
    fail "curl was called outside the FUEGO_FETCH boundary: $(cat "$TEST_DIR/real-curl-calls")"
  fi
}

fail() {
  printf 'FAIL: %s\n' "$*"
  exit 1
}

# --- Running the script --------------------------------------------------------------------

# run_fuego ARGS...: runs the script with no input; sets OUTPUT (stdout and stderr) and STATUS.
run_fuego() {
  OUTPUT=$("$FUEGO" "$@" 2>&1 < /dev/null)
  STATUS=$?
}

# run_fuego_answering INPUT ARGS...: same, with INPUT (one answer per line) on stdin.
run_fuego_answering() {
  local input=$1
  shift
  OUTPUT=$(printf '%s\n' "$input" | "$FUEGO" "$@" 2>&1)
  STATUS=$?
}

# with_list_entry FILE LINE: runs the script from a copy of the repo whose lists/FILE also has
# LINE, for list mistakes lists/check.sh would refuse (a package on two lists).
with_list_entry() {
  repo_copy
  printf '%s\n' "$2" >> "$TEST_DIR/repo/lists/$1"
}

# with_list FILE LINES: runs the script from a copy of the repo whose lists/FILE holds only LINES.
with_list() {
  repo_copy
  printf '%s\n' "$2" > "$TEST_DIR/repo/lists/$1"
}

# repo_copy: from now on, runs the script from a copy of the repo, whose lists a test may change.
repo_copy() {
  [ "$FUEGO" = "$REPO/script/fuego" ] || return 0
  mkdir -p "$TEST_DIR/repo/script"
  cp "$REPO/script/fuego" "$TEST_DIR/repo/script/fuego"
  cp -R "$REPO/lists" "$TEST_DIR/repo/lists"
  FUEGO="$TEST_DIR/repo/script/fuego"
}

# launcher_apk [VERSION_NAME VERSION_CODE [KEY]]: writes a fake Launcher APK and prints its path.
# The fake TV reads its "package=", "home=", "activity=" (an exported activity besides Home: the
# Inputs screen), "folder=" (the Launcher makes its Artwork Folder when it starts), "version=" and
# "key=" lines. The version defaults to 0.0.0 (versionCode 1) and the signing key to "release".
launcher_apk() {
  printf 'package=io.github.danajerban.fuegoos\nhome=io.github.danajerban.fuegoos/.HomeActivity\nactivity=io.github.danajerban.fuegoos/.InputsActivity\nfolder=files/artwork\nversion=%s %s\nkey=%s\n' \
    "${1:-0.0.0}" "${2:-1}" "${3:-release}" > "$TEST_DIR/launcher.apk"
  echo "$TEST_DIR/launcher.apk"
}

# The Snapshot apply keeps on the Mac (HOME is the test's own).
snapshot_file() {
  echo "$HOME/Library/Application Support/fuego-os/snapshot"
}

# The Check Step's answers, kept beside the Snapshot.
checks_file() {
  echo "$HOME/Library/Application Support/fuego-os/checks"
}

# --- Assertions ----------------------------------------------------------------------------

assert_status() {
  [ "$STATUS" -eq "$1" ] || fail "expected exit status $1, got $STATUS. Output:
$OUTPUT"
}

assert_output_contains() {
  case "$OUTPUT" in
    *"$1"*) ;;
    *) fail "expected the output to contain: $1
Output:
$OUTPUT" ;;
  esac
}

assert_output_lacks() {
  case "$OUTPUT" in
    *"$1"*) fail "expected the output not to contain: $1
Output:
$OUTPUT" ;;
  esac
}

assert_equals() {
  [ "$1" = "$2" ] || fail "${3:-values differ}: expected '$1', got '$2'"
}

assert_no_writes() {
  local writes
  writes=$(fake_tv_writes)
  [ -z "$writes" ] || fail "expected no write calls to the TV, got:
$writes"
}

# --- The fake TV ---------------------------------------------------------------------------

# fake_tv_new: a TV as it comes from the box, paired with and connected to the Mac.
# Package and component names are placeholders until probe confirms them on the real TV.
fake_tv_new() {
  export FAKE_TV="$TEST_DIR/tv"
  rm -rf "$FAKE_TV"
  mkdir -p "$FAKE_TV/packages" "$FAKE_TV/settings/global" "$FAKE_TV/settings/secure" \
    "$FAKE_TV/settings/system" "$FAKE_TV/props" "$FAKE_TV/sdcard" "$FAKE_TV/faults" "$FAKE_TV/link" \
    "$FAKE_TV/processes"
  : > "$FAKE_TV/calls"

  local pkg kind
  while read -r pkg kind; do
    fake_tv_install_package "$pkg" "$kind"
  done <<'EOF'
android system
com.android.location.fused system
com.android.tv.settings system
com.android.vending system
com.google.android.apps.mediashell system
com.google.android.apps.tv.dreamx system
com.google.android.apps.tv.launcherx system
com.google.android.gms system
com.google.android.gsf system
com.google.android.katniss system
com.google.android.tungsten.setupwraith system
com.google.android.tv system
com.google.android.tv.inputplayer system
com.google.android.tv.remote.service system
com.google.android.tvrecommendations system
com.google.android.youtube.tv system
com.netflix.ninja system
com.fuego.tv.otaupdater system
com.spotify.tv.android user
com.stremio.one user
EOF

  # The Stock Launcher outranks the setup wizard, which outranks any app the owner installs
  # (docs/research/android-tv-launchers.md section 2).
  cat > "$FAKE_TV/home-activities" <<'EOF'
com.google.android.apps.tv.launcherx/.home.HomeActivity 2
com.google.android.tungsten.setupwraith/.RecoveryActivity 1
EOF
  echo com.google.android.apps.tv.launcherx/.home.HomeActivity > "$FAKE_TV/focus"

  fake_tv_setting global window_animation_scale 1.0
  fake_tv_setting global transition_animation_scale 1.0
  # animator_duration_scale is unset (`settings get` prints null), as on an API 34 emulator.
  fake_tv_setting secure screensaver_enabled 1
  fake_tv_setting secure screensaver_components com.google.android.apps.tv.dreamx/.service.Backdrop

  fake_tv_prop ro.build.id UKNV.260529.001
  fake_tv_prop ro.build.version.release 14
  fake_tv_prop ro.product.model "FUEGO 2K SMART TV"
  fake_tv_prop ro.product.device GoogleTV8164

  fake_tv_memory 2025912 880436
  fake_tv_storage 10167132 565024 9454652
  fake_tv_home_draw_ms 1432

  echo "$FAKE_TV_PAIR_ADDRESS" > "$FAKE_TV/link/pair-address"
  echo "$FAKE_TV_ADDRESS" > "$FAKE_TV/link/address"
  echo "$FAKE_TV_PAIRING_CODE" > "$FAKE_TV/link/pairing-code"
  : > "$FAKE_TV/link/paired"
  echo "$FAKE_TV_ADDRESS" > "$FAKE_TV/link/connected"
}

# fake_tv_unpaired: the Mac has never paired with this TV and is not connected to it.
fake_tv_unpaired() {
  rm -f "$FAKE_TV/link/paired"
  : > "$FAKE_TV/link/connected"
}

# fake_tv_install_package PACKAGE [system|user] [enabled|disabled-user|disabled]
fake_tv_install_package() {
  printf '%s %s\n' "${3:-enabled}" "${2:-user}" > "$FAKE_TV/packages/$1"
}

# fake_tv_package_state PACKAGE: enabled, disabled-user, disabled, or "missing".
fake_tv_package_state() {
  local state kind
  if [ -f "$FAKE_TV/packages/$1" ]; then
    read -r state kind < "$FAKE_TV/packages/$1"
    echo "$state"
  else
    echo missing
  fi
}

# fake_tv_set_package_state PACKAGE STATE: as if something other than the script changed it,
# for example a TV update re-enabling a package.
fake_tv_set_package_state() {
  local state kind
  read -r state kind < "$FAKE_TV/packages/$1"
  printf '%s %s\n' "$2" "$kind" > "$FAKE_TV/packages/$1"
}

# fake_tv_setting NAMESPACE KEY [VALUE]: sets the value when given, prints it otherwise
# ("null" when unset, as `settings get` does).
fake_tv_setting() {
  if [ $# -ge 3 ]; then
    printf '%s\n' "$3" > "$FAKE_TV/settings/$1/$2"
  elif [ -f "$FAKE_TV/settings/$1/$2" ]; then
    cat "$FAKE_TV/settings/$1/$2"
  else
    echo null
  fi
}

fake_tv_prop() {
  printf '%s\n' "$2" > "$FAKE_TV/props/$1"
}

# fake_tv_memory TOTAL_KB AVAILABLE_KB: the RAM and the memory available, as the kernel reports.
fake_tv_memory() {
  printf '%s %s\n' "$1" "$2" > "$FAKE_TV/meminfo"
}

# fake_tv_storage TOTAL_KB USED_KB AVAILABLE_KB: the size of /data.
fake_tv_storage() {
  printf '%s %s %s\n' "$1" "$2" "$3" > "$FAKE_TV/storage"
}

# fake_tv_home_draw_ms MS: how long Home takes to draw when it is started or reopened.
fake_tv_home_draw_ms() {
  printf '%s\n' "$1" > "$FAKE_TV/home-draw-ms"
}

# fake_tv_launcher_is_home [APK]: as after the Home Takeover: the Launcher (the fake Launcher APK
# by default) installed, both Takeover Packages off, and the Launcher's Home on screen.
fake_tv_launcher_is_home() {
  FAKE_TV_INSPECT=1 "$TESTS/fake-adb" install -r "${1:-$(launcher_apk)}" > /dev/null
  fake_tv_set_package_state com.google.android.apps.tv.launcherx disabled-user
  fake_tv_set_package_state com.google.android.tungsten.setupwraith disabled-user
  FAKE_TV_INSPECT=1 "$TESTS/fake-adb" shell input keyevent KEYCODE_HOME
}

# fake_tv_process PACKAGE PSS_KB: the package is running and uses PSS_KB of memory.
fake_tv_process() {
  printf '%s\n' "$2" > "$FAKE_TV/processes/$1"
}

# fake_tv_home_activity COMPONENT PRIORITY: one more activity answers the Home intent.
fake_tv_home_activity() {
  [ -f "$FAKE_TV/packages/${1%%/*}" ] || fake_tv_install_package "${1%%/*}" system
  printf '%s %s\n' "$1" "$2" >> "$FAKE_TV/home-activities"
}

# fake_tv_home: the activity the Home button opens now. fake_tv_focus: the focused activity, or
# "null".
fake_tv_home() {
  # Inspecting is not logged and ignores faults, so the log holds only what the script did.
  FAKE_TV_INSPECT=1 "$TESTS/fake-adb" shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n 1
}

fake_tv_focus() {
  cat "$FAKE_TV/focus"
}

# fake_tv_sdcard_file PATH: the fake TV's copy of a file under /sdcard (PATH is relative to it).
fake_tv_sdcard_file() {
  echo "$FAKE_TV/sdcard/$1"
}

# fake_tv_fault NAME [TARGET]: makes the fake TV misbehave.
#   offline              the TV left the network: connect times out, every other call fails
#   debugging-off        Wireless debugging is off (a TV restart does this): connections refused
#   ignore-writes TARGET a write to TARGET answers as usual but changes nothing, so its read-back
#                        fails. TARGET is a package, NAMESPACE/KEY for a setting, "home" for the
#                        Home activity, "focus" for a Home press, or an /sdcard path.
#   offline-after TEXT   goes offline right after the first write call whose text contains TEXT
fake_tv_fault() {
  case "$1" in
    ignore-writes) printf '%s\n' "$2" >> "$FAKE_TV/faults/ignore-writes" ;;
    offline-after) printf '%s\n' "$2" > "$FAKE_TV/faults/offline-after" ;;
    *) : > "$FAKE_TV/faults/$1" ;;
  esac
}

# fake_tv_calls: every adb call so far, one per line, as "read ARGS" or "write ARGS".
# fake_tv_writes: only the write calls.
fake_tv_calls() {
  cat "$FAKE_TV/calls"
}

fake_tv_writes() {
  grep '^write ' "$FAKE_TV/calls"
}

# --- The fake GitHub -----------------------------------------------------------------------

# fake_github_new: the project's GitHub before any release is published.
fake_github_new() {
  export FAKE_GITHUB="$TEST_DIR/github"
  rm -rf "$FAKE_GITHUB"
  mkdir -p "$FAKE_GITHUB/releases"
  : > "$FAKE_GITHUB/calls"
}

# fake_github_release TAG [VERSION_CODE [KEY]]: publishes release TAG (vX.Y.Z) as the latest, with
# the fake Launcher APK and a SHA256SUMS listing its checksum, named as the release workflow names
# them. The APK's versionName is TAG without its "v", as the release workflow requires; its
# versionCode defaults to 1 and its signing key to "release".
fake_github_release() {
  local dir="$FAKE_GITHUB/releases/$1"
  mkdir -p "$dir"
  cp "$(launcher_apk "${1#v}" "${2:-1}" "${3:-release}")" "$dir/fuego-os-launcher-$1.apk"
  (cd "$dir" && shasum -a 256 "fuego-os-launcher-$1.apk") > "$dir/SHA256SUMS"
  printf '%s\n' "$1" > "$FAKE_GITHUB/latest"
}

# fake_github_asset TAG NAME: where release TAG keeps its asset NAME, to change it in a test.
fake_github_asset() {
  echo "$FAKE_GITHUB/releases/$1/$2"
}

# fake_github_offline: the Mac has no network, so every download fails.
fake_github_offline() {
  : > "$FAKE_GITHUB/offline"
}

# fake_github_calls: every URL the script downloaded so far, one per line.
fake_github_calls() {
  cat "$FAKE_GITHUB/calls"
}
