#!/bin/bash
# Tests for lists/check.sh, from the outside: a lists directory in, exit code and report out.
# Run from the repo root: lists/check_test.sh
# Works on macOS /bin/bash 3.2.

set -u

here=$(cd "$(dirname "$0")" && pwd)
check="$here/check.sh"
work=$(mktemp -d "${TMPDIR:-/tmp}/fuego-lists-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

# A small, valid set of the four lists.
write_valid_lists() {
  dir=$1
  mkdir -p "$dir"
  cat >"$dir/keep.txt" <<'EOF'
# package|confirmed_on_tv|reason
com.example.keep|false|An app the owner keeps
EOF
  cat >"$dir/must-keep.txt" <<'EOF'
# package|confirmed_on_tv|reason
com.example.system|false|A system part the TV needs

com.example.keep|false|On the Keep List
EOF
  cat >"$dir/known-bloat.txt" <<'EOF'
# package|confirmed_on_tv|reason
com.example.bloat|false|Something the TV runs without
EOF
  cat >"$dir/takeover.txt" <<'EOF'
# package|confirmed_on_tv|reason
com.example.launcher|false|The Stock Launcher
EOF
}

# run_check NAME DIR EXPECTED_EXIT [EXPECTED_TEXT]
run_check() {
  name=$1 dir=$2 want_exit=$3 want_text=${4:-}
  out=$("$check" "$dir" 2>&1)
  got_exit=$?
  if [ "$got_exit" -ne "$want_exit" ]; then
    echo "FAIL $name: exit $got_exit, want $want_exit"
    printf '%s\n' "$out" | sed 's/^/    /'
    failed=$((failed + 1))
    return
  fi
  if [ -n "$want_text" ] && ! printf '%s\n' "$out" | grep -qF -- "$want_text"; then
    echo "FAIL $name: output lacks \"$want_text\""
    printf '%s\n' "$out" | sed 's/^/    /'
    failed=$((failed + 1))
    return
  fi
  echo "ok   $name"
  passed=$((passed + 1))
}

# Each case gets its own copy of the valid lists.
fresh() {
  d="$work/$1"
  write_valid_lists "$d"
  echo "$d"
}

d=$(fresh valid)
run_check "valid lists pass" "$d" 0

d=$(fresh must-keep-and-bloat)
echo 'com.example.system|false|Wrongly listed as Bloat' >>"$d/known-bloat.txt"
run_check "a package on Must-Keep and Known-Bloat fails" "$d" 1 "com.example.system"

d=$(fresh takeover-and-bloat)
echo 'com.example.launcher|false|Wrongly listed as Bloat' >>"$d/known-bloat.txt"
run_check "a Takeover Package on Known-Bloat fails" "$d" 1 "com.example.launcher"

d=$(fresh keep-not-must-keep)
echo 'com.example.another|false|Another app the owner keeps' >>"$d/keep.txt"
run_check "a Keep List app missing from Must-Keep fails" "$d" 1 "com.example.another"

d=$(fresh no-reason)
echo 'com.example.quiet|false|' >>"$d/known-bloat.txt"
run_check "an entry without a reason fails" "$d" 1 "known-bloat.txt:3"

d=$(fresh bad-marker)
echo 'com.example.unsure|maybe|Not sure' >>"$d/known-bloat.txt"
run_check "a confirmed-on-TV marker other than true or false fails" "$d" 1 "known-bloat.txt:3"

d=$(fresh padded-id)
echo 'com.example.padded |false|A space before the separator' >>"$d/known-bloat.txt"
run_check "a package ID that is not a plain package name fails" "$d" 1 "known-bloat.txt:3"

d=$(fresh blank-with-spaces)
printf '  \t\n' >>"$d/known-bloat.txt"
run_check "a line of only spaces and tabs is skipped, as the script skips it" "$d" 0 "lists OK"

d=$(fresh missing-list)
rm "$d/takeover.txt"
run_check "a missing list file fails" "$d" 1 "takeover.txt"

run_check "the repo's own lists pass" "$here" 0 "lists OK"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
