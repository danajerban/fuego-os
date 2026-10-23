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
