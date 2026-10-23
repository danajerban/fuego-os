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

# The expected outputs in the Home tests below are copied from an Android TV API 34 emulator,
# whose Stock Launcher is com.google.android.tvlauncher (priority 2, like launcherx here).

test_fake_tv_installs_an_apk_like_adb() {
  launcher_apk > /dev/null
  adb_fake install -r "$TEST_DIR/launcher.apk"
  assert_status 0
  assert_equals "Performing Streamed Install
Success" "$OUTPUT"
  assert_equals enabled "$(fake_tv_package_state io.github.danajerban.fuegoos)"
  adb_fake install -r "$TEST_DIR/no-such.apk"
  assert_status 1
  assert_equals "Performing Streamed Install
adb: failed to stat $TEST_DIR/no-such.apk: No such file or directory" "$OUTPUT"
  echo junk > "$TEST_DIR/junk.apk"
  adb_fake install -r "$TEST_DIR/junk.apk"
  assert_status 1
  assert_output_contains "adb: failed to install $TEST_DIR/junk.apk: Failure [INSTALL_PARSE_FAILED_NOT_APK: Failed to parse"
}

test_fake_tv_resolves_home_in_short_form_with_its_priority() {
  adb_fake shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
  assert_equals "priority=2 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true
com.google.android.apps.tv.launcherx/.home.HomeActivity" "$OUTPUT"
}

test_fake_tv_set_home_activity_changes_nothing_while_the_stock_launcher_is_enabled() {
  launcher_apk > /dev/null
  adb_fake install -r "$TEST_DIR/launcher.apk"
  adb_fake shell cmd package set-home-activity io.github.danajerban.fuegoos/.HomeActivity
  assert_status 0
  assert_equals Success "$OUTPUT"
  adb_fake shell cmd role get-role-holders --user 0 android.app.role.HOME
  assert_equals io.github.danajerban.fuegoos "$OUTPUT"
  assert_equals com.google.android.apps.tv.launcherx/.home.HomeActivity "$(fake_tv_home)"
  adb_fake shell input keyevent KEYCODE_HOME
  assert_status 0
  assert_equals "" "$OUTPUT"
  assert_equals com.google.android.apps.tv.launcherx/.home.HomeActivity "$(fake_tv_focus)"
}

test_fake_tv_home_press_opens_the_chosen_home_once_the_takeover_packages_are_off() {
  launcher_apk > /dev/null
  adb_fake install -r "$TEST_DIR/launcher.apk"
  adb_fake shell cmd package set-home-activity io.github.danajerban.fuegoos/.HomeActivity
  adb_fake shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
  # With launcherx off, the setup wizard (priority 1) still outranks the chosen Launcher.
  assert_equals com.google.android.tungsten.setupwraith/.RecoveryActivity "$(fake_tv_home)"
  adb_fake shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
  adb_fake shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
  assert_equals "priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true
io.github.danajerban.fuegoos/.HomeActivity" "$OUTPUT"
  adb_fake shell input keyevent KEYCODE_HOME
  adb_fake shell dumpsys window
  assert_output_contains "  mCurrentFocus=Window{5e1f2a u0 io.github.danajerban.fuegoos/io.github.danajerban.fuegoos.HomeActivity}"
  assert_output_contains "  mFocusedApp=ActivityRecord{8c3d1b u0 io.github.danajerban.fuegoos/.HomeActivity t7}"
}

test_fake_tv_disabling_the_focused_app_leaves_no_focus() {
  adb_fake shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
  adb_fake shell dumpsys window
  assert_output_contains "  mCurrentFocus=null"
  assert_output_contains "  mFocusedApp=null"
}

test_fake_tv_refuses_a_home_activity_in_a_disabled_or_missing_package() {
  adb_fake shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
  adb_fake shell cmd package set-home-activity com.google.android.apps.tv.launcherx/.home.HomeActivity
  assert_status 1
  assert_equals "Error: Failed to set default home." "$OUTPUT"
  adb_fake shell cmd package set-home-activity no.such.pkg/.Main
  assert_status 1
  assert_equals "Error: Failed to set default home." "$OUTPUT"
}

test_fake_tv_home_role_falls_back_when_its_holder_is_uninstalled() {
  adb_fake shell cmd role get-role-holders --user 0 android.app.role.HOME
  assert_equals com.google.android.apps.tv.launcherx "$OUTPUT"
  launcher_apk > /dev/null
  adb_fake install -r "$TEST_DIR/launcher.apk"
  adb_fake shell cmd package set-home-activity io.github.danajerban.fuegoos/.HomeActivity
  adb_fake uninstall io.github.danajerban.fuegoos
  adb_fake shell cmd role get-role-holders --user 0 android.app.role.HOME
  assert_equals com.google.android.apps.tv.launcherx "$OUTPUT"
}

test_fake_tv_asks_which_home_when_two_share_the_top_priority() {
  fake_tv_home_activity com.other.launcher/.Home 2
  assert_equals android/com.android.internal.app.ResolverActivity "$(fake_tv_home)"
}

test_fake_tv_lists_settings_like_settings_list() {
  adb_fake shell settings list secure
  assert_status 0
  assert_equals "screensaver_components=com.google.android.apps.tv.dreamx/.service.Backdrop
screensaver_enabled=1" "$OUTPUT"
  fake_tv_setting global Phenotype_boot_count 2
  adb_fake shell settings list global
  assert_equals "Phenotype_boot_count=2
transition_animation_scale=1.0
window_animation_scale=1.0" "$OUTPUT"
}

# The outputs below are copied from an Android TV API 34 emulator, pushing to the Launcher's
# Artwork Folder.

test_fake_tv_push_into_an_app_folder_fails_until_the_app_has_made_it() {
  local artwork=/sdcard/Android/data/io.github.danajerban.fuegoos/files/artwork
  launcher_apk > /dev/null
  adb_fake install "$TEST_DIR/launcher.apk"
  echo art > "$TEST_DIR/sunrise.jpg"
  adb_fake shell ls "$artwork"
  assert_status 1
  assert_equals "ls: $artwork: No such file or directory" "$OUTPUT"
  adb_fake push "$TEST_DIR/sunrise.jpg" "$artwork/"
  assert_status 1
  assert_equals "$TEST_DIR/sunrise.jpg: 1 file pushed, 0 skipped. 0.1 MB/s (4 bytes in 0.001s)
adb: error: failed to copy '$TEST_DIR/sunrise.jpg' to '$artwork/': remote secure_mkdirs failed: Operation not permitted" \
    "$OUTPUT"
  [ ! -e "$(fake_tv_sdcard_file Android/data/io.github.danajerban.fuegoos)" ] ||
    fail "adb made the app's folder"
  adb_fake shell am start -W -n io.github.danajerban.fuegoos/.HomeActivity
  assert_equals "Starting: Intent { cmp=io.github.danajerban.fuegoos/.HomeActivity }
Status: ok
LaunchState: COLD
Activity: io.github.danajerban.fuegoos/.HomeActivity
TotalTime: 1432
WaitTime: 1440
Complete" "$OUTPUT"
  adb_fake shell ls "$artwork"
  assert_status 0
  assert_equals "" "$OUTPUT"
  adb_fake push "$TEST_DIR/sunrise.jpg" "$artwork/"
  assert_status 0
  assert_equals "$TEST_DIR/sunrise.jpg: 1 file pushed, 0 skipped. 0.1 MB/s (4 bytes in 0.001s)" "$OUTPUT"
  cmp -s "$TEST_DIR/sunrise.jpg" "$(fake_tv_sdcard_file Android/data/io.github.danajerban.fuegoos/files/artwork/sunrise.jpg)" ||
    fail "the picture is not on the TV"
}

test_fake_tv_starting_the_top_activity_again_delivers_to_it() {
  launcher_apk > /dev/null
  adb_fake install "$TEST_DIR/launcher.apk"
  adb_fake shell am start -W -n io.github.danajerban.fuegoos/.HomeActivity
  adb_fake shell am start -W -n io.github.danajerban.fuegoos/.HomeActivity
  assert_equals "Starting: Intent { cmp=io.github.danajerban.fuegoos/.HomeActivity }
Warning: Activity not started, intent has been delivered to currently running top-most instance.
Status: ok
LaunchState: UNKNOWN (0)
Activity: io.github.danajerban.fuegoos/.HomeActivity
TotalTime: 0
WaitTime: 19
Complete" "$OUTPUT"
}

test_fake_tv_push_sync_skips_a_file_already_on_the_tv() {
  echo art > "$TEST_DIR/sunrise.jpg"
  adb_fake push --sync "$TEST_DIR/sunrise.jpg" /sdcard/Pictures/
  assert_equals "$TEST_DIR/sunrise.jpg: 1 file pushed, 0 skipped. 0.1 MB/s (4 bytes in 0.001s)" "$OUTPUT"
  adb_fake push --sync "$TEST_DIR/sunrise.jpg" /sdcard/Pictures/
  assert_status 0
  assert_equals "$TEST_DIR/sunrise.jpg: 0 files pushed, 1 skipped." "$OUTPUT"
  echo other art > "$TEST_DIR/sunrise.jpg"
  adb_fake push --sync "$TEST_DIR/sunrise.jpg" /sdcard/Pictures/
  assert_equals "$TEST_DIR/sunrise.jpg: 1 file pushed, 0 skipped. 0.1 MB/s (10 bytes in 0.001s)" "$OUTPUT"
}

test_fake_tv_uninstall_removes_the_package_and_its_files() {
  launcher_apk > /dev/null
  adb_fake install "$TEST_DIR/launcher.apk"
  adb_fake shell am start -W -n io.github.danajerban.fuegoos/.HomeActivity
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
  assert_equals null "$(fake_tv_focus)"
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
