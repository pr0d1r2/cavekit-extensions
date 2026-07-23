#!/usr/bin/env bash
# ck-check-skip.sh — MECHANICAL superseded-§V filter for /check (V4 / I.check-skip).
# Lists active or superseded §V ids so /check can skip enforcement
# of [superseded by VN]-tagged invariants.
#
#   ck-check-skip.sh <list-active|list-skipped|is-skipped> [VN] [SPEC.md]
#
# list-active  — print §V ids that /check should enforce (not superseded)
# list-skipped — print §V ids that /check should skip (superseded)
# is-skipped   — exit 0 if VN is superseded, exit 1 if active
set -euo pipefail

SPEC="SPEC.md"
SUBCMD=""
ARG1=""
ARG2=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      echo "ck-check-skip: unknown option: $1 (see --help)" >&2
      exit 2
      ;;
    *)
      if [ -z "$SUBCMD" ]; then
        SUBCMD="$1"
      elif [ -z "$ARG1" ]; then
        ARG1="$1"
      else
        ARG2="$1"
      fi
      ;;
  esac
  shift
done

case "$SUBCMD" in
  list-active)
    [ -n "$ARG1" ] && SPEC="$ARG1"
    [ -f "$SPEC" ] || {
      echo "ck-check-skip: no such file: $SPEC" >&2
      exit 2
    }
    awk '/^- V[0-9]+: / && !/\[superseded by V[0-9]+\]/ {
          id = $2; sub(/:$/, "", id); print id
        }' "$SPEC"
    ;;
  list-skipped)
    [ -n "$ARG1" ] && SPEC="$ARG1"
    [ -f "$SPEC" ] || {
      echo "ck-check-skip: no such file: $SPEC" >&2
      exit 2
    }
    awk '/^- V[0-9]+: .*\[superseded by V[0-9]+\]/ {
          id = $2; sub(/:$/, "", id); print id
        }' "$SPEC"
    ;;
  is-skipped)
    [ -n "$ARG1" ] || {
      echo "ck-check-skip: is-skipped requires a VN argument" >&2
      exit 2
    }
    v_kind="${ARG1%%[0-9]*}"
    v_num="${ARG1#"$v_kind"}"
    if [ "$v_kind" != "V" ]; then
      echo "ck-check-skip: invalid id: $ARG1 (expected V<number>)" >&2
      exit 2
    fi
    case "$v_num" in
      '' | *[!0-9]*)
        echo "ck-check-skip: invalid id: $ARG1 (expected V<number>)" >&2
        exit 2
        ;;
    esac
    [ -n "$ARG2" ] && SPEC="$ARG2"
    [ -f "$SPEC" ] || {
      echo "ck-check-skip: no such file: $SPEC" >&2
      exit 2
    }
    if grep -qE "^- ${ARG1}: .*\[superseded by V[0-9]+\]" "$SPEC"; then
      echo "ck-check-skip: $ARG1 is superseded — skip"
      exit 0
    fi
    if grep -qE "^- ${ARG1}: " "$SPEC"; then
      echo "ck-check-skip: $ARG1 is active — enforce"
      exit 1
    fi
    echo "ck-check-skip: unknown id: $ARG1 (not in $SPEC)" >&2
    exit 2
    ;;
  "")
    echo "ck-check-skip: usage: ck-check-skip.sh <list-active|list-skipped|is-skipped> [VN] [SPEC.md]" >&2
    exit 2
    ;;
  *)
    echo "ck-check-skip: unknown subcommand: $SUBCMD (see --help)" >&2
    exit 2
    ;;
esac
