# apply's Idle Screen and artwork: the Launcher's dream as the screensaver in place of Google's
# ambient mode, the owner's pictures copied to the Artwork Folder, and restore putting the
# screensaver back.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

IDLE_SCREEN=io.github.danajerban.fuegoos/.IdleScreen
AMBIENT_MODE=com.google.android.apps.tv.dreamx/.service.Backdrop

# settings_writes: the write calls that change a setting, in order.
settings_writes() {
  fake_tv_writes | grep ' settings '
}

test_apply_sets_the_idle_screen_as_the_screensaver_in_place_of_ambient_mode() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals "$IDLE_SCREEN" "$(fake_tv_setting secure screensaver_components)" screensaver_components
  assert_equals 1 "$(fake_tv_setting secure screensaver_enabled)" screensaver_enabled
  assert_output_contains "changed      screensaver_components $AMBIENT_MODE -> $IDLE_SCREEN"
  assert_output_contains "unchanged    screensaver_enabled already 1"
}

test_apply_switches_the_screensaver_on_and_never_writes_the_idle_timeout() {
  fake_tv_setting secure screensaver_enabled 0
  fake_tv_setting secure screensaver_activate_on_sleep 0
  fake_tv_setting secure sleep_timeout 1800000
  fake_tv_setting system screen_off_timeout 600000
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals "write shell settings put global window_animation_scale 0.5
write shell settings put global transition_animation_scale 0.5
write shell settings put global animator_duration_scale 0.5
write shell settings put secure screensaver_components $IDLE_SCREEN
write shell settings put secure screensaver_enabled 1" "$(settings_writes)" "settings writes"
  assert_equals 600000 "$(fake_tv_setting system screen_off_timeout)" screen_off_timeout
  assert_output_contains "changed      screensaver_enabled 0 -> 1"
}

test_apply_without_the_launcher_leaves_the_screensaver_alone() {
  run_fuego apply
  assert_status 0
  assert_output_contains "not done     Idle Screen: the Launcher is not on the TV"
  assert_equals "" "$(settings_writes | grep screensaver)" "screensaver writes"
  assert_equals "$AMBIENT_MODE" "$(fake_tv_setting secure screensaver_components)"
}

test_apply_reports_a_screensaver_that_does_not_read_back() {
  fake_tv_fault ignore-writes secure/screensaver_components
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 1
  assert_output_contains "failed       screensaver_components (still $AMBIENT_MODE after settings put)"
}

# screensaver_state: the screensaver and ambient-mode settings the Snapshot records.
screensaver_state() {
  local key
  for key in screensaver_components screensaver_enabled screensaver_activate_on_sleep \
    screensaver_activate_on_dock; do
    printf '%s=%s\n' "$key" "$(fake_tv_setting secure "$key")"
  done
}

test_restore_returns_the_screensaver_to_the_snapshot() {
  fake_tv_setting secure screensaver_enabled 0
  screensaver_state > "$TEST_DIR/before"
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  run_fuego restore
  assert_status 0
  screensaver_state > "$TEST_DIR/after"
  diff "$TEST_DIR/before" "$TEST_DIR/after" || fail "restore did not put the screensaver back"
  assert_output_contains "changed      screensaver_components $IDLE_SCREEN -> $AMBIENT_MODE"
  assert_output_contains "changed      screensaver_enabled 1 -> 0"
}

# The emulator, like a TV whose owner never chose a screensaver, has no screensaver_components:
# the TV then uses its default one.
test_restore_removes_the_screensaver_setting_when_the_snapshot_had_none() {
  rm "$FAKE_TV/settings/secure/screensaver_components"
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_output_contains "changed      screensaver_components null -> $IDLE_SCREEN"
  run_fuego restore
  assert_status 0
  assert_equals null "$(fake_tv_setting secure screensaver_components)" screensaver_components
  assert_output_contains "changed      screensaver_components $IDLE_SCREEN -> null"
}

# The Idle Screen is the Launcher's, so the screensaver is handed back before the Launcher goes.
test_restore_hands_the_screensaver_back_before_uninstalling_the_launcher() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  : > "$FAKE_TV/calls"
  run_fuego restore
  assert_equals "write shell settings put secure screensaver_components $AMBIENT_MODE
write uninstall io.github.danajerban.fuegoos" \
    "$(fake_tv_writes | grep -e screensaver -e uninstall)" "writes"
}

test_apply_again_leaves_the_idle_screen_as_it_is() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  : > "$FAKE_TV/calls"
  run_fuego apply --skip-checks
  assert_status 0
  assert_output_contains "unchanged    screensaver_components already $IDLE_SCREEN"
  assert_no_writes
}
