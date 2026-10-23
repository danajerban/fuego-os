# probe: a read-only report of the TV's facts, its packages by list, and baseline measurements.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

test_probe_reports_the_tv_facts() {
  fake_tv_prop ro.soc.manufacturer MediaTek
  fake_tv_prop ro.soc.model MT9618
  fake_tv_prop ro.board.platform mt5862
  fake_tv_prop ro.hardware mt5862
  run_fuego probe
  assert_status 0
  assert_output_contains "Model:    FUEGO 2K SMART TV (GoogleTV8164)"
  assert_output_contains "Chip:     MediaTek MT9618 (board mt5862, hardware mt5862)"
  assert_output_contains "RAM:      1978 MB"
  assert_output_contains "Storage:  9.0 GB free of 9.7 GB"
  assert_output_contains "Android:  14 (build UKNV.260529.001)"
}

# package_line PACKAGE: the package's first line in the report, with runs of spaces squeezed.
package_line() {
  printf '%s\n' "$OUTPUT" | grep -m 1 "^  $1 " | tr -s ' ' | sed 's/^ //'
}

test_probe_tags_each_package_with_its_lists() {
  fake_tv_set_package_state com.google.android.katniss disabled-user
  run_fuego probe
  assert_status 0
  assert_output_contains "Packages (20 installed, 1 disabled)"
  assert_equals "com.netflix.ninja Keep List, Must-Keep List" "$(package_line com.netflix.ninja)"
  assert_equals "com.google.android.gms Must-Keep List" "$(package_line com.google.android.gms)"
  assert_equals "com.google.android.katniss Known-Bloat List, disabled" \
    "$(package_line com.google.android.katniss)"
  assert_equals "com.google.android.apps.tv.launcherx Takeover Packages" \
    "$(package_line com.google.android.apps.tv.launcherx)"
  assert_equals "com.fuego.tv.otaupdater unlisted" "$(package_line com.fuego.tv.otaupdater)"
}

test_probe_measures_available_memory_and_home_draw_time() {
  fake_tv_memory 2025912 655360
  fake_tv_launcher_is_home
  fake_tv_home_draw_ms 83
  run_fuego probe
  assert_status 0
  assert_output_contains "Available memory:  640 MB"
  assert_output_contains "Home Draw Time:    83 ms (io.github.danajerban.fuegoos/.HomeActivity reopened from the Inputs screen, a hot start; budget 200 ms)"
  assert_equals "read shell am start -W -n io.github.danajerban.fuegoos/.InputsActivity
read shell am start -W -n io.github.danajerban.fuegoos/.HomeActivity" \
    "$(fake_tv_calls | grep ' am ')" "how Home is timed"
  assert_equals io.github.danajerban.fuegoos/.HomeActivity "$(fake_tv_focus)" "focus afterwards"
}

test_probe_does_not_time_home_until_the_launcher_is_home() {
  run_fuego probe
  assert_status 0
  assert_output_contains "Home Draw Time:    not measured (until the Launcher is Home)"
  fake_tv_install_package io.github.danajerban.fuegoos user
  run_fuego probe
  assert_status 0
  assert_output_contains "Home Draw Time:    not measured (until the Launcher is Home)"
  assert_equals "" "$(fake_tv_calls | grep ' am ')" "activities started"
}

test_probe_says_when_the_inputs_screen_does_not_open() {
  # A Launcher whose Inputs screen can't be started over adb.
  printf 'package=io.github.danajerban.fuegoos\nhome=io.github.danajerban.fuegoos/.HomeActivity\n' \
    > "$TEST_DIR/inputs-less.apk"
  fake_tv_launcher_is_home "$TEST_DIR/inputs-less.apk"
  run_fuego probe
  assert_status 0
  assert_output_contains "Home Draw Time:    not measured (couldn't open the Inputs screen to leave Home: Error: Activity class {io.github.danajerban.fuegoos/io.github.danajerban.fuegoos.InputsActivity} does not exist.)"
  assert_equals "" "$(fake_tv_calls | grep ' am start -W -n io.github.danajerban.fuegoos/.HomeActivity')" \
    "Home timed without leaving it"
}

test_probe_measures_the_launchers_memory() {
  run_fuego probe
  assert_output_contains "Launcher memory:   not installed"
  fake_tv_install_package io.github.danajerban.fuegoos user
  run_fuego probe
  assert_output_contains "Launcher memory:   not running"
  fake_tv_process io.github.danajerban.fuegoos 17300
  run_fuego probe
  assert_status 0
  assert_output_contains "Launcher memory:   16.9 MB (PSS)"
}

test_probe_changes_nothing_on_the_tv_or_the_mac() {
  fake_tv_launcher_is_home # so that Home is timed
  mkdir -p "$TEST_DIR/cwd" "$TEST_DIR/tmp"
  cd "$TEST_DIR/cwd" || fail "can't enter $TEST_DIR/cwd"
  export TMPDIR="$TEST_DIR/tmp"
  cp -R "$FAKE_TV" "$TEST_DIR/tv-before"
  run_fuego probe
  assert_status 0
  assert_equals "" "$(fake_tv_calls | grep -v '^read ')" "calls other than reads"
  assert_equals "" "$(fake_tv_calls | grep -e ' -S ' -e force-stop -e ' kill')" "calls that stop an app"
  rm "$FAKE_TV/calls" "$TEST_DIR/tv-before/calls"
  diff -r "$TEST_DIR/tv-before" "$FAKE_TV" || fail "probe changed the TV"
  assert_equals "" "$(find "$HOME" "$TEST_DIR/cwd" "$TMPDIR" -mindepth 1)" "files written on the Mac"
}

test_probe_when_wireless_debugging_was_turned_off() {
  fake_tv_fault debugging-off
  run_fuego probe
  assert_status 1
  assert_output_contains "Can't reach the TV (error: no devices/emulators found)."
  assert_output_contains "Settings > System > Developer options > Wireless debugging"
  assert_output_contains "docs/tv-setup.md"
  assert_output_lacks "Packages"
  assert_equals "read get-state" "$(fake_tv_calls)" "calls to the TV"
}

test_probe_when_the_tv_left_the_network() {
  fake_tv_fault offline
  run_fuego probe
  assert_status 1
  assert_output_contains "Can't reach the TV (error: device offline)."
  assert_output_contains "fuego connect IP:PORT"
}

test_probe_stops_when_adb_is_missing() {
  export FUEGO_ADB="$TEST_DIR/nowhere/adb"
  run_fuego probe
  assert_status 1
  assert_output_contains "adb: missing"
}

test_probe_flags_packages_on_none_of_the_lists() {
  fake_tv_install_package com.fuego.tv.shoppingrows system # as a Fuego update might add
  fake_tv_set_package_state com.fuego.tv.otaupdater disabled-user
  run_fuego probe
  assert_status 0
  assert_output_contains "Unlisted packages (4): on none of the lists. fuego never disables them;"
  assert_equals "  android
  com.fuego.tv.otaupdater (disabled)
  com.fuego.tv.shoppingrows
  com.google.android.apps.tv.dreamx" \
    "$(printf '%s\n' "$OUTPUT" | sed -n '/^Unlisted packages/,/^$/p' | grep '^  ')"
}
