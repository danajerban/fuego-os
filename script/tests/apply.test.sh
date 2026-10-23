# apply: Snapshot, Debloat, speed settings, read-back and dry-run.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

test_apply_disables_only_known_bloat() {
  run_fuego apply
  assert_status 0
  assert_equals "write shell pm disable-user --user 0 com.google.android.katniss
write shell pm disable-user --user 0 com.google.android.tv
write shell pm disable-user --user 0 com.google.android.tvrecommendations" \
    "$(fake_tv_writes | grep ' pm ' | sort)" "package writes"
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.katniss)"
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.tv)"
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.tvrecommendations)"
  assert_equals enabled "$(fake_tv_package_state com.google.android.apps.tv.launcherx)"
  assert_equals enabled "$(fake_tv_package_state com.google.android.tungsten.setupwraith)"
  assert_output_contains "disabled     com.google.android.katniss"
}

test_apply_never_disables_a_must_keep_package_also_on_known_bloat() {
  with_list_entry known-bloat.txt "com.netflix.ninja|false|a mistake the Must-Keep List overrides"
  with_list_entry known-bloat.txt "com.google.android.apps.tv.launcherx|false|a Takeover Package by mistake"
  run_fuego apply
  assert_status 0
  assert_output_contains "skipped      com.netflix.ninja (on the Must-Keep List, which always wins)"
  assert_output_contains "skipped      com.google.android.apps.tv.launcherx (a Takeover Package: only the Home Takeover disables it)"
  assert_equals "" "$(fake_tv_writes | grep -e netflix -e launcherx -e setupwraith)" "writes to kept packages"
  assert_equals enabled "$(fake_tv_package_state com.netflix.ninja)"
}

test_apply_skips_missing_bloat_and_counts_bloat_already_off() {
  rm "$FAKE_TV/packages/com.google.android.tv"
  fake_tv_set_package_state com.google.android.katniss disabled-user
  run_fuego apply
  assert_status 0
  assert_output_contains "skipped      com.google.android.tv (not installed)"
  assert_output_contains "already off  com.google.android.katniss"
  assert_output_contains "Summary: 1 disabled, 14 skipped, 1 already off, 0 failed"
  assert_equals "write shell pm disable-user --user 0 com.google.android.tvrecommendations" \
    "$(fake_tv_writes | grep ' pm ')" "package writes"
}

test_apply_reports_unlisted_packages_and_leaves_them_alone() {
  fake_tv_install_package com.fuego.tv.shoppingrows system
  run_fuego apply
  assert_status 0
  assert_output_contains "Unlisted packages (3): on none of the lists. fuego never disables them;"
  assert_output_contains "  com.fuego.tv.shoppingrows"
  assert_equals enabled "$(fake_tv_package_state com.fuego.tv.shoppingrows)"
  assert_equals "" "$(fake_tv_writes | grep -e shoppingrows -e otaupdater)" "writes to unlisted packages"
}

# Google's ambient mode is Known-Bloat, and the screensaver the TV ships with.
AMBIENT_MODE=com.google.android.apps.tv.dreamx/.service.Backdrop

test_apply_disables_ambient_mode_only_after_the_idle_screen_takes_over() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals io.github.danajerban.fuegoos/.IdleScreen \
    "$(fake_tv_setting secure screensaver_components)" screensaver_components
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.apps.tv.dreamx)"
  assert_equals "write shell settings put secure screensaver_components io.github.danajerban.fuegoos/.IdleScreen
write shell pm disable-user --user 0 com.google.android.apps.tv.dreamx" \
    "$(fake_tv_writes | grep -e screensaver_components -e dreamx)" "screensaver and ambient mode writes"
  assert_output_contains "disabled     com.google.android.apps.tv.dreamx"
}

test_apply_keeps_ambient_mode_while_it_is_still_the_screensaver() {
  run_fuego apply
  assert_status 0
  assert_output_contains "not done     Idle Screen: the Launcher is not on the TV"
  assert_output_contains "skipped      com.google.android.apps.tv.dreamx (still the TV's screensaver: the Idle Screen did not take over)"
  assert_equals enabled "$(fake_tv_package_state com.google.android.apps.tv.dreamx)"
  assert_equals "$AMBIENT_MODE" "$(fake_tv_setting secure screensaver_components)" screensaver_components
  assert_equals "" "$(fake_tv_writes | grep -e screensaver -e dreamx)" "screensaver and ambient mode writes"
  # The next apply that sets the Idle Screen turns ambient mode off.
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.apps.tv.dreamx)"
}

test_apply_keeps_bloat_named_anywhere_in_the_screensaver_list() {
  fake_tv_setting secure screensaver_components "com.google.android.tv.dream/.Clock,$AMBIENT_MODE"
  run_fuego apply
  assert_status 0
  assert_output_contains "skipped      com.google.android.apps.tv.dreamx (still the TV's screensaver: the Idle Screen did not take over)"
  assert_equals enabled "$(fake_tv_package_state com.google.android.apps.tv.dreamx)"
  # Only a whole package name before "/" counts: com.google.android.tv is not com.google.android.tv.dream.
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.tv)"
}

test_apply_dry_run_with_the_launcher_would_disable_ambient_mode() {
  run_fuego apply --dry-run --launcher "$(launcher_apk)"
  assert_status 0
  assert_output_contains "would set    screensaver_components $AMBIENT_MODE -> io.github.danajerban.fuegoos/.IdleScreen"
  assert_output_contains "would disable com.google.android.apps.tv.dreamx"
  assert_no_writes
}

# snapshot_fields: the Snapshot without its comments and the time it was taken.
snapshot_fields() {
  grep -v -e '^#' -e '^taken=' "$(snapshot_file)"
}

test_apply_on_a_fresh_tv_writes_the_full_snapshot_first() {
  rm "$FAKE_TV/packages/com.stremio.one"
  fake_tv_setting secure screensaver_activate_on_sleep 0
  run_fuego apply
  assert_status 0
  assert_output_contains "Snapshot: saved to $(snapshot_file)"
  grep -q '^taken=20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]$' "$(snapshot_file)" ||
    fail "the Snapshot does not say when it was taken"
  assert_equals "package.com.amazon.amazonvideo.livingroom=missing
package.com.android.bluetooth=missing
package.com.android.location.fused=enabled
package.com.android.providers.tv=missing
package.com.android.shell=missing
package.com.android.tv.settings=enabled
package.com.android.vending=enabled
package.com.disney.disneyplus=missing
package.com.express.at.factory.factorymanager=missing
package.com.express.bt.autopair=missing
package.com.expressluck.tvhelpmanual=missing
package.com.google.android.apps.mediashell=enabled
package.com.google.android.apps.tv.dreamx=enabled
package.com.google.android.apps.tv.launcherx=enabled
package.com.google.android.feedback=missing
package.com.google.android.gms=enabled
package.com.google.android.gsf=enabled
package.com.google.android.inputmethod.latin=missing
package.com.google.android.katniss=enabled
package.com.google.android.play.games=missing
package.com.google.android.tungsten.setupwraith=enabled
package.com.google.android.tv=enabled
package.com.google.android.tv.inputplayer=enabled
package.com.google.android.tv.remote.service=enabled
package.com.google.android.tvrecommendations=enabled
package.com.google.android.videos=missing
package.com.google.android.webview=missing
package.com.google.android.youtube.tv=enabled
package.com.google.android.youtube.tvmusic=missing
package.com.iqiyi.i18n.tv=missing
package.com.mediatek.autopair=missing
package.com.mediatek.hotkey.dispatcher=missing
package.com.mediatek.tv.service=missing
package.com.mediatek.tvinput=missing
package.com.mediatek.wwtv.mediaplayer=missing
package.com.mediatek.wwtv.tvcenter=missing
package.com.netflix.ninja=enabled
package.com.spotify.tv.android=enabled
package.com.stremio.one=missing
package.com.wbd.stream=missing
package.fusion.android.tv.demo=missing
package.tv.anoki.acr.anokiacroptin=missing
home=com.google.android.apps.tv.launcherx/.home.HomeActivity
setting.global.window_animation_scale=1.0
setting.global.transition_animation_scale=1.0
setting.global.animator_duration_scale=null
setting.secure.screensaver_components=com.google.android.apps.tv.dreamx/.service.Backdrop
setting.secure.screensaver_enabled=1
setting.secure.screensaver_activate_on_sleep=0
setting.secure.screensaver_activate_on_dock=null
launcher=missing" "$(snapshot_fields)" "Snapshot"
}

test_apply_saves_every_setting_alongside_the_snapshot_once() {
  fake_tv_setting system screen_off_timeout 600000
  run_fuego apply
  assert_status 0
  local dir
  dir=$(dirname "$(snapshot_file)")
  assert_equals "screensaver_components=com.google.android.apps.tv.dreamx/.service.Backdrop
screensaver_enabled=1" "$(cat "$dir/snapshot-settings-secure")" "secure settings"
  assert_equals "transition_animation_scale=1.0
window_animation_scale=1.0" "$(cat "$dir/snapshot-settings-global")" "global settings"
  assert_equals "screen_off_timeout=600000" "$(cat "$dir/snapshot-settings-system")" "system settings"
  cp -R "$dir" "$TEST_DIR/first"
  fake_tv_setting secure screensaver_enabled 0
  run_fuego apply
  assert_status 0
  diff -r "$TEST_DIR/first" "$dir" || fail "the second apply rewrote the Snapshot or its settings"
}

test_apply_records_disabled_packages_and_an_installed_launcher() {
  fake_tv_set_package_state com.google.android.katniss disabled-user
  fake_tv_install_package io.github.danajerban.fuegoos user
  run_fuego apply
  assert_status 0
  snapshot_fields | grep -qx 'package.com.google.android.katniss=disabled' ||
    fail "katniss is not recorded as disabled"
  snapshot_fields | grep -qx 'launcher=installed' || fail "the Launcher is not recorded as installed"
}

test_apply_again_changes_nothing_and_keeps_the_snapshot() {
  run_fuego apply
  assert_status 0
  cp "$(snapshot_file)" "$TEST_DIR/first-snapshot"
  : > "$FAKE_TV/calls"
  fake_tv_set_package_state com.google.android.katniss enabled # as a TV update might do
  run_fuego apply
  assert_status 0
  assert_equals "write shell pm disable-user --user 0 com.google.android.katniss" "$(fake_tv_writes)" \
    "writes on the second run"
  : > "$FAKE_TV/calls"
  run_fuego apply
  assert_status 0
  assert_no_writes
  cmp -s "$TEST_DIR/first-snapshot" "$(snapshot_file)" || fail "the Snapshot was rewritten"
  assert_output_contains "Snapshot: kept from the first apply ($(snapshot_file)); it is never overwritten"
  assert_output_contains "Summary: 0 disabled, 13 skipped, 3 already off, 0 failed; 0 other changes"
}

test_apply_keeps_the_snapshot_in_fuego_state_dir() {
  export FUEGO_STATE_DIR="$TEST_DIR/state"
  run_fuego apply
  assert_status 0
  [ -f "$TEST_DIR/state/snapshot" ] || fail "no Snapshot in FUEGO_STATE_DIR"
  [ ! -e "$(snapshot_file)" ] || fail "a Snapshot was written to the default place too"
}

test_apply_stops_before_any_change_when_the_snapshot_cannot_be_saved() {
  export FUEGO_STATE_DIR="$TEST_DIR/not-a-dir/state"
  echo "a file" > "$TEST_DIR/not-a-dir"
  run_fuego apply
  assert_status 1
  assert_output_contains "Can't save the Snapshot to $TEST_DIR/not-a-dir/state/snapshot"
  assert_no_writes
}

test_apply_dry_run_lists_the_changes_and_writes_nothing_anywhere() {
  mkdir -p "$TEST_DIR/cwd" "$TEST_DIR/tmp"
  cd "$TEST_DIR/cwd" || fail "can't enter $TEST_DIR/cwd"
  export TMPDIR="$TEST_DIR/tmp"
  fake_tv_set_package_state com.google.android.katniss disabled-user
  cp -R "$FAKE_TV" "$TEST_DIR/tv-before"
  run_fuego apply --dry-run
  assert_status 0
  assert_output_contains "Dry run: nothing is written to the TV or this Mac."
  assert_output_contains "Snapshot: would be saved to $(snapshot_file)"
  assert_output_contains "would disable com.google.android.tvrecommendations"
  assert_output_contains "already off  com.google.android.katniss"
  assert_output_contains "would set    window_animation_scale 1.0 -> 0.5"
  assert_output_contains "Summary (dry run): 2 to disable, 13 skipped, 1 already off, 0 failed; 3 other changes to make"
  assert_equals "" "$(fake_tv_calls | grep -v '^read ')" "calls other than reads"
  rm "$FAKE_TV/calls" "$TEST_DIR/tv-before/calls"
  diff -r "$TEST_DIR/tv-before" "$FAKE_TV" || fail "the dry run changed the TV"
  assert_equals "" "$(find "$HOME" "$TEST_DIR/cwd" "$TMPDIR" -mindepth 1)" "files written on the Mac"
}

test_apply_dry_run_after_a_real_run_keeps_the_snapshot() {
  run_fuego apply
  cp "$(snapshot_file)" "$TEST_DIR/first-snapshot"
  fake_tv_set_package_state com.google.android.katniss enabled
  : > "$FAKE_TV/calls"
  run_fuego apply --dry-run
  assert_status 0
  assert_output_contains "would disable com.google.android.katniss"
  assert_no_writes
  cmp -s "$TEST_DIR/first-snapshot" "$(snapshot_file)" || fail "the dry run rewrote the Snapshot"
}

test_apply_prints_measurements_before_and_after() {
  fake_tv_home_draw_ms 61
  run_fuego_answering "yes
yes
yes
yes
yes" apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals 2 "$(printf '%s\n' "$OUTPUT" | grep -c '^  Available memory:  859 MB$')" \
    "available memory lines"
  assert_equals "Before
After" "$(printf '%s\n' "$OUTPUT" | grep -e '^Before$' -e '^After$')" "measurement headings"
  # Before the Home Takeover the Stock Launcher is Home; after it, the Launcher is, and is timed.
  assert_equals "  Home Draw Time:    not measured (until the Launcher is Home)
  Home Draw Time:    61 ms (io.github.danajerban.fuegoos/.HomeActivity reopened from the Inputs screen, a hot start; budget 200 ms)" \
    "$(printf '%s\n' "$OUTPUT" | grep '^  Home Draw Time:')" "Home Draw Time lines"
}

test_apply_sets_animation_scales_to_half_and_no_other_setting() {
  fake_tv_setting global transition_animation_scale 0.5
  run_fuego apply
  assert_status 0
  assert_equals 0.5 "$(fake_tv_setting global window_animation_scale)" window_animation_scale
  assert_equals 0.5 "$(fake_tv_setting global transition_animation_scale)" transition_animation_scale
  assert_equals 0.5 "$(fake_tv_setting global animator_duration_scale)" animator_duration_scale
  # Only the scales: never the background process limit or Play auto-updates.
  assert_equals "write shell settings put global window_animation_scale 0.5
write shell settings put global animator_duration_scale 0.5" \
    "$(fake_tv_writes | grep -v ' pm ')" "writes other than Debloat"
  assert_output_contains "changed      window_animation_scale 1.0 -> 0.5"
  assert_output_contains "unchanged    transition_animation_scale already 0.5"
  assert_output_contains "changed      animator_duration_scale null -> 0.5"
}

test_apply_reports_a_scale_that_does_not_read_back_as_failed() {
  fake_tv_fault ignore-writes global/window_animation_scale
  run_fuego apply
  assert_status 1
  assert_output_contains "failed       window_animation_scale (still 1.0 after settings put)"
  assert_output_contains "1 failed"
}

test_apply_reports_a_disable_that_does_not_read_back_as_failed() {
  fake_tv_fault ignore-writes com.google.android.katniss
  run_fuego apply
  assert_status 1
  assert_output_contains "failed       com.google.android.katniss (still enabled after pm disable-user)"
  assert_output_lacks "disabled     com.google.android.katniss"
  assert_output_contains "Summary: 2 disabled, 13 skipped, 0 already off, 1 failed"
}
