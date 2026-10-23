# apply's Launcher from the latest GitHub Release: downloaded through the FUEGO_FETCH boundary,
# checked against the release's SHA256SUMS before it reaches the TV, overridden by --launcher.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

LAUNCHER=io.github.danajerban.fuegoos
LAUNCHER_HOME=io.github.danajerban.fuegoos/.HomeActivity
RELEASES=https://github.com/danajerban/fuego-os/releases

test_apply_installs_the_launcher_from_the_latest_release() {
  fake_github_release v0.2.0
  run_fuego_answering yes apply
  assert_status 0
  assert_equals "https://api.github.com/repos/danajerban/fuego-os/releases/latest
$RELEASES/download/v0.2.0/SHA256SUMS
$RELEASES/download/v0.2.0/fuego-os-launcher-v0.2.0.apk" "$(fake_github_calls)" "downloads"
  assert_output_contains "installed    $LAUNCHER from release v0.2.0"
  assert_equals enabled "$(fake_tv_package_state "$LAUNCHER")"
  assert_equals "$LAUNCHER_HOME" "$(fake_tv_home)"
}

test_apply_refuses_a_release_apk_whose_checksum_does_not_match() {
  fake_github_release v0.2.0
  echo "not the Launcher the checksum was written for" \
    >> "$(fake_github_asset v0.2.0 fuego-os-launcher-v0.2.0.apk)"
  run_fuego_answering yes apply
  assert_status 1
  assert_output_contains "failed       $LAUNCHER (fuego-os-launcher-v0.2.0.apk from release v0.2.0 does not match its checksum in SHA256SUMS, so it was not installed)"
  assert_output_contains "not done     Home Takeover: the Launcher is not on the TV"
  assert_equals "" "$(fake_tv_writes | grep -e ' install ' -e set-home-activity)" "install and Home writes"
  assert_equals missing "$(fake_tv_package_state "$LAUNCHER")"
}

test_apply_refuses_a_release_apk_without_a_checksum() {
  fake_github_release v0.2.0
  echo "0000000000000000000000000000000000000000000000000000000000000000  fuego-os-v0.2.0.tar.gz" \
    > "$(fake_github_asset v0.2.0 SHA256SUMS)"
  run_fuego_answering yes apply
  assert_status 1
  assert_output_contains "failed       $LAUNCHER (fuego-os-launcher-v0.2.0.apk from release v0.2.0 has no checksum in SHA256SUMS, so it was not installed)"
  assert_equals "" "$(fake_tv_writes | grep ' install ')" "install writes"
}

test_apply_removes_the_downloaded_launcher_from_the_mac() {
  mkdir -p "$TEST_DIR/tmp"
  export TMPDIR="$TEST_DIR/tmp"
  fake_github_release v0.2.0
  run_fuego_answering yes apply
  assert_status 0
  assert_equals "" "$(find "$TMPDIR" -mindepth 1)" "files left in TMPDIR"
}

test_apply_with_a_local_launcher_apk_downloads_nothing() {
  fake_github_release v0.2.0
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_output_contains "installed    $LAUNCHER from $TEST_DIR/launcher.apk"
  assert_equals "" "$(fake_github_calls)" "downloads"
}

# An earlier apply installed Launcher 0.1.0 (versionCode 2) and took over Home.
launcher_0_1_0_in_place() {
  run_fuego_answering yes apply --skip-checks --launcher "$(launcher_apk 0.1.0 2)"
  assert_status 0
  : > "$FAKE_TV/calls"
}

# tv_launcher_version: the Launcher's versionName as the TV reports it.
tv_launcher_version() {
  FAKE_TV_INSPECT=1 "$FUEGO_ADB" shell dumpsys package "$LAUNCHER" | sed -n 's/^ *versionName=//p'
}

API=https://api.github.com/repos/danajerban/fuego-os/releases/latest

test_apply_updates_the_launcher_to_a_newer_release() {
  launcher_0_1_0_in_place
  fake_github_release v0.2.0 3
  run_fuego apply --skip-checks
  assert_status 0
  assert_output_contains "installed    $LAUNCHER 0.1.0 -> 0.2.0 from release v0.2.0"
  assert_equals "$API
$RELEASES/download/v0.2.0/SHA256SUMS
$RELEASES/download/v0.2.0/fuego-os-launcher-v0.2.0.apk" "$(fake_github_calls)" "downloads"
  assert_equals 0.2.0 "$(tv_launcher_version)"
  # The update keeps the Home Takeover and the Idle Screen, and apply finds them in place.
  assert_output_contains "unchanged    Home opens the Launcher ($LAUNCHER_HOME)"
  assert_output_contains "unchanged    screensaver_components already $LAUNCHER/.IdleScreen"
}

test_apply_leaves_the_launcher_at_the_latest_release() {
  launcher_0_1_0_in_place
  fake_github_release v0.1.0 2
  run_fuego apply --skip-checks
  assert_status 0
  assert_output_contains "unchanged    $LAUNCHER 0.1.0 already the latest release (v0.1.0)"
  assert_equals "$API" "$(fake_github_calls)" "downloads"
  assert_equals "" "$(fake_tv_writes | grep ' install ')" "install writes"
}

test_apply_leaves_a_launcher_newer_than_the_latest_release() {
  run_fuego_answering yes apply --skip-checks --launcher "$(launcher_apk 0.10.0 11)"
  : > "$FAKE_TV/calls"
  fake_github_release v0.9.0 10
  run_fuego apply --skip-checks
  assert_status 0
  assert_output_contains "unchanged    $LAUNCHER 0.10.0 is newer than the latest release (v0.9.0), so it is left as it is"
  assert_equals "$API" "$(fake_github_calls)" "downloads"
  assert_equals 0.10.0 "$(tv_launcher_version)"
}

test_apply_offline_keeps_the_installed_launcher_and_carries_on() {
  launcher_0_1_0_in_place
  fake_github_release v0.2.0 3
  fake_github_offline
  run_fuego apply --skip-checks
  assert_status 0
  assert_output_contains "unchanged    $LAUNCHER 0.1.0 installed; couldn't check for a newer release (curl: (6) Could not resolve host: api.github.com)"
  assert_output_contains "unchanged    Home opens the Launcher ($LAUNCHER_HOME)"
  assert_output_contains "Idle Screen"
  assert_equals 0.1.0 "$(tv_launcher_version)"
}

test_apply_dry_run_names_the_launcher_update_and_downloads_nothing() {
  launcher_0_1_0_in_place
  fake_github_release v0.2.0 3
  run_fuego apply --dry-run
  assert_status 0
  assert_output_contains "would install $LAUNCHER 0.1.0 -> 0.2.0 from release v0.2.0"
  assert_equals "$API" "$(fake_github_calls)" "downloads"
  assert_no_writes
  assert_equals 0.1.0 "$(tv_launcher_version)"
}

test_apply_reports_a_launcher_update_the_tv_refuses() {
  launcher_0_1_0_in_place
  fake_github_release v0.2.0 3 another-key
  run_fuego apply --skip-checks
  assert_status 1
  assert_output_contains "failed       $LAUNCHER (not updated 0.1.0 -> 0.2.0 from release v0.2.0: adb: failed to install"
  assert_output_contains "INSTALL_FAILED_UPDATE_INCOMPATIBLE"
  assert_output_contains "The release is signed with another key than the Launcher on the TV: run fuego restore, then fuego apply (docs/releasing.md)."
  # The Launcher that is there stays, and the rest of apply goes on with it.
  assert_equals 0.1.0 "$(tv_launcher_version)"
  assert_output_contains "unchanged    Home opens the Launcher ($LAUNCHER_HOME)"
}

test_apply_without_a_release_leaves_the_launcher_not_done() {
  run_fuego_answering yes apply
  assert_status 0
  assert_output_contains "not done     Launcher: not on the TV, and no release to install it from at $RELEASES (curl: (22) The requested URL returned error: 404). Give an APK instead: fuego apply --launcher APK"
  assert_output_contains "not done     Home Takeover: the Launcher is not on the TV"
  assert_equals "" "$(fake_tv_writes | grep -e ' install ' -e set-home-activity)" "install and Home writes"
}

test_apply_without_network_leaves_the_launcher_not_done() {
  fake_github_release v0.2.0
  fake_github_offline
  run_fuego_answering yes apply
  assert_status 0
  assert_output_contains "not done     Launcher: not on the TV, and no release to install it from at $RELEASES (curl: (6) Could not resolve host: api.github.com)"
  assert_equals "" "$(fake_tv_writes | grep -e ' install ' -e set-home-activity)" "install and Home writes"
}

test_apply_reports_a_release_without_its_launcher_apk_as_failed() {
  fake_github_release v0.2.0
  rm "$(fake_github_asset v0.2.0 fuego-os-launcher-v0.2.0.apk)"
  run_fuego_answering yes apply
  assert_status 1
  assert_output_contains "failed       $LAUNCHER (can't download fuego-os-launcher-v0.2.0.apk and its checksum from release v0.2.0: curl: (22) The requested URL returned error: 404)"
  assert_equals "" "$(fake_tv_writes | grep ' install ')" "install writes"
}

test_apply_dry_run_names_the_release_and_downloads_no_launcher() {
  mkdir -p "$TEST_DIR/cwd" "$TEST_DIR/tmp"
  cd "$TEST_DIR/cwd" || fail "can't enter $TEST_DIR/cwd"
  export TMPDIR="$TEST_DIR/tmp"
  fake_github_release v0.2.0
  run_fuego_answering yes apply --dry-run
  assert_status 0
  assert_output_contains "would install $LAUNCHER from release v0.2.0"
  assert_output_contains "would set    Home activity -> $LAUNCHER_HOME"
  assert_equals "https://api.github.com/repos/danajerban/fuego-os/releases/latest" \
    "$(fake_github_calls)" "downloads"
  assert_equals "" "$(fake_tv_calls | grep -v '^read ')" "calls other than reads"
  assert_equals "" "$(find "$HOME" "$TEST_DIR/cwd" "$TMPDIR" -mindepth 1)" "files written on the Mac"
}
