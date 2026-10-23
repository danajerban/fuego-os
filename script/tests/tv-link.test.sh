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

test_an_address_without_a_port_is_refused() {
  run_fuego connect "$FAKE_TV_HOST"
  assert_status 2
  assert_output_contains "IP address and port"
  assert_equals "" "$(fake_tv_calls)" "calls to the TV"
}
