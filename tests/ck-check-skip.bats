#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031
# Coverage for ck-check-skip.sh — MECHANICAL superseded-§V filter for /check
# (V4/I.check-skip/T6). Tests: list-active, list-skipped, is-skipped subcommands;
# superseded vs active §V filtering; error handling.

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-file/load.bash"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/ck-check-skip.sh"
  TMP="$(mktemp -d)"
  SPEC="$TMP/SPEC.md"
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: current law
- V2: old rule [superseded by V1]
- V3: active invariant
- V4: also old [superseded by V3]
## §T TASKS
| T1 | x | done | V1 |
| T2 | . | pending | V3 |
EOF
}
teardown() { rm -rf "$TMP"; }

@test "script exists" {
  assert_file_exist "$SCRIPT"
}

# --- list-active ---

@test "list-active returns non-superseded §V ids (V4)" {
  run bash "$SCRIPT" list-active "$SPEC"
  assert_success
  assert_line "V1"
  assert_line "V3"
  refute_line "V2"
  refute_line "V4"
}

@test "list-active with all active → lists all (V4)" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: first
- V2: second
- V3: third
EOF
  run bash "$SCRIPT" list-active "$SPEC"
  assert_success
  assert_line "V1"
  assert_line "V2"
  assert_line "V3"
}

@test "list-active with all superseded → empty output (V4)" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: old [superseded by V3]
- V2: also old [superseded by V3]
## §T TASKS
| T1 | . | pending | V1 |
EOF
  run bash "$SCRIPT" list-active "$SPEC"
  assert_success
  assert_output ""
}

@test "list-active with no §V section → empty output (V4)" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §T TASKS
| T1 | . | pending | V1 |
EOF
  run bash "$SCRIPT" list-active "$SPEC"
  assert_success
  assert_output ""
}

@test "list-active ignores §T/§B/§C rows (V4)" {
  run bash "$SCRIPT" list-active "$SPEC"
  assert_success
  refute_line "T1"
  refute_line "T2"
}

@test "list-active defaults to SPEC.md in cwd" {
  subdir="$TMP/sub"
  mkdir -p "$subdir"
  cp "$SPEC" "$subdir/SPEC.md"
  cd "$subdir"
  run bash "$SCRIPT" list-active
  assert_success
  assert_line "V1"
  assert_line "V3"
}

@test "list-active missing file → error" {
  run bash "$SCRIPT" list-active /nonexistent/SPEC.md
  assert_failure
  assert_output --partial "no such file"
}

# --- list-skipped ---

@test "list-skipped returns superseded §V ids (V4)" {
  run bash "$SCRIPT" list-skipped "$SPEC"
  assert_success
  assert_line "V2"
  assert_line "V4"
  refute_line "V1"
  refute_line "V3"
}

@test "list-skipped with no superseded → empty output (V4)" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: active
- V2: also active
EOF
  run bash "$SCRIPT" list-skipped "$SPEC"
  assert_success
  assert_output ""
}

@test "list-skipped with no §V section → empty output (V4)" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §T TASKS
| T1 | . | pending | V1 |
EOF
  run bash "$SCRIPT" list-skipped "$SPEC"
  assert_success
  assert_output ""
}

@test "list-skipped missing file → error" {
  run bash "$SCRIPT" list-skipped /nonexistent/SPEC.md
  assert_failure
  assert_output --partial "no such file"
}

# --- is-skipped ---

@test "is-skipped returns 0 for superseded §V (V4)" {
  run bash "$SCRIPT" is-skipped V2 "$SPEC"
  assert_success
  assert_output --partial "superseded"
  assert_output --partial "skip"
}

@test "is-skipped returns 1 for active §V (V4)" {
  run bash "$SCRIPT" is-skipped V1 "$SPEC"
  [ "$status" -eq 1 ]
  assert_output --partial "active"
  assert_output --partial "enforce"
}

@test "is-skipped returns 2 for unknown §V (V4)" {
  run bash "$SCRIPT" is-skipped V99 "$SPEC"
  [ "$status" -eq 2 ]
  assert_output --partial "unknown id"
}

@test "is-skipped with no VN → error" {
  run bash "$SCRIPT" is-skipped
  assert_failure
  assert_output --partial "requires"
}

@test "is-skipped with non-V id → error" {
  run bash "$SCRIPT" is-skipped T1 "$SPEC"
  assert_failure
  assert_output --partial "invalid id"
}

@test "is-skipped with bare number → error" {
  run bash "$SCRIPT" is-skipped 42 "$SPEC"
  assert_failure
  assert_output --partial "invalid id"
}

@test "is-skipped missing file → error" {
  run bash "$SCRIPT" is-skipped V1 /nonexistent/SPEC.md
  assert_failure
  assert_output --partial "no such file"
}

@test "is-skipped defaults to SPEC.md in cwd" {
  subdir="$TMP/sub"
  mkdir -p "$subdir"
  cp "$SPEC" "$subdir/SPEC.md"
  cd "$subdir"
  run bash "$SCRIPT" is-skipped V2
  assert_success
  assert_output --partial "superseded"
}

# --- list-active + list-skipped complement (V4) ---

@test "list-active and list-skipped together cover all §V ids (V4)" {
  active="$(bash "$SCRIPT" list-active "$SPEC" | sort)"
  skipped="$(bash "$SCRIPT" list-skipped "$SPEC" | sort)"
  all="$(printf '%s\n%s\n' "$active" "$skipped" | sort)"
  expected="$(grep -oE '^- V[0-9]+' "$SPEC" | sed 's/^- //' | sort)"
  assert_equal "$all" "$expected"
}

# --- error handling ---

@test "no subcommand → usage error" {
  run bash "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "unknown subcommand → error" {
  run bash "$SCRIPT" bogus "$SPEC"
  assert_failure
  assert_output --partial "unknown subcommand"
}

@test "--help prints usage" {
  run bash "$SCRIPT" --help
  assert_success
  assert_output --partial "ck-check-skip"
  assert_output --partial "list-active"
  assert_output --partial "list-skipped"
  assert_output --partial "is-skipped"
}

@test "unknown option → error" {
  run bash "$SCRIPT" --bogus
  assert_failure
  assert_output --partial "unknown option"
}
