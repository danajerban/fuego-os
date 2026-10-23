# Test each piece from the outside, through two seams

Tests drive each piece the way the owner does, with no tests of internal functions (spec, Testing Decisions). The script is tested against the Fake TV: every `adb` call goes through the ADB Boundary, which the tests point at the Fake TV. The Launcher is tested on an Android TV (API 34) emulator, pressing keys and checking what the screen shows and which app opens. Casting, HDMI switching, Wi-Fi after the takeover and the remote's buttons can only be checked on the real TV, through the Check Step.
