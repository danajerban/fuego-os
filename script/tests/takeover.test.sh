# apply's Launcher install and Home Takeover: install first, take over Home as a separate step,
# wait for the owner's yes, check focus and roll back, redo after a TV update, keep the way back.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

LAUNCHER=io.github.danajerban.fuegoos
LAUNCHER_HOME=io.github.danajerban.fuegoos/.HomeActivity
STOCK_LAUNCHER=com.google.android.apps.tv.launcherx
SETUP_WIZARD=com.google.android.tungsten.setupwraith
STOCK_HOME=com.google.android.apps.tv.launcherx/.home.HomeActivity

# takeover_writes: the write calls that install the Launcher, choose Home, press Home or touch a
# Takeover Package, in order.
takeover_writes() {
  fake_tv_writes | grep -e ' install ' -e set-home-activity -e keyevent -e "$STOCK_LAUNCHER" \
    -e "$SETUP_WIZARD" -e ' uninstall '
}

# home_state: what the Home button depends on: the Takeover Packages, the chosen Home, and what
# Home opens.
home_state() {
  printf '%s %s\n' "$STOCK_LAUNCHER" "$(fake_tv_package_state "$STOCK_LAUNCHER")"
  printf '%s %s\n' "$SETUP_WIZARD" "$(fake_tv_package_state "$SETUP_WIZARD")"
  printf 'role %s\n' "$(FAKE_TV_INSPECT=1 "$FUEGO_ADB" shell cmd role get-role-holders --user 0 android.app.role.HOME)"
  printf 'home %s\n' "$(fake_tv_home)"
}

test_takeover_installs_the_launcher_first_then_takes_over_home_as_its_own_step() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals "write install -r $TEST_DIR/launcher.apk
write shell cmd package set-home-activity $LAUNCHER_HOME
write shell pm disable-user --user 0 $SETUP_WIZARD
write shell pm disable-user --user 0 $STOCK_LAUNCHER
write shell input keyevent KEYCODE_HOME" "$(takeover_writes)" "Launcher and Home Takeover writes"
  assert_equals enabled "$(fake_tv_package_state "$LAUNCHER")"
  assert_equals disabled-user "$(fake_tv_package_state "$STOCK_LAUNCHER")"
  assert_equals disabled-user "$(fake_tv_package_state "$SETUP_WIZARD")"
  assert_equals "$LAUNCHER_HOME" "$(fake_tv_home)"
  assert_equals "$LAUNCHER_HOME" "$(fake_tv_focus)"
  assert_output_contains "installed    $LAUNCHER from $TEST_DIR/launcher.apk"
  assert_output_contains "changed      Home activity -> $LAUNCHER_HOME"
  assert_output_contains "disabled     $SETUP_WIZARD"
  assert_output_contains "checked      a Home press opens the Launcher ($LAUNCHER_HOME)"
  assert_output_contains "checked      the TV is still on the network"
  assert_output_lacks "  $LAUNCHER
"
}

test_takeover_disables_no_takeover_package_without_the_owners_yes() {
  local answer
  for answer in "" no y; do
    fake_tv_new
    run_fuego_answering "$answer" apply --launcher "$(launcher_apk)"
    assert_status 0
    assert_output_contains "Disabling the setup wizard can delete the Wi-Fi network"
    assert_output_contains "not done     Home Takeover: no yes from the owner"
    assert_equals "" "$(fake_tv_writes | grep -e "$STOCK_LAUNCHER" -e "$SETUP_WIZARD")" \
      "Takeover Package writes after the answer '$answer'"
    assert_equals enabled "$(fake_tv_package_state "$SETUP_WIZARD")"
    assert_equals "$STOCK_HOME" "$(fake_tv_home)"
  done
}

test_takeover_without_the_launcher_is_not_done() {
  run_fuego_answering yes apply
  assert_status 0
  assert_output_contains "not done     Launcher: not on the TV, and no APK given (fuego apply --launcher APK)"
  assert_output_contains "not done     Home Takeover: the Launcher is not on the TV"
  assert_equals "" "$(takeover_writes)" "Launcher and Home Takeover writes"
}

test_takeover_uses_a_launcher_already_on_the_tv() {
  fake_tv_install_package "$LAUNCHER" user
  fake_tv_home_activity "$LAUNCHER_HOME" 0
  run_fuego_answering yes apply
  assert_status 0
  assert_output_contains "unchanged    $LAUNCHER already installed"
  assert_equals "$LAUNCHER_HOME" "$(fake_tv_home)"
}

test_takeover_stops_when_the_launcher_does_not_install() {
  echo junk > "$TEST_DIR/junk.apk"
  run_fuego_answering yes apply --launcher "$TEST_DIR/junk.apk"
  assert_status 1
  assert_output_contains "failed       $LAUNCHER (not installed from $TEST_DIR/junk.apk: adb: failed to install"
  assert_output_contains "not done     Home Takeover: the Launcher is not on the TV"
  assert_equals "write install -r $TEST_DIR/junk.apk" "$(takeover_writes)" "Launcher and Home Takeover writes"
}

test_apply_refuses_a_launcher_apk_that_is_not_there() {
  run_fuego apply --launcher "$TEST_DIR/no-such.apk"
  assert_status 2
  assert_output_contains "No Launcher APK at $TEST_DIR/no-such.apk"
  assert_equals "" "$(fake_tv_calls)" "calls to the TV"
}

test_takeover_rolls_back_when_home_does_not_open_the_launcher() {
  home_state > "$TEST_DIR/before"
  fake_tv_fault ignore-writes focus
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 1
  assert_output_contains "failed       Home Takeover: a Home press opened null, not the Launcher"
  assert_output_contains "enabled      $STOCK_LAUNCHER"
  assert_output_contains "enabled      $SETUP_WIZARD"
  assert_output_contains "changed      Home activity -> $STOCK_HOME"
  home_state > "$TEST_DIR/after"
  diff "$TEST_DIR/before" "$TEST_DIR/after" || fail "the rollback did not put Home back as it was"
  # Re-enabled in the reverse order: the Stock Launcher first, so Home never lands on the wizard.
  assert_equals "write shell pm enable $STOCK_LAUNCHER
write shell pm enable $SETUP_WIZARD" "$(fake_tv_writes | grep 'pm enable')" "re-enables"
}

test_takeover_rolls_back_when_a_takeover_package_stays_on() {
  home_state > "$TEST_DIR/before"
  fake_tv_fault ignore-writes "$STOCK_LAUNCHER"
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 1
  assert_output_contains "failed       $STOCK_LAUNCHER (still enabled after pm disable-user)"
  assert_output_contains "enabled      $SETUP_WIZARD"
  home_state > "$TEST_DIR/after"
  diff "$TEST_DIR/before" "$TEST_DIR/after" || fail "the rollback did not put Home back as it was"
}

test_apply_again_finds_the_takeover_in_place_and_asks_nothing() {
  # yes to the Wi-Fi warning, then the four checks answered.
  run_fuego_answering "$(printf 'yes\nyes\nyes\nyes\nyes')" apply --launcher "$(launcher_apk)"
  assert_status 0
  : > "$FAKE_TV/calls"
  run_fuego apply
  assert_status 0
  assert_no_writes
  assert_output_contains "unchanged    Home opens the Launcher ($LAUNCHER_HOME)"
  assert_output_lacks "Disabling the setup wizard"
  assert_output_lacks "Check Step"
}

test_apply_redoes_the_takeover_after_a_tv_update_re_enables_the_stock_launcher() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  fake_tv_set_package_state "$STOCK_LAUNCHER" enabled # as a TV update might do
  : > "$FAKE_TV/calls"
  run_fuego_answering yes apply
  assert_status 0
  assert_output_contains "Home opens $STOCK_HOME, not the Launcher"
  assert_output_contains "unchanged    Home activity already $LAUNCHER_HOME"
  assert_equals "write shell pm disable-user --user 0 $STOCK_LAUNCHER
write shell input keyevent KEYCODE_HOME" "$(takeover_writes)" "Home Takeover writes"
  assert_equals "$LAUNCHER_HOME" "$(fake_tv_home)"
  assert_equals "$LAUNCHER_HOME" "$(fake_tv_focus)"
}

test_takeover_that_loses_the_network_gives_the_reconnect_and_restore_steps() {
  fake_tv_fault offline-after "pm disable-user --user 0 $STOCK_LAUNCHER"
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 1
  assert_output_contains "failed       $STOCK_LAUNCHER (no answer from the TV after pm disable-user)"
  assert_output_lacks "still missing"
  assert_output_contains "The TV can't be reached since the Home Takeover (error: device offline)."
  assert_output_contains "Settings > Network & Internet"
  assert_output_contains "Settings > System > Developer options > Wireless debugging"
  assert_output_contains "fuego connect IP:PORT"
  assert_output_contains "fuego restore"
}

test_takeover_dry_run_lists_every_step_and_writes_nothing_anywhere() {
  mkdir -p "$TEST_DIR/cwd" "$TEST_DIR/tmp"
  cd "$TEST_DIR/cwd" || fail "can't enter $TEST_DIR/cwd"
  export TMPDIR="$TEST_DIR/tmp"
  launcher_apk > /dev/null
  cp -R "$FAKE_TV" "$TEST_DIR/tv-before"
  run_fuego_answering yes apply --dry-run --launcher "$TEST_DIR/launcher.apk"
  assert_status 0
  assert_output_contains "would install $LAUNCHER from $TEST_DIR/launcher.apk"
  assert_output_contains "would set    Home activity -> $LAUNCHER_HOME"
  assert_output_contains "would ask    the owner's yes to the Wi-Fi warning"
  assert_output_contains "would disable $SETUP_WIZARD"
  assert_output_contains "would disable $STOCK_LAUNCHER"
  assert_output_contains "would check  a Home press opens the Launcher"
  assert_equals "" "$(fake_tv_calls | grep -v '^read ')" "calls other than reads"
  rm "$FAKE_TV/calls" "$TEST_DIR/tv-before/calls"
  diff -r "$TEST_DIR/tv-before" "$FAKE_TV" || fail "the dry run changed the TV"
  assert_equals "" "$(find "$HOME" "$TEST_DIR/cwd" "$TMPDIR" -mindepth 1)" "files written on the Mac"
}
