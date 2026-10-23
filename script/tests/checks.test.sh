# apply's Check Step and Casting Fallback: after the Home Takeover the owner answers four checks,
# recorded beside the Snapshot; "casting broken" re-enables the setup wizard alone.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

STOCK_LAUNCHER=com.google.android.apps.tv.launcherx
SETUP_WIZARD=com.google.android.tungsten.setupwraith

# The owner's input for a first apply: yes to the Wi-Fi warning, then one answer per check
# (casting, HDMI inputs, Wi-Fi, the remote's buttons).
takeover_and_checks() {
  printf 'yes\n%s\n%s\n%s\n%s' "$1" "$2" "$3" "$4"
}

test_check_step_asks_the_four_checks_one_at_a_time_and_records_the_answers() {
  run_fuego_answering "$(takeover_and_checks yes no "" yes)" apply --launcher "$(launcher_apk)"
  assert_status 0
  printf '%s\n' "$OUTPUT" | grep -e '^  Casting:' -e '^  HDMI inputs:' -e '^  Wi-Fi:' -e '^  Remote buttons:' \
    -e '^  recorded ' > "$TEST_DIR/asked"
  assert_equals "  Casting: cast a video from your phone to the TV. Does it play on the TV?
  recorded     casting: works
  HDMI inputs: open Inputs on the Dock and choose each HDMI input. Does each show its picture?
  recorded     hdmi-inputs: broken
  Wi-Fi: open Settings > Network & Internet on the TV. Is the TV on your Wi-Fi network?
  recorded     wifi: skipped
  Remote buttons: press the remote's Netflix button, then Home, then its YouTube button. Do both apps open?
  recorded     remote-buttons: works" "$(cat "$TEST_DIR/asked")" "questions and answers, in order"
  assert_output_contains "Answers recorded in $(checks_file)"
  grep -q '^checked=[0-9]' "$(checks_file)" || fail "no date in $(checks_file)"
  assert_equals "check.casting=works
check.hdmi-inputs=broken
check.wifi=skipped
check.remote-buttons=works" "$(grep '^check\.' "$(checks_file)")" "recorded answers"
  grep -q -e 'check' -e 'casting' "$(snapshot_file)" && fail "the answers went into the Snapshot"
  assert_equals disabled-user "$(fake_tv_package_state "$SETUP_WIZARD")"
  assert_equals disabled-user "$(fake_tv_package_state "$STOCK_LAUNCHER")"
}

test_casting_broken_re_enables_only_the_setup_wizard_and_records_what_has_home_focus() {
  run_fuego_answering "$(takeover_and_checks no yes yes yes)" apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals "write shell input keyevent KEYCODE_HOME
write shell pm enable $SETUP_WIZARD
write shell input keyevent KEYCODE_HOME" \
    "$(fake_tv_writes | grep -e 'pm enable' -e keyevent)" "writes from the Home press on"
  assert_equals enabled "$(fake_tv_package_state "$SETUP_WIZARD")"
  assert_equals disabled-user "$(fake_tv_package_state "$STOCK_LAUNCHER")"
  assert_output_contains "Casting Fallback: turning the setup wizard back on, alone; the Stock Launcher stays disabled."
  assert_output_contains "enabled      $SETUP_WIZARD"
  # The setup wizard answers Home too, and outranks the Launcher on the fake TV.
  assert_output_contains "checked      Home focus after a Home press: $SETUP_WIZARD/.RecoveryActivity"
  assert_output_contains "Home now opens $SETUP_WIZARD/.RecoveryActivity, not the Launcher."
  assert_output_contains "Casting should work now: cast from your phone again."
  assert_equals "check.casting=broken
casting-fallback=done
casting-fallback.home-focus=$SETUP_WIZARD/.RecoveryActivity" \
    "$(grep -e '^check.casting=' -e '^casting-fallback' "$(checks_file)")" "recorded fallback"
  grep -q -e 'check' -e 'casting' "$(snapshot_file)" && fail "the fallback went into the Snapshot"
  assert_output_contains "already off, 0 failed;"
}

test_apply_after_the_casting_fallback_leaves_the_setup_wizard_on_unless_the_owner_says_yes() {
  local answer
  run_fuego_answering "$(takeover_and_checks no yes yes yes)" apply --launcher "$(launcher_apk)"
  assert_status 0
  cp "$(snapshot_file)" "$TEST_DIR/snapshot-before"
  cp "$(checks_file)" "$TEST_DIR/checks-before"
  for answer in "" no yes-please; do
    : > "$FAKE_TV/calls"
    run_fuego_answering "$answer" apply
    assert_status 0
    assert_output_contains "The Casting Fallback turned the setup wizard back on, because casting broke without it."
    assert_output_contains "Type yes to disable the setup wizard again, which can break casting again:"
    assert_output_contains "unchanged    $SETUP_WIZARD left on for casting (the Casting Fallback)"
    assert_output_lacks "Disabling the setup wizard can delete"
    assert_output_lacks "Check Step"
    assert_no_writes
    assert_equals enabled "$(fake_tv_package_state "$SETUP_WIZARD")"
  done
  cmp -s "$TEST_DIR/snapshot-before" "$(snapshot_file)" || fail "the Snapshot was rewritten"
  cmp -s "$TEST_DIR/checks-before" "$(checks_file)" || fail "the answers changed with no new answers"
}

test_apply_after_the_casting_fallback_disables_the_setup_wizard_again_after_two_yeses() {
  run_fuego_answering "$(takeover_and_checks no yes yes yes)" apply --launcher "$(launcher_apk)"
  assert_status 0
  : > "$FAKE_TV/calls"
  run_fuego_answering "$(printf 'yes\nyes')" apply
  assert_status 0
  assert_output_contains "Disabling the setup wizard can delete"
  assert_equals "write shell pm disable-user --user 0 $SETUP_WIZARD
write shell input keyevent KEYCODE_HOME" "$(fake_tv_writes)" "writes"
  assert_equals disabled-user "$(fake_tv_package_state "$SETUP_WIZARD")"
  assert_output_contains "checked      a Home press opens the Launcher"
  assert_equals undone "$(sed -n 's/^casting-fallback=//p' "$(checks_file)" | tail -n 1)" "the fallback's record"
  # The Check Step follows the new takeover; this run's input has ended.
  assert_output_contains "not done     Check Step: no answers"
}

test_apply_after_the_casting_fallback_and_a_tv_update_disables_only_the_stock_launcher() {
  run_fuego_answering "$(takeover_and_checks no yes yes yes)" apply --launcher "$(launcher_apk)"
  assert_status 0
  fake_tv_set_package_state "$STOCK_LAUNCHER" enabled # as a TV update might do
  : > "$FAKE_TV/calls"
  # Return to keep the setup wizard on, then yes to the Wi-Fi warning.
  run_fuego_answering "$(printf '\nyes')" apply
  assert_status 0
  assert_output_contains "unchanged    $SETUP_WIZARD left on for casting (the Casting Fallback)"
  assert_equals "write shell pm disable-user --user 0 $STOCK_LAUNCHER
write shell input keyevent KEYCODE_HOME" "$(fake_tv_writes)" "writes"
  assert_equals disabled-user "$(fake_tv_package_state "$STOCK_LAUNCHER")"
  assert_equals enabled "$(fake_tv_package_state "$SETUP_WIZARD")"
  assert_output_contains "checked      Home focus after a Home press: $SETUP_WIZARD/.RecoveryActivity"
  assert_output_lacks "Rolling back"
  assert_output_lacks "Check Step"
}

test_check_step_is_skipped_with_skip_checks() {
  run_fuego_answering "$(takeover_and_checks no no no no)" apply --skip-checks --launcher "$(launcher_apk)"
  assert_status 0
  assert_output_contains "checked      a Home press opens the Launcher"
  assert_output_contains "not done     Check Step: skipped (--skip-checks); the next apply asks again"
  assert_output_lacks "Casting:"
  [ ! -e "$(checks_file)" ] || fail "answers recorded from a skipped Check Step"
  assert_equals disabled-user "$(fake_tv_package_state "$SETUP_WIZARD")"
}

test_check_step_in_a_dry_run_is_listed_and_asks_nothing() {
  run_fuego_answering "$(takeover_and_checks no no no no)" apply --dry-run --launcher "$(launcher_apk)"
  assert_status 0
  assert_output_contains "would ask    the Check Step: casting, HDMI inputs, Wi-Fi, the remote's Netflix and YouTube buttons"
  assert_output_lacks "Casting:"
  assert_equals "" "$(fake_tv_writes)" "writes to the TV"
}

test_check_step_without_answers_records_nothing_and_the_next_apply_asks_again() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_output_contains "not done     Check Step: no answers (the input ended); the next apply asks again"
  [ ! -e "$(checks_file)" ] || fail "answers recorded from a run that gave none: $(cat "$(checks_file)")"
  : > "$FAKE_TV/calls"
  run_fuego_answering "$(printf 'yes\nno\nyes\nyes')" apply
  assert_status 0
  assert_no_writes
  assert_output_contains "unchanged    Home opens the Launcher"
  assert_equals "check.casting=works
check.hdmi-inputs=broken
check.wifi=works
check.remote-buttons=works" "$(grep '^check\.' "$(checks_file)")" "recorded answers"
}
