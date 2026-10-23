# The missing-tools check: the script names exactly what to install on the Mac.
# shellcheck shell=bash
# shellcheck disable=SC2034 # OUTPUT and STATUS are read by lib.sh's assertions

# A Mac with the Android SDK and a JDK 17 in place, for building the Launcher.
make_build_tools() {
  mkdir -p "$TEST_DIR/sdk/platforms/android-34" "$TEST_DIR/sdk/build-tools/36.0.0" "$TEST_DIR/jdk/bin"
  printf '#!/bin/sh\n' > "$TEST_DIR/jdk/bin/java"
  chmod +x "$TEST_DIR/jdk/bin/java"
  export ANDROID_HOME="$TEST_DIR/sdk" JAVA_HOME="$TEST_DIR/jdk"
  unset ANDROID_SDK_ROOT
}

no_build_tools() {
  unset ANDROID_HOME ANDROID_SDK_ROOT JAVA_HOME
}

test_check_finds_adb() {
  no_build_tools
  run_fuego check
  assert_status 0
  assert_output_contains "adb: found"
  assert_output_lacks "Android SDK"
}

test_missing_adb_is_named_with_how_to_install_it() {
  [ ! -e /usr/bin/adb ] && [ ! -e /bin/adb ] || return 0 # this machine has adb in a system dir
  unset FUEGO_ADB
  PATH=/usr/bin:/bin run_fuego check
  assert_status 1
  assert_output_contains "adb: missing"
  assert_output_contains "brew install --cask android-platform-tools"
}

test_fuego_adb_pointing_nowhere_is_reported() {
  export FUEGO_ADB="$TEST_DIR/nowhere/adb"
  run_fuego check
  assert_status 1
  assert_output_contains "adb: missing"
  assert_output_contains "FUEGO_ADB is set to $TEST_DIR/nowhere/adb"
}

test_tv_commands_stop_when_adb_is_missing() {
  export FUEGO_ADB="$TEST_DIR/nowhere/adb"
  run_fuego connect "$FAKE_TV_ADDRESS"
  assert_status 1
  assert_output_contains "adb: missing"
  assert_equals "" "$(fake_tv_calls)" "calls to the TV"
}

test_build_check_asks_for_the_sdk_and_jdk_when_missing() {
  no_build_tools
  run_fuego check --build
  assert_status 1
  assert_output_contains "adb: found"
  assert_output_contains "Android SDK: missing"
  assert_output_contains "brew install --cask android-commandlinetools"
  assert_output_contains "JDK 17: missing"
  assert_output_contains "brew install openjdk@17"
}

test_build_check_passes_with_the_sdk_and_jdk() {
  make_build_tools
  run_fuego check --build
  assert_status 0
  assert_output_contains "Android SDK: found ($TEST_DIR/sdk)"
  assert_output_contains "JDK 17: found ($TEST_DIR/jdk)"
}

test_build_check_names_the_missing_sdk_platform() {
  make_build_tools
  rm -rf "$TEST_DIR/sdk/platforms/android-34"
  run_fuego check --build
  assert_status 1
  assert_output_contains 'sdkmanager "platforms;android-34"'
}

test_build_check_names_the_missing_build_tools() {
  make_build_tools
  rm -rf "$TEST_DIR/sdk/build-tools/36.0.0"
  run_fuego check --build
  assert_status 1
  assert_output_contains "Android SDK: missing"
  assert_output_contains '"build-tools;36.0.0"'
}
