#!/bin/bash
# Checks the package lists. Run from the repo root: lists/check.sh [lists-dir]
# Exits 0 and prints "lists OK" when every rule holds, or prints each problem and exits 1.
# Works on macOS /bin/bash 3.2.

set -u

dir=${1:-$(cd "$(dirname "$0")" && pwd)}
problems=0

problem() {
  echo "check: $*" >&2
  problems=$((problems + 1))
}

# Whether a line is skipped: a comment, or blank (only spaces and tabs), as script/fuego skips it.
skipped_line() {
  case $1 in
    '#'*) return 0 ;;
    *[![:space:]]*) return 1 ;;
  esac
  return 0
}

# Prints the package IDs in a list file, one per line, skipping comments and blank lines.
ids() {
  while IFS= read -r line; do
    skipped_line "$line" && continue
    echo "${line%%|*}"
  done <"$dir/$1"
}

# Checks every entry in a list file has the form package|confirmed_on_tv|reason.
check_entries() {
  n=0
  while IFS= read -r line; do
    n=$((n + 1))
    skipped_line "$line" && continue
    IFS='|' read -r pkg confirmed reason <<EOF
$line
EOF
    if ! printf '%s\n' "$pkg" | grep -Eq '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$'; then
      problem "$1:$n: \"$pkg\" is not a package name"
    fi
    case $confirmed in
      true | false) ;;
      *) problem "$1:$n: confirmed_on_tv is \"$confirmed\", want true or false" ;;
    esac
    if [ -z "$reason" ]; then
      problem "$1:$n: $pkg has no reason"
    fi
  done <"$dir/$1"
}

for list in keep.txt must-keep.txt known-bloat.txt takeover.txt; do
  if [ ! -f "$dir/$list" ]; then
    problem "$dir/$list is missing"
  fi
done
if [ "$problems" -gt 0 ]; then
  exit 1
fi

for list in keep.txt must-keep.txt known-bloat.txt takeover.txt; do
  check_entries "$list"
done

# Prints the IDs on both lists.
on_both() {
  comm -12 <(ids "$1" | sort -u) <(ids "$2" | sort -u)
}

# Prints the IDs on the first list but not the second.
only_on_first() {
  comm -23 <(ids "$1" | sort -u) <(ids "$2" | sort -u)
}

for pkg in $(only_on_first keep.txt must-keep.txt); do
  problem "$pkg is on the Keep List but missing from the Must-Keep List"
done

for pkg in $(on_both must-keep.txt known-bloat.txt); do
  problem "$pkg is on both the Must-Keep List and the Known-Bloat List"
done

for pkg in $(on_both takeover.txt known-bloat.txt); do
  problem "$pkg is a Takeover Package and must not be on the Known-Bloat List"
done

if [ "$problems" -gt 0 ]; then
  exit 1
fi
echo "lists OK"
