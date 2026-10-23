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
  fake_tv_home_draw_ms 1432
  run_fuego probe
  assert_status 0
  assert_output_contains "Available memory:  640 MB"
  assert_output_contains "Home draw time:    1432 ms (cold start of com.google.android.apps.tv.launcherx/com.google.android.apps.tv.launcherx.home.HomeActivity)"
}

test_probe_says_when_there_is_no_home_to_time() {
  fake_tv_set_package_state com.google.android.apps.tv.launcherx disabled-user
  fake_tv_set_package_state com.google.android.tungsten.setupwraith disabled-user
  run_fuego probe
  assert_status 0
  assert_output_contains "Home draw time:    not measured (no app answers the Home button)"
}

test_probe_does_not_time_the_home_chooser() {
  fake_tv_install_package android system
  printf '%s\n' android/com.android.internal.app.ResolverActivity "$(cat "$FAKE_TV/home-activities")" \
    > "$FAKE_TV/home-activities"
  run_fuego probe
  assert_status 0
  assert_output_contains "Home draw time:    not measured (the TV asks which app to use as Home)"
  if fake_tv_calls | grep -q "am start"; then
    fail "probe started the Home chooser: $(fake_tv_calls | grep "am start")"
  fi
}

test_probe_changes_nothing_on_the_tv_or_the_mac() {
  mkdir -p "$TEST_DIR/cwd" "$TEST_DIR/tmp"
  cd "$TEST_DIR/cwd" || fail "can't enter $TEST_DIR/cwd"
  export TMPDIR="$TEST_DIR/tmp"
  cp -R "$FAKE_TV" "$TEST_DIR/tv-before"
  run_fuego probe
  assert_status 0
  assert_equals "" "$(fake_tv_calls | grep -v '^read ')" "calls other than reads"
  rm "$FAKE_TV/calls" "$TEST_DIR/tv-before/calls"
  diff -r "$TEST_DIR/tv-before" "$FAKE_TV" || fail "probe changed the TV"
  assert_equals "" "$(find "$HOME" "$TEST_DIR/cwd" "$TMPDIR" -mindepth 1)" "files written on the Mac"
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
