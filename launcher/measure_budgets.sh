#!/bin/bash
# Measures the Launcher's budgets on a TV or emulator over adb:
#   - cold Home draw: the Launcher not running, Home opened (budget 800 ms);
#   - warm Home draw: the Launcher running, Home reopened from an app (budget 200 ms);
#   - memory: the Launcher's total PSS while Home is on screen with its artwork (budget 40 MB).
#
# Draw time is the activity manager's TotalTime from `am start -W`: until the Home window's first frame,
# which has the Dock in it (the artwork is decoded after and fades in). Memory is TOTAL PSS from
# `dumpsys meminfo`, read a few seconds after each warm visit so the artwork is in.
#
# Usage: launcher/measure_budgets.sh [runs]   (default 5 runs; the verdict uses the median)
# Needs the Launcher installed and one Keep List app to leave Home for. Pick the device with
# ANDROID_SERIAL (or point FUEGO_ADB at another adb). Runs on macOS's bash 3.2.
set -u

LAUNCHER=io.github.danajerban.fuegoos
HOME_ACTIVITY=$LAUNCHER/.HomeActivity
KEEP_APPS="com.netflix.ninja com.google.android.youtube.tv com.stremio.one com.spotify.tv.android"
RUNS=${1:-5}

adb_shell() {
  "${FUEGO_ADB:-adb}" shell "$@" | tr -d '\r'
}

fail() {
  echo "measure_budgets.sh: $*" >&2
  exit 2
}

# launch [-S]: opens Home with `am start -W` (-S stops the Launcher first) and prints "STATE MS".
launch() {
  adb_shell am start -W "$@" -n "$HOME_ACTIVITY" |
    sed -n -e 's/^LaunchState: //p' -e 's/^TotalTime: //p' | tr '\n' ' '
}

# leave_home: opens a Keep List app, so Home is stopped but the Launcher keeps running.
leave_home() {
  adb_shell am start -W -n "$away_activity" >/dev/null
  sleep 2
}

pss_kb() {
  adb_shell dumpsys meminfo "$LAUNCHER" | sed -n 's/^ *TOTAL PSS: *\([0-9]*\).*/\1/p'
}

median() {
  sort -n | awk '{ v[NR] = $1 } END { print v[int((NR + 1) / 2)] }'
}

worst() {
  sort -n | tail -n 1
}

# verdict NAME UNIT BUDGET VALUES...: prints the line for one budget, and returns 1 when the median is over.
verdict() {
  name=$1 unit=$2 budget=$3
  shift 3
  values=$(printf '%s\n' "$@")
  mid=$(printf '%s\n' "$values" | median)
  top=$(printf '%s\n' "$values" | worst)
  if [ "$mid" -le "$budget" ]; then result="within budget"; else result="OVER BUDGET"; fi
  echo "  $name: median $mid $unit, worst $top $unit over $# runs (budget $budget $unit): $result"
  echo "    runs: $*"
  [ "$mid" -le "$budget" ]
}

adb_shell pm path "$LAUNCHER" | grep -q '^package:' || fail "the Launcher ($LAUNCHER) is not installed"
away_activity=
for app in $KEEP_APPS; do
  away_activity=$(adb_shell cmd package resolve-activity --brief -a android.intent.action.MAIN \
    -c android.intent.category.LEANBACK_LAUNCHER "$app" | grep "^$app/" | tail -n 1)
  [ -n "$away_activity" ] && break
done
[ -n "$away_activity" ] || fail "no Keep List app is installed to leave Home for"

# home_draw_ms KIND [-S]: leaves Home, reopens it and prints its draw time. KIND is the launch state
# it must be (COLD, or WARM for HOT or WARM). When the app did not open, Home was never left and
# nothing is drawn, so it tries again, up to three times.
home_draw_ms() {
  kind=$1
  shift
  for _ in 1 2 3; do
    leave_home
    read -r state ms < <(launch "$@")
    case "$kind:${state:-}" in COLD:COLD | WARM:HOT | WARM:WARM) [ -n "${ms:-}" ] && echo "$ms" && return ;; esac
  done
  fail "run $i: Home never opened as a $kind start (last: '${state:-nothing}'); does $away_activity open?"
}

cold=() warm=() memory=()
i=0
while [ "$i" -lt "$RUNS" ]; do
  i=$((i + 1))
  ms=$(home_draw_ms COLD -S) || exit 2
  cold+=("$ms")
  ms=$(home_draw_ms WARM) || exit 2
  warm+=("$ms")
  sleep 3
  memory+=("$(($(pss_kb) / 1024))")
done

echo "Launcher budgets on $(adb_shell getprop ro.product.model) (Android $(adb_shell getprop ro.build.version.release)):"
ok=0
verdict "Cold Home Draw Time" ms 800 "${cold[@]}" || ok=1
verdict "Warm Home Draw Time" ms 200 "${warm[@]}" || ok=1
verdict "Memory (total PSS) on Home" MB 40 "${memory[@]}" || ok=1
exit "$ok"
