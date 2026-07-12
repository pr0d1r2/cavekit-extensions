#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031
# Coverage for ck-supersede.sh mode A — MECHANICAL §V supersession tagger
# (V2/I.ck-supersede). Tags losers `[superseded by <winner>]`; validates ids
# exist, idempotent, intra-kind, refuses self/unknown. Does NOT evict.

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-file/load.bash"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/ck-supersede.sh"
  TMP="$(mktemp -d)"
  SPEC="$TMP/SPEC.md"
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: first invariant
- V2: second invariant
- V3: third replaces first
- V4: fourth invariant
## §T TASKS
| T1 | . | task one | V1 |
| T2 | x | task two done | V2 |
## §B BUGS
| B1 | 2026-01-01 | a bug | fixed |
EOF
}
teardown() { rm -rf "$TMP"; }

@test "script exists and is executable" {
  assert_file_exist "$SCRIPT"
}

@test "tags single loser [superseded by <winner>] (V2)" {
  run bash "$SCRIPT" V3 V1 "$SPEC"
  assert_success
  assert_output --partial "tagged 1 loser(s)"
  run grep '^- V1: ' "$SPEC"
  assert_success
  assert_output --partial "[superseded by V3]"
}

@test "tags multiple losers in one invocation (V2)" {
  run bash "$SCRIPT" V3 V1 V2 "$SPEC"
  assert_success
  assert_output --partial "tagged 2 loser(s)"
  run grep '^- V1: ' "$SPEC"
  assert_output --partial "[superseded by V3]"
  run grep '^- V2: ' "$SPEC"
  assert_output --partial "[superseded by V3]"
}

@test "winner line is NOT tagged (V2)" {
  run bash "$SCRIPT" V3 V1 "$SPEC"
  assert_success
  run grep '^- V3: ' "$SPEC"
  assert_success
  refute_output --partial "[superseded"
}

@test "idempotent — re-tag is a noop (V2)" {
  bash "$SCRIPT" V3 V1 "$SPEC"
  before="$(cat "$SPEC")"
  run bash "$SCRIPT" V3 V1 "$SPEC"
  assert_success
  assert_output --partial "already tagged"
  assert_output --partial "noop"
  assert_equal "$(cat "$SPEC")" "$before"
}

@test "refuses self-supersession (V2)" {
  run bash "$SCRIPT" V3 V3 "$SPEC"
  assert_failure
  assert_output --partial "self-supersession"
}

@test "refuses cross-kind ids (V2 intra-kind)" {
  run bash "$SCRIPT" V3 T1 "$SPEC"
  assert_failure
  assert_output --partial "cross-kind"
}

@test "refuses re-supersession by different winner (V2 idempotent)" {
  bash "$SCRIPT" V3 V1 "$SPEC"
  run bash "$SCRIPT" V4 V1 "$SPEC"
  assert_failure
  assert_output --partial "already superseded"
  # original tag unchanged
  run grep '^- V1: ' "$SPEC"
  assert_output --partial "[superseded by V3]"
  refute_output --partial "[superseded by V4]"
}

@test "refuses unknown winner id (V2)" {
  run bash "$SCRIPT" V99 V1 "$SPEC"
  assert_failure
  assert_output --partial "unknown id"
  assert_output --partial "V99"
}

@test "refuses unknown loser id (V2)" {
  run bash "$SCRIPT" V3 V99 "$SPEC"
  assert_failure
  assert_output --partial "unknown id"
  assert_output --partial "V99"
}

@test "refuses invalid id format" {
  run bash "$SCRIPT" 99 V1 "$SPEC"
  assert_failure
  assert_output --partial "invalid id"
}

@test "no args → usage error" {
  run bash "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "winner only, no loser → usage error" {
  run bash "$SCRIPT" V3
  assert_failure
  assert_output --partial "usage"
}

@test "--link annotates winner with [supersedes ...] (T1)" {
  run bash "$SCRIPT" --link V3 V1 V2 "$SPEC"
  assert_success
  run grep '^- V3: ' "$SPEC"
  assert_success
  assert_output --partial "[supersedes V1, V2]"
}

@test "--link idempotent — does not duplicate annotation" {
  bash "$SCRIPT" --link V3 V1 "$SPEC"
  before="$(cat "$SPEC")"
  run bash "$SCRIPT" --link V3 V1 "$SPEC"
  assert_success
  assert_output --partial "noop"
  assert_equal "$(cat "$SPEC")" "$before"
}

@test "does NOT modify non-target §V lines (V2)" {
  before_v4="$(grep '^- V4: ' "$SPEC")"
  run bash "$SCRIPT" V3 V1 "$SPEC"
  assert_success
  assert_equal "$(grep '^- V4: ' "$SPEC")" "$before_v4"
}

@test "does NOT modify §T or §B lines (V2)" {
  before_t1="$(grep -F '| T1 ' "$SPEC")"
  before_b1="$(grep -F '| B1 ' "$SPEC")"
  run bash "$SCRIPT" V3 V1 "$SPEC"
  assert_success
  assert_equal "$(grep -F '| T1 ' "$SPEC")" "$before_t1"
  assert_equal "$(grep -F '| B1 ' "$SPEC")" "$before_b1"
}

@test "default SPEC.md missing → error" {
  cd "$TMP"
  rm -f SPEC.md
  run bash "$SCRIPT" V3 V1
  assert_failure
  assert_output --partial "no such file"
}

@test "--help prints usage" {
  run bash "$SCRIPT" --help
  assert_success
  assert_output --partial "ck-supersede"
}

@test "unknown option → error" {
  run bash "$SCRIPT" --bogus V3 V1 "$SPEC"
  assert_failure
  assert_output --partial "unknown option"
}
