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
  assert_output_contains "Summary: 1 disabled, 1 skipped, 1 already off, 0 failed"
  assert_equals "write shell pm disable-user --user 0 com.google.android.tvrecommendations" \
    "$(fake_tv_writes | grep ' pm ')" "package writes"
}

test_apply_reports_unlisted_packages_and_leaves_them_alone() {
  fake_tv_install_package com.fuego.tv.shoppingrows system
  run_fuego apply
  assert_status 0
  assert_output_contains "Unlisted packages (4): on none of the lists. fuego never disables them;"
  assert_output_contains "  com.fuego.tv.shoppingrows"
  assert_equals enabled "$(fake_tv_package_state com.fuego.tv.shoppingrows)"
  assert_equals "" "$(fake_tv_writes | grep -e shoppingrows -e otaupdater -e dreamx)" "writes to unlisted packages"
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
  assert_output_contains "Summary: 2 disabled, 0 skipped, 0 already off, 1 failed"
}
