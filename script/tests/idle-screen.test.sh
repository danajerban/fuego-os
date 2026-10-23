# apply's Idle Screen and artwork: the Launcher's dream as the screensaver in place of Google's
# ambient mode, the owner's pictures copied to the Artwork Folder, and restore putting the
# screensaver back.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

IDLE_SCREEN=io.github.danajerban.fuegoos/.IdleScreen
AMBIENT_MODE=com.google.android.apps.tv.dreamx/.service.Backdrop

# settings_writes: the write calls that change a setting, in order.
settings_writes() {
  fake_tv_writes | grep ' settings '
}

test_apply_sets_the_idle_screen_as_the_screensaver_in_place_of_ambient_mode() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals "$IDLE_SCREEN" "$(fake_tv_setting secure screensaver_components)" screensaver_components
  assert_equals 1 "$(fake_tv_setting secure screensaver_enabled)" screensaver_enabled
  assert_output_contains "changed      screensaver_components $AMBIENT_MODE -> $IDLE_SCREEN"
  assert_output_contains "unchanged    screensaver_enabled already 1"
}

test_apply_switches_the_screensaver_on_and_never_writes_the_idle_timeout() {
  fake_tv_setting secure screensaver_enabled 0
  fake_tv_setting secure screensaver_activate_on_sleep 0
  fake_tv_setting secure sleep_timeout 1800000
  fake_tv_setting system screen_off_timeout 600000
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  assert_equals "write shell settings put global window_animation_scale 0.5
write shell settings put global transition_animation_scale 0.5
write shell settings put global animator_duration_scale 0.5
write shell settings put secure screensaver_components $IDLE_SCREEN
write shell settings put secure screensaver_enabled 1" "$(settings_writes)" "settings writes"
  assert_equals 600000 "$(fake_tv_setting system screen_off_timeout)" screen_off_timeout
  assert_output_contains "changed      screensaver_enabled 0 -> 1"
}

test_apply_without_the_launcher_leaves_the_screensaver_alone() {
  run_fuego apply
  assert_status 0
  assert_output_contains "not done     Idle Screen: the Launcher is not on the TV"
  assert_equals "" "$(settings_writes | grep screensaver)" "screensaver writes"
  assert_equals "$AMBIENT_MODE" "$(fake_tv_setting secure screensaver_components)"
}

test_apply_reports_a_screensaver_that_does_not_read_back() {
  fake_tv_fault ignore-writes secure/screensaver_components
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 1
  assert_output_contains "failed       screensaver_components (still $AMBIENT_MODE after settings put)"
}

# screensaver_state: the screensaver and ambient-mode settings the Snapshot records.
screensaver_state() {
  local key
  for key in screensaver_components screensaver_enabled screensaver_activate_on_sleep \
    screensaver_activate_on_dock; do
    printf '%s=%s\n' "$key" "$(fake_tv_setting secure "$key")"
  done
}

test_restore_returns_the_screensaver_to_the_snapshot() {
  fake_tv_setting secure screensaver_enabled 0
  screensaver_state > "$TEST_DIR/before"
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_status 0
  run_fuego restore
  assert_status 0
  screensaver_state > "$TEST_DIR/after"
  diff "$TEST_DIR/before" "$TEST_DIR/after" || fail "restore did not put the screensaver back"
  assert_output_contains "changed      screensaver_components $IDLE_SCREEN -> $AMBIENT_MODE"
  assert_output_contains "changed      screensaver_enabled 1 -> 0"
}

# The emulator, like a TV whose owner never chose a screensaver, has no screensaver_components:
# the TV then uses its default one.
test_restore_removes_the_screensaver_setting_when_the_snapshot_had_none() {
  rm "$FAKE_TV/settings/secure/screensaver_components"
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_output_contains "changed      screensaver_components null -> $IDLE_SCREEN"
  run_fuego restore
  assert_status 0
  assert_equals null "$(fake_tv_setting secure screensaver_components)" screensaver_components
  assert_output_contains "changed      screensaver_components $IDLE_SCREEN -> null"
}

# The Idle Screen is the Launcher's, so the screensaver is handed back before the Launcher goes.
test_restore_hands_the_screensaver_back_before_uninstalling_the_launcher() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  : > "$FAKE_TV/calls"
  run_fuego restore
  assert_equals "write shell settings put secure screensaver_components $AMBIENT_MODE
write uninstall io.github.danajerban.fuegoos" \
    "$(fake_tv_writes | grep -e screensaver -e uninstall)" "writes"
}

# Ambient mode is Known-Bloat, so apply turned it off: restore turns it on before the screensaver
# points at it again.
test_restore_enables_ambient_mode_before_making_it_the_screensaver_again() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  assert_equals disabled-user "$(fake_tv_package_state com.google.android.apps.tv.dreamx)"
  : > "$FAKE_TV/calls"
  run_fuego restore
  assert_status 0
  assert_equals enabled "$(fake_tv_package_state com.google.android.apps.tv.dreamx)"
  assert_equals "$AMBIENT_MODE" "$(fake_tv_setting secure screensaver_components)" screensaver_components
  assert_equals "write shell pm enable com.google.android.apps.tv.dreamx
write shell settings put secure screensaver_components $AMBIENT_MODE" \
    "$(fake_tv_writes | grep -e screensaver_components -e dreamx)" "writes"
}

ARTWORK=/sdcard/Android/data/io.github.danajerban.fuegoos/files/artwork

# pictures_folder: the owner's folder on the Mac, with two JPEGs, a PNG and other files. Prints
# its path.
pictures_folder() {
  local dir="$TEST_DIR/pictures"
  mkdir -p "$dir/holiday"
  echo sunrise > "$dir/sunrise.jpg"
  echo "blue hour" > "$dir/blue hour.JPEG"
  echo dusk > "$dir/dusk.png"
  echo notes > "$dir/notes.txt"
  echo raw > "$dir/beach.heic"
  echo hidden > "$dir/.DS_Store"
  echo nested > "$dir/holiday/pier.jpg"
  echo "$dir"
}

# artwork_on_tv: the files in the fake TV's Artwork Folder.
artwork_on_tv() {
  (cd "$(fake_tv_sdcard_file "${ARTWORK#/sdcard/}")" && LC_ALL=C ls)
}

test_apply_copies_the_owners_jpeg_and_png_pictures_to_the_artwork_folder() {
  local pictures
  pictures=$(pictures_folder)
  run_fuego_answering yes apply --launcher "$(launcher_apk)" --pictures "$pictures"
  assert_status 0
  assert_equals "blue hour.JPEG
dusk.png
sunrise.jpg" "$(artwork_on_tv)" "pictures on the TV"
  cmp -s "$pictures/blue hour.JPEG" "$(fake_tv_sdcard_file "${ARTWORK#/sdcard/}/blue hour.JPEG")" ||
    fail "the picture on the TV differs from the owner's"
  assert_output_contains "copied       blue hour.JPEG"
  assert_output_contains "copied       sunrise.jpg"
  assert_output_contains "skipped      notes.txt (not a JPEG or PNG picture)"
  assert_output_contains "skipped      beach.heic (not a JPEG or PNG picture)"
  assert_output_contains "skipped      holiday (a folder)"
  assert_output_lacks ".DS_Store"
}

# Without the Home Takeover the Launcher has never been shown, so its Artwork Folder isn't there
# yet, and adb can't make it.
test_apply_starts_the_launcher_once_when_its_artwork_folder_is_missing() {
  run_fuego_answering no apply --launcher "$(launcher_apk)" --pictures "$(pictures_folder)"
  assert_status 0
  assert_output_contains "not done     Home Takeover: no yes from the owner"
  assert_output_contains "Starting the Launcher once, so it makes its Artwork Folder."
  fake_tv_calls | grep -qx "read shell am start -W -n io.github.danajerban.fuegoos/.HomeActivity" ||
    fail "the Launcher was not started"
  assert_equals "blue hour.JPEG
dusk.png
sunrise.jpg" "$(artwork_on_tv)" "pictures on the TV"
}

test_apply_reports_an_artwork_folder_the_launcher_never_makes() {
  printf 'package=io.github.danajerban.fuegoos\nhome=io.github.danajerban.fuegoos/.HomeActivity\n' \
    > "$TEST_DIR/launcher.apk"
  run_fuego_answering no apply --launcher "$TEST_DIR/launcher.apk" --pictures "$(pictures_folder)"
  assert_status 1
  assert_output_contains "failed       Artwork: the Launcher did not make its Artwork Folder ($ARTWORK)"
  assert_equals "" "$(fake_tv_writes | grep ' push ')" "pushes"
}

test_apply_again_leaves_pictures_already_on_the_tv() {
  local pictures
  pictures=$(pictures_folder)
  run_fuego_answering yes apply --launcher "$(launcher_apk)" --pictures "$pictures"
  echo "a new sunrise" > "$pictures/sunrise.jpg"
  run_fuego apply --skip-checks --pictures "$pictures"
  assert_status 0
  assert_output_contains "unchanged    dusk.png already in the Artwork Folder"
  assert_output_contains "copied       sunrise.jpg"
  cmp -s "$pictures/sunrise.jpg" "$(fake_tv_sdcard_file "${ARTWORK#/sdcard/}/sunrise.jpg")" ||
    fail "the changed picture was not copied again"
}

test_apply_reports_a_picture_that_does_not_read_back() {
  fake_tv_fault ignore-writes "$ARTWORK/"
  run_fuego_answering yes apply --launcher "$(launcher_apk)" --pictures "$(pictures_folder)"
  assert_status 1
  assert_output_contains "failed       dusk.png (not in the Artwork Folder after adb push: $TEST_DIR/pictures/dusk.png: 1 file pushed, 0 skipped."
  assert_output_lacks "copied "
}

test_apply_without_the_launcher_copies_no_pictures() {
  run_fuego apply --pictures "$(pictures_folder)"
  assert_status 0
  assert_output_contains "not done     Artwork: the Launcher is not on the TV"
  assert_equals "" "$(fake_tv_writes | grep ' push ')" "pushes"
}

test_apply_with_a_folder_without_pictures_copies_nothing() {
  mkdir -p "$TEST_DIR/empty"
  echo notes > "$TEST_DIR/empty/notes.txt"
  run_fuego_answering yes apply --launcher "$(launcher_apk)" --pictures "$TEST_DIR/empty"
  assert_status 0
  assert_output_contains "skipped      notes.txt (not a JPEG or PNG picture)"
  assert_output_contains "not done     Artwork: no JPEG or PNG pictures in $TEST_DIR/empty"
  assert_equals "" "$(fake_tv_writes | grep ' push ')" "pushes"
}

test_apply_with_no_pictures_folder_stops_before_anything() {
  run_fuego apply --pictures "$TEST_DIR/no-such-folder"
  assert_status 2
  assert_output_contains "No pictures folder at $TEST_DIR/no-such-folder."
  assert_equals "" "$(fake_tv_calls)" "calls to the TV"
}

test_apply_dry_run_sets_no_screensaver_and_copies_no_pictures() {
  cp -R "$FAKE_TV" "$TEST_DIR/tv-before"
  run_fuego apply --dry-run --launcher "$(launcher_apk)" --pictures "$(pictures_folder)"
  assert_status 0
  assert_output_contains "would set    screensaver_components $AMBIENT_MODE -> $IDLE_SCREEN"
  assert_output_contains "would copy   sunrise.jpg"
  assert_output_contains "skipped      notes.txt (not a JPEG or PNG picture)"
  assert_equals "" "$(fake_tv_calls | grep -v '^read ')" "calls other than reads"
  assert_equals "" "$(fake_tv_calls | grep -e ' am start' -e ' push ')" "starts and copies"
  rm "$FAKE_TV/calls" "$TEST_DIR/tv-before/calls"
  diff -r "$TEST_DIR/tv-before" "$FAKE_TV" || fail "the dry run changed the TV"
}

test_apply_again_leaves_the_idle_screen_as_it_is() {
  run_fuego_answering yes apply --launcher "$(launcher_apk)"
  : > "$FAKE_TV/calls"
  run_fuego apply --skip-checks
  assert_status 0
  assert_output_contains "unchanged    screensaver_components already $IDLE_SCREEN"
  assert_no_writes
}
