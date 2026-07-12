#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031
# Coverage for scripts/ck-archive.sh — DETERMINISTIC lossless SPEC compaction
# (V1/V4/I.ck-archive). A synthetic fixture with a low threshold drives eviction:
# done §T (`x`) + §B evict oldest-first keeping newest K; [superseded]-tagged §V
# always evict; pending/in-progress §T and live §V/§C/§I are NEVER touched;
# rows MOVE to archived.md (grep-by-id spans both).

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-file/load.bash"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/ck-archive.sh"
  TMP="$(mktemp -d)"
  SPEC="$TMP/SPEC.md"
  # 5 done §T (T1..T5), 1 pending (T6 `.`), 1 in-progress (T7 `~`), 3 §B, plus
  # live §V/§C + 1 superseded §V. 17 content lines ⇒ threshold 4 triggers.
  cat >"$SPEC" <<'EOF'
# SPEC
## §C CONSTRAINTS
- C1: never break the sandbox
## §V INVARIANTS
- V1: the one true invariant
- V2: old invariant [superseded by V1]
## §T TASKS
| T1 | x | oldest done | C1 |
| T2 | x | done two | C1 |
| T3 | x | done three | C1 |
| T4 | x | done four | C1 |
| T5 | x | newest done | C1 |
| T6 | . | pending — stays | C1 |
| T7 | ~ | in progress — stays | C1 |
## §B BUGS
| B1 | 2026-01-01 | oldest bug | fixed |
| B2 | 2026-01-02 | bug two | fixed |
| B3 | 2026-01-03 | newest bug | fixed |
EOF
}
teardown() { rm -rf "$TMP"; }

@test "script exists" {
  assert_file_exist "$SCRIPT"
}

@test "below threshold → noop, file unchanged" {
  before="$(cat "$SPEC")"
  run bash "$SCRIPT" --threshold 500 "$SPEC"
  assert_success
  assert_output --partial "noop"
  assert_equal "$(cat "$SPEC")" "$before"
  assert_file_not_exist "$TMP/archived.md"
}

@test "above threshold → evicts old done §T, keeps newest K (V1)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  # kept in SPEC: newest 2 done (T4,T5); evicted: T1,T2,T3
  run grep -E '^\| T4 \| x ' "$SPEC"; assert_success
  run grep -E '^\| T5 \| x ' "$SPEC"; assert_success
  run grep -E '^\| T1 \| x ' "$SPEC"; assert_failure
  run grep -E '^\| T3 \| x ' "$SPEC"; assert_failure
  # evicted rows land in archived.md
  run grep -E '^\| T1 \| x ' "$TMP/archived.md"; assert_success
}

@test "NEVER evicts pending (.) or in-progress (~) §T (V1)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 0 "$SPEC"
  assert_success
  run grep -E '^\| T6 \| \. ' "$SPEC"; assert_success
  run grep -E '^\| T7 \| ~ ' "$SPEC"; assert_success
  # even with keep-recent 0, pending/wip never leave
  run grep -E '^\| T6 ' "$TMP/archived.md"; assert_failure
}

@test "evicts old §B keeping newest K (V1)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 1 "$SPEC"
  assert_success
  run grep -E '^\| B3 ' "$SPEC"; assert_success          # newest kept
  run grep -E '^\| B1 ' "$SPEC"; assert_failure          # oldest evicted
  run grep -E '^\| B1 ' "$TMP/archived.md"; assert_success
}

@test "NEVER touches §V/§C/§I live lines (V1)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 0 "$SPEC"
  assert_success
  run grep -E '^- V1: ' "$SPEC"; assert_success
  run grep -E '^- C1: ' "$SPEC"; assert_success
  # the §V/§C DEFINITION lines must never be evicted (a `C1` in a task's cites
  # column legitimately rides along in the archived row — that's not the §C def)
  run grep -E '^- (V1|C1): ' "$TMP/archived.md"; assert_failure
}

@test "--dry-run mutates nothing" {
  before="$(cat "$SPEC")"
  run bash "$SCRIPT" --dry-run --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  assert_output --partial "DRY-RUN"
  assert_equal "$(cat "$SPEC")" "$before"
  assert_file_not_exist "$TMP/archived.md"
}

@test "IDs preserved — grep -r spans SPEC + archived (V1)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  # every original id still resolvable across the two files
  run grep -rhE '^\| T1 ' "$SPEC" "$TMP/archived.md"; assert_success   # archived
  run grep -rhE '^\| T5 ' "$SPEC" "$TMP/archived.md"; assert_success   # live
}

@test "idempotent — re-run once under threshold → noop" {
  bash "$SCRIPT" --threshold 4 --keep-recent 2 "$SPEC"
  # after eviction the fixture is small; a 500-threshold re-run is a noop
  run bash "$SCRIPT" --threshold 500 "$SPEC"
  assert_success
  assert_output --partial "noop"
}

@test "dated archive block header written (V1)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  run grep -E '^## Archived [0-9]{4}-[0-9]{2}-[0-9]{2} \(ck:archive\)' "$TMP/archived.md"
  assert_success
}

@test "evicts [superseded]-tagged §V lines (V4)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  run grep -E '^- V2: ' "$SPEC"; assert_failure
  run grep -E '^- V2: .*\[superseded by V1\]' "$TMP/archived.md"; assert_success
}

@test "NEVER evicts live (non-superseded) §V lines (V4)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 0 "$SPEC"
  assert_success
  run grep -E '^- V1: ' "$SPEC"; assert_success
  run grep -E '^- V1: ' "$TMP/archived.md"; assert_failure
}

@test "superseded §V IDs preserved — grep spans SPEC + archived (V4)" {
  run bash "$SCRIPT" --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  run grep -rhE '^- V2: ' "$SPEC" "$TMP/archived.md"; assert_success
  run grep -rhE '^- V1: ' "$SPEC" "$TMP/archived.md"; assert_success
}

@test "--dry-run with superseded §V counts but mutates nothing (V4)" {
  before="$(cat "$SPEC")"
  run bash "$SCRIPT" --dry-run --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  assert_output --partial "DRY-RUN"
  assert_equal "$(cat "$SPEC")" "$before"
  assert_file_not_exist "$TMP/archived.md"
}

@test "multiple superseded §V lines all evict (V4)" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: current law
- V2: old thing [superseded by V1]
- V3: also old [superseded by V1]
- V4: yet another old [superseded by V1]
## §T TASKS
| T1 | x | done | V1 |
| T2 | x | done | V1 |
| T3 | . | pending | V1 |
EOF
  run bash "$SCRIPT" --threshold 4 --keep-recent 2 "$SPEC"
  assert_success
  run grep -E '^- V1: ' "$SPEC"; assert_success
  run grep -E '^- V2: ' "$SPEC"; assert_failure
  run grep -E '^- V3: ' "$SPEC"; assert_failure
  run grep -E '^- V4: ' "$SPEC"; assert_failure
  run grep -cE '^- V[0-9]+: ' "$TMP/archived.md"
  assert_output "3"
}

@test "§V without [superseded] tag is never evicted even with keep-recent 0 (V4)" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: live one
- V2: live two
- V3: live three
## §T TASKS
| T1 | x | done | V1 |
| T2 | x | done | V1 |
| T3 | x | done | V1 |
| T4 | x | done | V1 |
| T5 | x | done | V1 |
EOF
  run bash "$SCRIPT" --threshold 4 --keep-recent 0 "$SPEC"
  assert_success
  run grep -E '^- V1: ' "$SPEC"; assert_success
  run grep -E '^- V2: ' "$SPEC"; assert_success
  run grep -E '^- V3: ' "$SPEC"; assert_success
}
