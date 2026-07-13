#!/usr/bin/env bash
# ck-assemble.sh — MECHANICAL assembly manifest for nix-cavekit (V6/C1 / T7).
# nix-cavekit PINS this repo + MERGES its portable content into the plugin
# derivation; this script enumerates WHAT gets merged and reports the
# formatVersion that rides the set-and-setting lock-bump propagation.
#
#   ck-assemble.sh <list|manifest|version|check> [REPO_ROOT]
#
# list     — print the portable content paths this repo contributes (sorted)
# manifest — print the assembly manifest: formatVersion + content paths
# version  — print the repo-declared formatVersion (drives lock-bump propagation)
# check    — verify the manifest is assemblable (marker + every path present)
set -euo pipefail

SUBCMD=""
ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      echo "ck-assemble: unknown option: $1 (see --help)" >&2
      exit 2
      ;;
    *)
      if [ -z "$SUBCMD" ]; then
        SUBCMD="$1"
      else
        ROOT="$1"
      fi
      ;;
  esac
  shift
done

# Default REPO_ROOT to the directory holding this script (the pinned source
# nix-cavekit assembles from), so list/manifest are cwd-independent.
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "$0")" && pwd)"
fi

# The portable content this repo contributes to the plugin derivation (C1):
# the mechanical ck-*.sh verbs + the LLM proposer skills. Derived from the
# tree (not hardcoded) so a new script/skill is merged without editing this.
# (No shell functions — this repo's no-shell-functions check forbids them.)
CONTENT="$(
  {
    for f in "$ROOT"/ck-*.sh; do
      [ -e "$f" ] || continue
      printf '%s\n' "${f#"$ROOT"/}"
    done
    if [ -d "$ROOT/.claude/skills" ]; then
      for f in "$ROOT"/.claude/skills/*.md; do
        [ -e "$f" ] || continue
        printf '%s\n' "${f#"$ROOT"/}"
      done
    fi
  } | LC_ALL=C sort -u
)"

# The formatVersion is only needed by version/manifest/check; resolving it for
# list would wrongly require SPEC.md. Read it (with error handling) up front
# for exactly those subcommands.
VER=""
case "$SUBCMD" in
  version | manifest | check)
    spec="$ROOT/SPEC.md"
    [ -f "$spec" ] || {
      echo "ck-assemble: no such file: $spec" >&2
      exit 2
    }
    if ! grep -qE '<!-- formatVersion: [0-9]+ -->' "$spec"; then
      echo "ck-assemble: no formatVersion marker in $spec" >&2
      exit 1
    fi
    VER="$(grep -oE '<!-- formatVersion: [0-9]+ -->' "$spec" |
      head -1 | grep -oE '[0-9]+')"
    ;;
esac

case "$SUBCMD" in
  list)
    [ -n "$CONTENT" ] && printf '%s\n' "$CONTENT"
    ;;
  version)
    echo "$VER"
    ;;
  manifest)
    echo "formatVersion $VER"
    [ -n "$CONTENT" ] && printf '%s\n' "$CONTENT" | sed 's/^/path /'
    ;;
  check)
    missing=0
    empty=0
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      if [ ! -e "$ROOT/$rel" ]; then
        echo "ck-assemble: missing content: $rel" >&2
        missing=$((missing + 1))
      elif [ ! -s "$ROOT/$rel" ]; then
        echo "ck-assemble: empty content: $rel" >&2
        empty=$((empty + 1))
      fi
    done <<EOF
$CONTENT
EOF
    if [ "$missing" -ne 0 ] || [ "$empty" -ne 0 ]; then
      echo "ck-assemble: NOT assemblable ($missing missing, $empty empty)" >&2
      exit 1
    fi
    count="$(printf '%s\n' "$CONTENT" | grep -c .)"
    echo "ck-assemble: ok (formatVersion $VER, $count content paths)"
    ;;
  "")
    echo "ck-assemble: usage: ck-assemble.sh <list|manifest|version|check> [REPO_ROOT]" >&2
    exit 2
    ;;
  *)
    echo "ck-assemble: unknown subcommand: $SUBCMD (see --help)" >&2
    exit 2
    ;;
esac
