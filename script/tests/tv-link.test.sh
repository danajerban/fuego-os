# Pairing with and connecting to the TV over Wireless debugging, and what the owner is told
# when the TV can't be reached.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

WIRELESS_DEBUGGING="Settings > System > Developer options > Wireless debugging"
SETUP_DOC="docs/tv-setup.md"

assert_tells_how_to_turn_wireless_debugging_on() {
  assert_output_contains "$WIRELESS_DEBUGGING"
  assert_output_contains "$SETUP_DOC"
}

test_pair_with_the_code_shown_on_the_tv() {
  fake_tv_unpaired
  run_fuego pair "$FAKE_TV_PAIR_ADDRESS" "$FAKE_TV_PAIRING_CODE"
  assert_status 0
  assert_output_contains "Paired with the TV at $FAKE_TV_PAIR_ADDRESS"
  assert_output_contains "fuego connect"
}

test_pair_asks_for_the_code_when_not_given() {
  fake_tv_unpaired
  run_fuego_answering "$FAKE_TV_PAIRING_CODE" pair "$FAKE_TV_PAIR_ADDRESS"
  assert_status 0
  assert_output_contains "Pairing code"
  assert_output_contains "Paired with the TV"
}

test_pair_with_a_wrong_code_says_so() {
  fake_tv_unpaired
  run_fuego pair "$FAKE_TV_PAIR_ADDRESS" 000000
  assert_status 1
  assert_output_contains "The TV did not accept the pairing code"
  assert_output_lacks "Paired with the TV"
}

test_pair_when_the_tv_cannot_be_reached() {
  fake_tv_unpaired
  fake_tv_fault debugging-off
  run_fuego pair "$FAKE_TV_PAIR_ADDRESS" "$FAKE_TV_PAIRING_CODE"
  assert_status 1
  assert_output_contains "Couldn't pair with the TV at $FAKE_TV_PAIR_ADDRESS"
  assert_tells_how_to_turn_wireless_debugging_on
}

test_connect_after_pairing() {
  fake_tv_unpaired
  run_fuego pair "$FAKE_TV_PAIR_ADDRESS" "$FAKE_TV_PAIRING_CODE"
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 0
  assert_output_contains "Connected to the TV at $FAKE_TV_ADDRESS"
}

test_connect_again_when_already_connected() {
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 0
  assert_output_contains "Connected to the TV at $FAKE_TV_ADDRESS"
}

test_connect_changes_nothing_on_the_tv() {
  fake_tv_unpaired
  : > "$FAKE_TV/link/connected"
  : > "$FAKE_TV/link/paired"
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 0
  assert_no_writes
}

test_connect_after_a_restart_turned_wireless_debugging_off() {
  fake_tv_fault debugging-off
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 1
  assert_output_contains "The TV at $FAKE_TV_ADDRESS refused the connection"
  assert_output_contains "A TV restart turns Wireless debugging off"
  assert_tells_how_to_turn_wireless_debugging_on
}

test_connect_when_the_tv_is_off_the_network() {
  fake_tv_fault offline
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 1
  assert_output_contains "Can't reach the TV at $FAKE_TV_ADDRESS"
  assert_output_contains "same network"
  assert_tells_how_to_turn_wireless_debugging_on
}

test_connect_before_pairing() {
  fake_tv_unpaired
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 1
  assert_output_contains "This Mac isn't paired with the TV"
  assert_output_contains "fuego pair"
  assert_tells_how_to_turn_wireless_debugging_on
}

test_connect_saves_the_tvs_address_beside_the_snapshot() {
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 0
  assert_equals "$FAKE_TV_ADDRESS" "$(cat "$(tv_address_file)")" "saved address"
}

test_connect_replaces_the_saved_address() {
  mkdir -p "$(dirname "$(tv_address_file)")"
  echo "$FAKE_TV_HOST:38453" > "$(tv_address_file)"
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 0
  assert_equals "$FAKE_TV_ADDRESS" "$(cat "$(tv_address_file)")" "saved address"
}

test_connect_that_fails_saves_nothing() {
  fake_tv_fault debugging-off
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 1
  [ ! -e "$(tv_address_file)" ] || fail "a failed connect saved the address"
}

# adb's mDNS lists the TV a second time under another name, so commands pick one device.

test_probe_with_the_tv_listed_twice_uses_the_saved_address() {
  fake_tv_listed_by_mdns
  run_fuego connect "$FAKE_TV_ADDRESS"
  run_fuego probe
  assert_status 0
  assert_output_contains "Model:    FUEGO 2K SMART TV (GoogleTV8164)"
  assert_output_contains "com.netflix.ninja"
}

test_apply_with_the_tv_listed_twice_uses_the_saved_address() {
  fake_tv_listed_by_mdns
  run_fuego connect "$FAKE_TV_ADDRESS"
  run_fuego apply
  assert_status 0
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.katniss)"
  assert_output_contains "disabled     com.google.android.katniss"
  assert_output_lacks "missing"
}

test_apply_dry_run_with_the_tv_listed_twice_writes_nothing() {
  fake_tv_listed_by_mdns
  run_fuego connect "$FAKE_TV_ADDRESS"
  run_fuego apply --dry-run
  assert_status 0
  assert_output_contains "would disable com.google.android.katniss"
  assert_no_writes
  [ ! -e "$(snapshot_file)" ] || fail "the dry run saved a Snapshot"
}

test_after_a_restart_the_one_device_listed_is_used() {
  fake_tv_listed_by_mdns
  run_fuego connect "$FAKE_TV_ADDRESS"
  : > "$FAKE_TV/link/connected"
  run_fuego probe
  assert_status 0
  assert_output_contains "Model:    FUEGO 2K SMART TV (GoogleTV8164)"
}

test_several_devices_and_none_saved_says_to_connect() {
  fake_tv_listed_by_mdns
  run_fuego apply
  assert_status 1
  assert_output_contains "adb lists more than one device"
  assert_output_contains "$FAKE_TV_MDNS_SERIAL"
  assert_output_contains "fuego connect IP:PORT"
  assert_tells_how_to_turn_wireless_debugging_on
  assert_output_lacks "Can't reach the TV"
  assert_no_writes
  [ ! -e "$(snapshot_file)" ] || fail "a Snapshot was saved"
}

test_several_devices_and_the_saved_one_gone_says_to_connect() {
  fake_tv_listed_by_mdns
  mkdir -p "$(dirname "$(tv_address_file)")"
  echo "$FAKE_TV_HOST:38453" > "$(tv_address_file)"
  run_fuego probe
  assert_status 1
  assert_output_contains "fuego connect IP:PORT"
}

test_android_serial_wins_over_the_saved_address() {
  fake_tv_listed_by_mdns
  run_fuego connect "$FAKE_TV_ADDRESS"
  ANDROID_SERIAL=nope run_fuego probe
  assert_status 1
  assert_output_contains "Can't reach the TV (error: device 'nope' not found)."
  ANDROID_SERIAL=$FAKE_TV_MDNS_SERIAL run_fuego probe
  assert_status 0
  assert_output_contains "Model:    FUEGO 2K SMART TV (GoogleTV8164)"
}

test_android_serial_picks_the_tv_among_several() {
  fake_tv_listed_by_mdns
  ANDROID_SERIAL=$FAKE_TV_MDNS_SERIAL run_fuego probe
  assert_status 0
  assert_output_contains "Model:    FUEGO 2K SMART TV (GoogleTV8164)"
}

test_an_address_without_a_port_is_refused() {
  run_fuego connect "$FAKE_TV_HOST"
  assert_status 2
  assert_output_contains "IP address and port"
  assert_equals "" "$(fake_tv_calls)" "calls to the TV"
}
