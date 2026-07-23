#!/usr/bin/env bash
# ck-format-version.sh — format-version primitive (V6/C2 / I.format-version / T5).
# The on-disk schema constant (lib.formatVersion) + repo-declared formatVersion
# marker; checks compatibility (the plugin/format axis split).
#
#   ck-format-version.sh <current|read|check|stamp> [SPEC.md]
#
# current  — print lib.formatVersion (the tooling's on-disk schema version)
# read     — print the repo's declared formatVersion from SPEC.md
# check    — verify compatibility (repo <= tooling)
# stamp    — write/update the formatVersion marker in SPEC.md
set -euo pipefail

FORMAT_VERSION=1

SPEC="SPEC.md"
SUBCMD=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      echo "ck-format-version: unknown option: $1 (see --help)" >&2
      exit 2
      ;;
    *)
      if [ -z "$SUBCMD" ]; then
        SUBCMD="$1"
      else
        SPEC="$1"
      fi
      ;;
  esac
  shift
done

case "$SUBCMD" in
  current)
    echo "$FORMAT_VERSION"
    ;;
  read)
    [ -f "$SPEC" ] || {
      echo "ck-format-version: no such file: $SPEC" >&2
      exit 2
    }
    if ! grep -qE '<!-- formatVersion: [0-9]+ -->' "$SPEC"; then
      echo "ck-format-version: no formatVersion marker in $SPEC" >&2
      exit 1
    fi
    ver="$(grep -oE '<!-- formatVersion: [0-9]+ -->' "$SPEC" |
      head -1 | grep -oE '[0-9]+')"
    echo "$ver"
    ;;
  check)
    [ -f "$SPEC" ] || {
      echo "ck-format-version: no such file: $SPEC" >&2
      exit 2
    }
    if ! grep -qE '<!-- formatVersion: [0-9]+ -->' "$SPEC"; then
      echo "ck-format-version: no formatVersion marker in $SPEC" >&2
      exit 1
    fi
    ver="$(grep -oE '<!-- formatVersion: [0-9]+ -->' "$SPEC" |
      head -1 | grep -oE '[0-9]+')"
    if [ "$ver" -gt "$FORMAT_VERSION" ]; then
      echo "ck-format-version: $SPEC formatVersion $ver > tooling $FORMAT_VERSION — upgrade tooling" >&2
      exit 1
    fi
    if [ "$ver" -lt "$FORMAT_VERSION" ]; then
      echo "ck-format-version: ok (formatVersion $ver; current is $FORMAT_VERSION — migrate available)"
      exit 0
    fi
    echo "ck-format-version: ok (formatVersion $ver)"
    ;;
  stamp)
    [ -f "$SPEC" ] || {
      echo "ck-format-version: no such file: $SPEC" >&2
      exit 2
    }
    if grep -qE '<!-- formatVersion: [0-9]+ -->' "$SPEC"; then
      old="$(grep -oE '<!-- formatVersion: [0-9]+ -->' "$SPEC" |
        grep -oE '[0-9]+' | head -1)"
      if [ "$old" = "$FORMAT_VERSION" ]; then
        echo "ck-format-version: $SPEC already at formatVersion $FORMAT_VERSION — noop"
        exit 0
      fi
      sed -i "s/<!-- formatVersion: [0-9][0-9]* -->/<!-- formatVersion: $FORMAT_VERSION -->/" "$SPEC"
      echo "ck-format-version: $SPEC formatVersion $old → $FORMAT_VERSION"
    else
      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT
      awk -v ver="$FORMAT_VERSION" '
              NR == 1 && /^# / {
                print
                getline
                if ($0 == "") {
                  print ""
                  print "<!-- formatVersion: " ver " -->"
                  print ""
                } else {
                  print ""
                  print "<!-- formatVersion: " ver " -->"
                  print ""
                  print
                }
                next
              }
              NR == 1 {
                print "<!-- formatVersion: " ver " -->"
                print ""
                print
                next
              }
              { print }
            ' "$SPEC" >"$tmp"
      mv "$tmp" "$SPEC"
      echo "ck-format-version: stamped $SPEC with formatVersion $FORMAT_VERSION"
    fi
    ;;
  "")
    echo "ck-format-version: usage: ck-format-version.sh <current|read|check|stamp> [SPEC.md]" >&2
    exit 2
    ;;
  *)
    echo "ck-format-version: unknown subcommand: $SUBCMD (see --help)" >&2
    exit 2
    ;;
esac
