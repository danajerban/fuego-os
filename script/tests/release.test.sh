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

test_apply_with_the_launcher_already_on_the_tv_downloads_nothing() {
  fake_github_release v0.2.0
  fake_tv_install_package "$LAUNCHER" user
  fake_tv_home_activity "$LAUNCHER_HOME" 0
  run_fuego_answering yes apply
  assert_status 0
  assert_output_contains "unchanged    $LAUNCHER already installed"
  assert_equals "" "$(fake_github_calls)" "downloads"
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
