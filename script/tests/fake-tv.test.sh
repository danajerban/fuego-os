# The fake TV answers adb calls the way a real TV does, so script tests can trust it.
# These drive the fake directly, through the same command line the script uses.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

adb_fake() {
  OUTPUT=$("$FUEGO_ADB" "$@" 2>&1)
  STATUS=$?
}

test_fake_tv_lists_packages_and_disabled_packages() {
  fake_tv_set_package_state com.google.android.katniss disabled-user
  adb_fake shell pm list packages
  assert_output_contains "package:com.google.android.katniss"
  assert_output_contains "package:com.netflix.ninja"
  adb_fake shell pm list packages -d
  assert_equals "package:com.google.android.katniss" "$OUTPUT" "disabled packages"
}

test_fake_tv_disables_and_enables_a_package() {
  adb_fake shell pm disable-user --user 0 com.google.android.katniss
  assert_equals "Package com.google.android.katniss new state: disabled-user" "$OUTPUT"
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.katniss)"
  adb_fake shell pm enable com.google.android.katniss
  assert_equals "Package com.google.android.katniss new state: enabled" "$OUTPUT"
  assert_equals enabled "$(fake_tv_package_state com.google.android.katniss)"
}

test_fake_tv_reads_and_writes_settings() {
  adb_fake shell settings get global window_animation_scale
  assert_equals 1.0 "$OUTPUT"
  adb_fake shell settings put global window_animation_scale 0.5
  assert_equals 0.5 "$(fake_tv_setting global window_animation_scale)"
  adb_fake shell settings get secure no_such_key
  assert_equals null "$OUTPUT"
}

test_fake_tv_reads_build_facts() {
  adb_fake shell getprop ro.build.id
  assert_equals UKNV.260529.001 "$OUTPUT"
}

test_fake_tv_home_press_opens_the_home_activity() {
  printf 'package=io.github.danajerban.fuegoos\nhome=io.github.danajerban.fuegoos/.HomeActivity\n' \
    > "$TEST_DIR/launcher.apk"
  adb_fake install -r "$TEST_DIR/launcher.apk"
  assert_output_contains "Success"
  adb_fake shell cmd package set-home-activity io.github.danajerban.fuegoos/.HomeActivity
  assert_equals Success "$OUTPUT"
  adb_fake shell input keyevent KEYCODE_HOME
  adb_fake shell dumpsys window
  assert_output_contains "mCurrentFocus=Window{"
  assert_output_contains "io.github.danajerban.fuegoos/.HomeActivity}"
}

test_fake_tv_home_falls_back_when_the_home_package_is_disabled() {
  adb_fake shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
  assert_equals \
    com.google.android.tungsten.setupwraith/com.google.android.tungsten.setupwraith.FallbackHomeActivity \
    "$(fake_tv_home)"
}

test_fake_tv_uninstall_removes_the_package_and_its_files() {
  printf 'package=io.github.danajerban.fuegoos\n' > "$TEST_DIR/launcher.apk"
  adb_fake install "$TEST_DIR/launcher.apk"
  echo art > "$TEST_DIR/sunrise.jpg"
  adb_fake push "$TEST_DIR/sunrise.jpg" /sdcard/Android/data/io.github.danajerban.fuegoos/files/artwork/
  assert_status 0
  adb_fake shell ls /sdcard/Android/data/io.github.danajerban.fuegoos/files/artwork
  assert_equals sunrise.jpg "$OUTPUT"
  adb_fake uninstall io.github.danajerban.fuegoos
  assert_equals Success "$OUTPUT"
  assert_equals missing "$(fake_tv_package_state io.github.danajerban.fuegoos)"
  [ ! -e "$(fake_tv_sdcard_file Android/data/io.github.danajerban.fuegoos)" ] ||
    fail "the uninstalled app's files are still on the TV"
  adb_fake uninstall io.github.danajerban.fuegoos
  assert_status 1
}

test_fake_tv_logs_reads_and_writes() {
  adb_fake shell pm list packages
  adb_fake shell settings put global window_animation_scale 0.5
  assert_equals "read shell pm list packages
write shell settings put global window_animation_scale 0.5" "$(fake_tv_calls)"
  assert_equals "write shell settings put global window_animation_scale 0.5" "$(fake_tv_writes)"
}

test_fake_tv_refuses_calls_it_does_not_know() {
  adb_fake shell reboot
  assert_status 64
  assert_output_contains "fake TV: unsupported adb call: shell reboot"
  assert_equals "unsupported shell reboot" "$(fake_tv_calls)"
}

test_fake_tv_ignored_write_does_not_read_back() {
  fake_tv_fault ignore-writes com.google.android.katniss
  fake_tv_fault ignore-writes global/window_animation_scale
  adb_fake shell pm disable-user --user 0 com.google.android.katniss
  assert_equals "Package com.google.android.katniss new state: disabled-user" "$OUTPUT"
  assert_equals enabled "$(fake_tv_package_state com.google.android.katniss)"
  adb_fake shell settings put global window_animation_scale 0.5
  assert_equals 1.0 "$(fake_tv_setting global window_animation_scale)"
}

test_fake_tv_ignored_home_press_keeps_focus() {
  fake_tv_fault ignore-writes focus
  adb_fake shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
  adb_fake shell input keyevent KEYCODE_HOME
  assert_equals com.google.android.apps.tv.launcherx/com.google.android.apps.tv.launcherx.home.HomeActivity \
    "$(fake_tv_focus)"
}

test_fake_tv_goes_offline_after_a_chosen_write() {
  fake_tv_fault offline-after "pm disable-user --user 0 com.google.android.tungsten.setupwraith"
  adb_fake shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
  assert_status 0
  adb_fake shell pm list packages
  assert_status 1
  assert_equals "error: device offline" "$OUTPUT"
  adb_fake connect "$FAKE_TV_ADDRESS"
  assert_output_contains "failed to connect to '$FAKE_TV_ADDRESS'"
}

test_fake_tv_pairs_and_connects() {
  fake_tv_unpaired
  adb_fake connect "$FAKE_TV_ADDRESS"
  assert_equals "failed to authenticate to $FAKE_TV_ADDRESS" "$OUTPUT"
  adb_fake pair "$FAKE_TV_PAIR_ADDRESS" 000000
  assert_status 1
  adb_fake pair "$FAKE_TV_PAIR_ADDRESS" "$FAKE_TV_PAIRING_CODE"
  assert_output_contains "Successfully paired to $FAKE_TV_PAIR_ADDRESS"
  adb_fake connect "$FAKE_TV_ADDRESS"
  assert_equals "connected to $FAKE_TV_ADDRESS" "$OUTPUT"
  adb_fake -s "$FAKE_TV_ADDRESS" get-state
  assert_equals device "$OUTPUT"
}

test_fake_tv_with_debugging_off_refuses_connections() {
  fake_tv_fault debugging-off
  adb_fake connect "$FAKE_TV_ADDRESS"
  assert_status 0
  assert_equals "failed to connect to '$FAKE_TV_ADDRESS': Connection refused" "$OUTPUT"
  adb_fake shell getprop ro.build.id
  assert_status 1
}

# The expected outputs below are copied from an Android TV API 34 emulator.

test_fake_tv_reports_memory_like_the_kernel() {
  fake_tv_memory 2025912 880436
  adb_fake shell cat /proc/meminfo
  assert_status 0
  assert_output_contains "MemTotal:        2025912 kB"
  assert_output_contains "MemAvailable:     880436 kB"
}

test_fake_tv_reports_storage_in_kilobyte_blocks() {
  fake_tv_storage 10167132 565024 9454652
  adb_fake shell df -k /data
  assert_status 0
  assert_equals "Filesystem       1K-blocks   Used Available Use% Mounted on
/dev/block/dm-37  10167132 565024   9454652   6% /data/user/0" "$OUTPUT"
}

test_fake_tv_times_a_cold_start_of_home() {
  local home
  home=$(fake_tv_home)
  fake_tv_home_draw_ms 1432
  adb_fake shell am start -W -S -n "$home"
  assert_status 0
  assert_equals "Starting: Intent { cmp=$home }
Status: ok
LaunchState: COLD
Activity: $home
TotalTime: 1432
WaitTime: 1440
Complete" "$OUTPUT"
  assert_equals "$home" "$(fake_tv_focus)"
}

test_fake_tv_cannot_start_a_missing_activity() {
  adb_fake shell am start -W -S -n no.such.pkg/.Main
  assert_status 0
  assert_equals "Starting: Intent { cmp=no.such.pkg/.Main }
Error type 3
Error: Activity class {no.such.pkg/no.such.pkg.Main} does not exist." "$OUTPUT"
}

test_fake_tv_disables_and_enables_like_pm_on_a_package_it_does_not_know() {
  adb_fake shell pm disable-user --user 0 no.such.pkg
  assert_status 255
  assert_equals "
Exception occurred while executing 'disable-user':
java.lang.IllegalArgumentException: Unknown package: no.such.pkg" "$(printf '%s\n' "$OUTPUT" | sed -n '1,3p')"
  assert_output_contains "	at com.android.server.pm.PackageManagerService.setEnabledSettings"
  adb_fake shell pm enable no.such.pkg
  assert_status 255
  assert_output_contains "Exception occurred while executing 'enable':"
}

test_fake_tv_lists_user_disabled_packages_as_disabled() {
  adb_fake shell pm disable-user --user 0 com.google.android.tvrecommendations
  adb_fake shell pm disable-user --user 0 com.google.android.tvrecommendations
  assert_equals "Package com.google.android.tvrecommendations new state: disabled-user" "$OUTPUT"
  adb_fake shell pm list packages -d
  assert_equals "package:com.google.android.tvrecommendations" "$OUTPUT"
  adb_fake shell pm enable com.google.android.tvrecommendations
  adb_fake shell pm list packages -d
  assert_equals "" "$OUTPUT"
}

test_fake_tv_animation_scales_put_and_delete_like_settings() {
  adb_fake shell settings get global animator_duration_scale
  assert_equals null "$OUTPUT"
  adb_fake shell settings put global window_animation_scale 0.5
  assert_equals "" "$OUTPUT"
  adb_fake shell settings delete global window_animation_scale
  assert_equals "Deleted 1 rows" "$OUTPUT"
  adb_fake shell settings get global window_animation_scale
  assert_equals null "$OUTPUT"
  adb_fake shell settings delete global window_animation_scale
  assert_equals "Deleted 0 rows" "$OUTPUT"
}

test_fake_tv_reports_a_package_memory_summary() {
  fake_tv_process com.android.tv.settings 17300
  adb_fake shell dumpsys meminfo com.android.tv.settings
  assert_status 0
  assert_output_contains "** MEMINFO in pid "
  assert_output_contains " App Summary"
  assert_output_contains "           TOTAL PSS:    17300            TOTAL RSS:"
  adb_fake shell dumpsys meminfo com.google.android.apps.tv.launcherx
  assert_status 0
  assert_equals "No process found for: com.google.android.apps.tv.launcherx" "$OUTPUT"
}

test_fake_tv_window_list_has_no_focus_lines() {
  adb_fake shell dumpsys window windows
  assert_output_contains "WINDOW MANAGER WINDOWS (dumpsys window windows)"
  assert_output_lacks "mCurrentFocus"
  adb_fake shell dumpsys window
  assert_output_contains "mCurrentFocus=Window{"
}
