# restore: puts package states and animation scales back to the Snapshot.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

# tv_state: the fake TV's packages and settings, to compare before apply and after restore.
tv_state() {
  (cd "$FAKE_TV" && grep -r . packages settings | LC_ALL=C sort)
}

test_restore_returns_packages_and_animation_scales_to_the_snapshot() {
  fake_tv_set_package_state com.google.android.tv disabled-user
  tv_state > "$TEST_DIR/before"
  run_fuego apply
  assert_status 0
  : > "$FAKE_TV/calls"
  run_fuego restore
  assert_status 0
  tv_state > "$TEST_DIR/after"
  diff "$TEST_DIR/before" "$TEST_DIR/after" || fail "restore did not put the TV back"
  assert_output_contains "enabled      com.google.android.katniss"
  assert_output_contains "enabled      com.google.android.tvrecommendations"
  assert_output_contains "changed      window_animation_scale 0.5 -> 1.0"
  assert_output_contains "changed      animator_duration_scale 0.5 -> null"
  assert_output_contains "Summary: 5 changed back, 0 not changed back"
  assert_equals "" "$(fake_tv_writes | grep -e 'pm disable' -e 'com.google.android.tv$')" \
    "writes to packages that were already as in the Snapshot"
}

test_restore_again_changes_nothing() {
  run_fuego apply
  run_fuego restore
  : > "$FAKE_TV/calls"
  run_fuego restore
  assert_status 0
  assert_no_writes
  assert_output_contains "unchanged    17 packages already as in the Snapshot"
  assert_output_contains "Summary: 0 changed back, 0 not changed back"
}

test_restore_keeps_the_snapshot() {
  run_fuego apply
  cp "$(snapshot_file)" "$TEST_DIR/snapshot"
  run_fuego restore
  cmp -s "$TEST_DIR/snapshot" "$(snapshot_file)" || fail "restore changed the Snapshot"
  run_fuego apply
  assert_status 0
  assert_output_contains "Snapshot: kept from the first apply"
}

test_restore_without_a_snapshot_changes_nothing() {
  run_fuego restore
  assert_status 1
  assert_output_contains "No Snapshot at $(snapshot_file)"
  assert_no_writes
}

test_restore_reports_a_write_that_does_not_read_back() {
  run_fuego apply
  fake_tv_fault ignore-writes com.google.android.katniss
  fake_tv_fault ignore-writes global/transition_animation_scale
  run_fuego restore
  assert_status 1
  assert_output_contains "failed       com.google.android.katniss (still disabled after pm enable)"
  assert_output_contains "failed       transition_animation_scale (still 0.5 after settings put)"
  assert_output_contains "enabled      com.google.android.tvrecommendations"
  assert_output_contains "Summary: 4 changed back, 2 not changed back"
}

test_restore_reports_a_package_that_is_gone() {
  run_fuego apply
  rm "$FAKE_TV/packages/com.google.android.katniss"
  run_fuego restore
  assert_status 1
  assert_output_contains "failed       com.google.android.katniss (enabled in the Snapshot, not installed now)"
}

test_restore_disables_again_what_was_off_but_never_a_must_keep_package() {
  fake_tv_set_package_state com.google.android.tv disabled-user
  fake_tv_set_package_state com.stremio.one disabled-user
  run_fuego apply
  fake_tv_set_package_state com.google.android.tv enabled
  fake_tv_set_package_state com.stremio.one enabled
  run_fuego restore
  assert_status 0
  assert_output_contains "disabled     com.google.android.tv"
  assert_output_contains "skipped      com.stremio.one (disabled in the Snapshot, but on the Must-Keep List)"
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.tv)"
  assert_equals enabled "$(fake_tv_package_state com.stremio.one)"
}

test_restore_when_the_tv_cannot_be_reached() {
  run_fuego apply
  fake_tv_fault offline
  run_fuego restore
  assert_status 1
  assert_output_contains "Can't reach the TV (error: device offline)."
}
