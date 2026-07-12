#!/usr/bin/env bash
# ck-supersede.sh — MECHANICAL §V supersession tagger (V2 / I.ck-supersede mode A).
# Tags each loser `[superseded by <winner>]`; validates ids exist, idempotent,
# intra-kind, refuses self/unknown. Tags but does NOT evict (V1 does that).
#
#   ck-supersede.sh [--link] <winner> <loser>... [SPEC.md]
#
# --link also annotates the winner with `[supersedes <losers>]`.
set -euo pipefail

SPEC="SPEC.md"
LINK=0
WINNER=""
LOSERS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --link) LINK=1 ;;
        -h | --help)
            sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        --*)
            echo "ck-supersede: unknown option: $1 (see --help)" >&2
            exit 2
            ;;
        *)
            if [ -z "$WINNER" ]; then
                WINNER="$1"
            else
                LOSERS+=("$1")
            fi
            ;;
    esac
    shift
done

if [ -z "$WINNER" ] || [ ${#LOSERS[@]} -eq 0 ]; then
    echo "ck-supersede: usage: ck-supersede.sh [--link] <winner> <loser>..." >&2
    exit 2
fi

# If the last "loser" is a readable .md file, treat it as the SPEC path.
last="${LOSERS[-1]}"
if [ -f "$last" ]; then
    case "$last" in
        *.md)
            SPEC="$last"
            unset 'LOSERS[-1]'
            ;;
    esac
fi

if [ ${#LOSERS[@]} -eq 0 ]; then
    echo "ck-supersede: need at least one loser id" >&2
    exit 2
fi

[ -f "$SPEC" ] || {
    echo "ck-supersede: no such file: $SPEC" >&2
    exit 2
}

# Extract kind prefix + numeric part; validate format.
w_kind="${WINNER%%[0-9]*}"
w_num="${WINNER#"$w_kind"}"
case "$w_num" in
    '' | *[!0-9]*)
        echo "ck-supersede: invalid id: $WINNER" >&2
        exit 2
        ;;
esac
if [ -z "$w_kind" ]; then
    echo "ck-supersede: invalid id: $WINNER" >&2
    exit 2
fi

for loser in "${LOSERS[@]}"; do
    l_kind="${loser%%[0-9]*}"
    l_num="${loser#"$l_kind"}"
    case "$l_num" in
        '' | *[!0-9]*)
            echo "ck-supersede: invalid id: $loser" >&2
            exit 2
            ;;
    esac
    if [ -z "$l_kind" ]; then
        echo "ck-supersede: invalid id: $loser" >&2
        exit 2
    fi
    if [ "$l_kind" != "$w_kind" ]; then
        echo "ck-supersede: cross-kind: $WINNER vs $loser" >&2
        exit 2
    fi
    if [ "$loser" = "$WINNER" ]; then
        echo "ck-supersede: self-supersession refused: $loser" >&2
        exit 2
    fi
done

# Validate that every id has a definition line in the spec.
# §V/§C/§I: `^- <ID>: `   §T/§B: `^\| <ID> `
for id in "$WINNER" "${LOSERS[@]}"; do
    if ! grep -qE "^- ${id}: |^\| ${id} " "$SPEC"; then
        echo "ck-supersede: unknown id: $id (not in $SPEC)" >&2
        exit 2
    fi
done

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cp "$SPEC" "$tmp"

tagged=0
skipped=0

for loser in "${LOSERS[@]}"; do
    if grep -qE "^- ${loser}: .*\[superseded by ${WINNER}\]" "$tmp"; then
        skipped=$((skipped + 1))
        continue
    fi
    if grep -qE "^- ${loser}: .*\[superseded by " "$tmp"; then
        echo "ck-supersede: $loser already superseded (not by $WINNER)" >&2
        exit 2
    fi
    sed -i "s|^\\(- ${loser}: .*\\)$|\\1 [superseded by ${WINNER}]|" "$tmp"
    tagged=$((tagged + 1))
done

if [ "$LINK" = 1 ]; then
    loser_csv=""
    for loser in "${LOSERS[@]}"; do
        if [ -n "$loser_csv" ]; then
            loser_csv="${loser_csv}, ${loser}"
        else
            loser_csv="$loser"
        fi
    done
    if ! grep -qE "^- ${WINNER}: .*\[supersedes " "$tmp"; then
        sed -i "s|^\\(- ${WINNER}: .*\\)$|\\1 [supersedes ${loser_csv}]|" "$tmp"
    fi
fi

if [ "$tagged" -eq 0 ]; then
    echo "ck-supersede: already tagged — noop"
    exit 0
fi

mv "$tmp" "$SPEC"
echo "ck-supersede: tagged $tagged loser(s) [superseded by $WINNER]"
