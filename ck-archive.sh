#!/usr/bin/env bash
# ck-archive.sh — DETERMINISTIC, lossless SPEC.md compaction (V1/V4 / I.ck-archive).
# Evicts the coldest done §T (`x`) + §B rows + [superseded]-tagged §V to
# archived.md, keeping the newest K of §T/§B; threshold-gated; a pure text
# transform (no LLM ⇒ hookable). Rows MOVE — grep-by-id spans both files.
#
#   ck-archive.sh [--dry-run] [--threshold N] [--keep-recent K] [SPEC.md]
#
# Noop when ≤ threshold lines. Never touches pending/in-progress §T (`.`/`~`),
# live §V, or §G/§C/§I/§R.
set -euo pipefail

THRESHOLD=500
KEEP=20
DRY=0
SPEC="SPEC.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --threshold)
      THRESHOLD="$2"
      shift
      ;;
    --threshold=*) THRESHOLD="${1#*=}" ;;
    --keep-recent)
      KEEP="$2"
      shift
      ;;
    --keep-recent=*) KEEP="${1#*=}" ;;
    -h | --help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      echo "ck-archive: unknown option: $1 (see --help)" >&2
      exit 2
      ;;
    *) SPEC="$1" ;;
  esac
  shift
done

[ -f "$SPEC" ] || {
  echo "ck-archive: no such file: $SPEC" >&2
  exit 2
}
ARCHIVE="$(dirname "$SPEC")/archived.md"

lines="$(wc -l <"$SPEC" | tr -d ' ')"
if [ "$lines" -le "$THRESHOLD" ]; then
  echo "ck-archive: $SPEC = $lines lines ≤ threshold $THRESHOLD — noop"
  exit 0
fi

# Newest K ids of each kind stay in SPEC; the rest are evicted. Comma-delimited
# membership sets (",5,12,99,") for an exact awk lookup. pipefail is scoped OFF
# per subshell: a no-match grep (rc 1) or `tail -n 0` closing early (SIGPIPE, 141)
# must ⊥ abort — an empty keep-set (⇒ evict all) is legal.
keep_t=",$(
  set +o pipefail
  grep -oE '^\| T[0-9]+ \| x ' "$SPEC" | grep -oE '[0-9]+' | sort -n | tail -n "$KEEP" | tr '\n' ','
)"
keep_b=",$(
  set +o pipefail
  grep -oE '^\| B[0-9]+ ' "$SPEC" | grep -oE '[0-9]+' | sort -n | tail -n "$KEEP" | tr '\n' ','
)"

tmp_spec="$(mktemp)"
tmp_evict="$(mktemp)"
trap 'rm -f "$tmp_spec" "$tmp_evict"' EXIT

# One pass: a done-§T or §B row whose id is NOT in its keep-set → evicted (to
# tmp_evict, oldest-first as they appear); everything else → new spec (stdout).
# idof extracted inline (⊥ an awk function — the no-shell-functions lint greps
# the .sh text for `function ` and can't tell awk's keyword from bash's).
awk -v kt="$keep_t" -v kb="$keep_b" -v evf="$tmp_evict" '
  {
    id = $0; sub(/^\| [TB]/, "", id); sub(/ .*/, "", id)
    if ($0 ~ /^\| T[0-9]+ \| x \|/) {
      if (index(kt, "," id ",") == 0) { print >> evf; next }
    } else if ($0 ~ /^\| B[0-9]+ \|/) {
      if (index(kb, "," id ",") == 0) { print >> evf; next }
    } else if ($0 ~ /^- V[0-9]+: .*\[superseded by V[0-9]+\]/) {
      print >> evf; next
    }
    print
  }
' "$SPEC" >"$tmp_spec"

evicted="$(grep -cE '^\| [TB][0-9]+ |^- V[0-9]+: ' "$tmp_evict" || true)"
projected="$(wc -l <"$tmp_spec" | tr -d ' ')"

if [ "$evicted" -eq 0 ]; then
  echo "ck-archive: nothing to evict — noop"
  exit 0
fi

if [ "$DRY" = 1 ]; then
  echo "ck-archive: DRY-RUN — would evict $evicted row(s) → $ARCHIVE"
  echo "ck-archive: $SPEC $lines → $projected lines (keep newest $KEEP of §T·§B)"
  exit 0
fi

{
  echo ""
  echo "## Archived $(date +%Y-%m-%d) (ck:archive)"
  echo ""
  cat "$tmp_evict"
} >>"$ARCHIVE"
mv "$tmp_spec" "$SPEC"

echo "ck-archive: evicted $evicted row(s) → $ARCHIVE; $SPEC $lines → $projected lines"
