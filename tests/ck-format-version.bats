#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031
# Coverage for ck-format-version.sh — format-version primitive (V6/C2/T5).
# Tests: subcommands (current, read, check, stamp), error handling,
# marker insertion/update, format compatibility checking.

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-file/load.bash"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/ck-format-version.sh"
  TMP="$(mktemp -d)"
  SPEC="$TMP/SPEC.md"
  cat >"$SPEC" <<'EOF'
# SPEC

<!-- formatVersion: 1 -->

## §G GOAL

goals here

## §V INVARIANTS

- V1: first invariant
EOF
}
teardown() { rm -rf "$TMP"; }

@test "script exists and is executable" {
  assert_file_exist "$SCRIPT"
}

# --- current ---

@test "current prints the tooling format version (V6)" {
  run bash "$SCRIPT" current
  assert_success
  assert_output "1"
}

@test "current ignores SPEC argument" {
  run bash "$SCRIPT" current /nonexistent
  assert_success
  assert_output "1"
}

# --- read ---

@test "read prints formatVersion from marker (V6)" {
  run bash "$SCRIPT" read "$SPEC"
  assert_success
  assert_output "1"
}

@test "read with no marker → error" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: something
EOF
  run bash "$SCRIPT" read "$SPEC"
  assert_failure
  assert_output --partial "no formatVersion marker"
}

@test "read with missing file → error" {
  run bash "$SCRIPT" read /nonexistent/SPEC.md
  assert_failure
  assert_output --partial "no such file"
}

@test "read defaults to SPEC.md in cwd" {
  subdir="$TMP/sub"
  mkdir -p "$subdir"
  cp "$SPEC" "$subdir/SPEC.md"
  cd "$subdir"
  run bash "$SCRIPT" read
  assert_success
  assert_output "1"
}

@test "read extracts multi-digit version" {
  cat >"$SPEC" <<'EOF'
# SPEC

<!-- formatVersion: 42 -->

## §V INVARIANTS
EOF
  run bash "$SCRIPT" read "$SPEC"
  assert_success
  assert_output "42"
}

# --- check ---

@test "check with matching version → ok (V6)" {
  run bash "$SCRIPT" check "$SPEC"
  assert_success
  assert_output --partial "ok"
  assert_output --partial "formatVersion 1"
}

@test "check with higher repo version → error (C2 upgrade tooling)" {
  cat >"$SPEC" <<'EOF'
# SPEC

<!-- formatVersion: 99 -->

## §V INVARIANTS
- V1: something
EOF
  run bash "$SCRIPT" check "$SPEC"
  assert_failure
  assert_output --partial "upgrade tooling"
  assert_output --partial "99"
}

@test "check with lower repo version → ok + migrate hint (C2)" {
  cat >"$SPEC" <<'EOF'
# SPEC

<!-- formatVersion: 0 -->

## §V INVARIANTS
- V1: something
EOF
  run bash "$SCRIPT" check "$SPEC"
  assert_success
  assert_output --partial "ok"
  assert_output --partial "migrate available"
}

@test "check with no marker → error" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: something
EOF
  run bash "$SCRIPT" check "$SPEC"
  assert_failure
  assert_output --partial "no formatVersion marker"
}

@test "check with missing file → error" {
  run bash "$SCRIPT" check /nonexistent/SPEC.md
  assert_failure
  assert_output --partial "no such file"
}

# --- stamp ---

@test "stamp on unmarked SPEC → adds marker (V6)" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: something
EOF
  run bash "$SCRIPT" stamp "$SPEC"
  assert_success
  assert_output --partial "stamped"
  run grep '<!-- formatVersion: 1 -->' "$SPEC"
  assert_success
}

@test "stamp preserves heading as first line (V6)" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: something
EOF
  bash "$SCRIPT" stamp "$SPEC"
  run head -1 "$SPEC"
  assert_output "# SPEC"
}

@test "stamp inserts marker after heading (V6)" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: something
EOF
  bash "$SCRIPT" stamp "$SPEC"
  run grep -n '<!-- formatVersion: 1 -->' "$SPEC"
  assert_success
  # marker should be after the heading, not on line 1
  refute_output --partial "1:<!-- format"
}

@test "stamp on already-current SPEC → noop (V6)" {
  before="$(cat "$SPEC")"
  run bash "$SCRIPT" stamp "$SPEC"
  assert_success
  assert_output --partial "noop"
  assert_equal "$(cat "$SPEC")" "$before"
}

@test "stamp on older version → updates marker in place (V6)" {
  cat >"$SPEC" <<'EOF'
# SPEC

<!-- formatVersion: 0 -->

## §V INVARIANTS
- V1: something
EOF
  run bash "$SCRIPT" stamp "$SPEC"
  assert_success
  assert_output --partial "0"
  run grep '<!-- formatVersion: 1 -->' "$SPEC"
  assert_success
  run grep '<!-- formatVersion: 0 -->' "$SPEC"
  assert_failure
}

@test "stamp on missing file → error" {
  run bash "$SCRIPT" stamp /nonexistent/SPEC.md
  assert_failure
  assert_output --partial "no such file"
}

@test "stamp preserves all existing content (V6)" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: first invariant
- V2: second invariant
## §T TASKS
| T1 | . | task one | V1 |
## §B BUGS
| B1 | 2026-01-01 | a bug | fixed |
EOF
  bash "$SCRIPT" stamp "$SPEC"
  run grep '^- V1: first invariant' "$SPEC"
  assert_success
  run grep '^- V2: second invariant' "$SPEC"
  assert_success
  run grep '^| T1 ' "$SPEC"
  assert_success
  run grep '^| B1 ' "$SPEC"
  assert_success
}

@test "stamp on file without heading → prepends marker (V6)" {
  cat >"$SPEC" <<'EOF'
some content without heading
more content
EOF
  bash "$SCRIPT" stamp "$SPEC"
  run head -1 "$SPEC"
  assert_output '<!-- formatVersion: 1 -->'
  run grep 'some content without heading' "$SPEC"
  assert_success
}

@test "stamp on heading without blank line → inserts with spacing" {
  cat >"$SPEC" <<'EOF'
# SPEC
## §V INVARIANTS
- V1: something
EOF
  bash "$SCRIPT" stamp "$SPEC"
  run head -1 "$SPEC"
  assert_output "# SPEC"
  run grep '<!-- formatVersion: 1 -->' "$SPEC"
  assert_success
  run grep '^## §V INVARIANTS' "$SPEC"
  assert_success
}

@test "stamp then read round-trips (V6)" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: something
EOF
  bash "$SCRIPT" stamp "$SPEC"
  run bash "$SCRIPT" read "$SPEC"
  assert_success
  assert_output "1"
}

@test "stamp then check round-trips (V6)" {
  cat >"$SPEC" <<'EOF'
# SPEC

## §V INVARIANTS
- V1: something
EOF
  bash "$SCRIPT" stamp "$SPEC"
  run bash "$SCRIPT" check "$SPEC"
  assert_success
  assert_output --partial "ok"
}

# --- error handling ---

@test "no subcommand → usage error" {
  run bash "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "unknown subcommand → error" {
  run bash "$SCRIPT" bogus
  assert_failure
  assert_output --partial "unknown subcommand"
}

@test "--help prints usage" {
  run bash "$SCRIPT" --help
  assert_success
  assert_output --partial "ck-format-version"
  assert_output --partial "current"
  assert_output --partial "read"
  assert_output --partial "check"
  assert_output --partial "stamp"
}

@test "unknown option → error" {
  run bash "$SCRIPT" --bogus
  assert_failure
  assert_output --partial "unknown option"
}
