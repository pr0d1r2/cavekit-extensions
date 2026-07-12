#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031
# Coverage for ck-assemble.sh — MECHANICAL assembly manifest for nix-cavekit
# (V6/C1/T7). Tests: list, manifest, version, check subcommands; content
# enumeration (ck-*.sh + skills), formatVersion propagation, error handling.

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-file/load.bash"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/ck-assemble.sh"
  # A fake pinned source tree with the portable content nix-cavekit merges.
  TMP="$(mktemp -d)"
  cat >"$TMP/SPEC.md" <<'EOF'
# SPEC

<!-- formatVersion: 1 -->

## §V INVARIANTS
- V1: an invariant
EOF
  printf '#!/usr/bin/env bash\necho archive\n' >"$TMP/ck-archive.sh"
  printf '#!/usr/bin/env bash\necho supersede\n' >"$TMP/ck-supersede.sh"
  mkdir -p "$TMP/.claude/skills"
  printf '# a skill\n' >"$TMP/.claude/skills/ck-supersede-propose.md"
}
teardown() { rm -rf "$TMP"; }

@test "script exists" {
  assert_file_exist "$SCRIPT"
}

# --- list ---

@test "list enumerates ck-*.sh content (C1)" {
  run bash "$SCRIPT" list "$TMP"
  assert_success
  assert_line "ck-archive.sh"
  assert_line "ck-supersede.sh"
}

@test "list enumerates proposer skills (C1)" {
  run bash "$SCRIPT" list "$TMP"
  assert_success
  assert_line ".claude/skills/ck-supersede-propose.md"
}

@test "list output is sorted and deduped (deterministic)" {
  run bash "$SCRIPT" list "$TMP"
  assert_success
  sorted="$(printf '%s\n' "$output" | LC_ALL=C sort -u)"
  assert_equal "$output" "$sorted"
}

@test "list paths are repo-relative, not absolute" {
  run bash "$SCRIPT" list "$TMP"
  assert_success
  refute_output --partial "$TMP"
}

@test "list picks up a newly added script without editing ck-assemble (derived)" {
  printf '#!/usr/bin/env bash\necho new\n' >"$TMP/ck-newverb.sh"
  run bash "$SCRIPT" list "$TMP"
  assert_success
  assert_line "ck-newverb.sh"
}

@test "list omits non-content files" {
  printf 'not content\n' >"$TMP/README.md"
  printf '{}\n' >"$TMP/flake.nix"
  run bash "$SCRIPT" list "$TMP"
  assert_success
  refute_line "README.md"
  refute_line "flake.nix"
}

@test "list works with no skills dir" {
  rm -rf "$TMP/.claude"
  run bash "$SCRIPT" list "$TMP"
  assert_success
  assert_line "ck-archive.sh"
  refute_output --partial ".claude"
}

# --- version ---

@test "version prints the repo-declared formatVersion (V6)" {
  run bash "$SCRIPT" version "$TMP"
  assert_success
  assert_output "1"
}

@test "version reads a multi-digit marker" {
  cat >"$TMP/SPEC.md" <<'EOF'
# SPEC

<!-- formatVersion: 42 -->
EOF
  run bash "$SCRIPT" version "$TMP"
  assert_success
  assert_output "42"
}

@test "version with no marker → error (V6)" {
  cat >"$TMP/SPEC.md" <<'EOF'
# SPEC
## §V INVARIANTS
EOF
  run bash "$SCRIPT" version "$TMP"
  assert_failure
  assert_output --partial "no formatVersion marker"
}

@test "version with missing SPEC.md → error" {
  rm -f "$TMP/SPEC.md"
  run bash "$SCRIPT" version "$TMP"
  assert_failure
  assert_output --partial "no such file"
}

# --- manifest ---

@test "manifest carries the formatVersion for lock-bump propagation (V6)" {
  run bash "$SCRIPT" manifest "$TMP"
  assert_success
  assert_line "formatVersion 1"
}

@test "manifest lists every content path with a path prefix (C1)" {
  run bash "$SCRIPT" manifest "$TMP"
  assert_success
  assert_line "path ck-archive.sh"
  assert_line "path ck-supersede.sh"
  assert_line "path .claude/skills/ck-supersede-propose.md"
}

@test "manifest formatVersion is the first line" {
  run bash "$SCRIPT" manifest "$TMP"
  assert_success
  assert_equal "${lines[0]}" "formatVersion 1"
}

@test "manifest is stable across invocations (deterministic assembly)" {
  run bash "$SCRIPT" manifest "$TMP"
  first="$output"
  run bash "$SCRIPT" manifest "$TMP"
  assert_equal "$output" "$first"
}

# --- check ---

@test "check passes on an assemblable tree (V6)" {
  run bash "$SCRIPT" check "$TMP"
  assert_success
  assert_output --partial "ok"
  assert_output --partial "formatVersion 1"
}

@test "check reports the content count" {
  run bash "$SCRIPT" check "$TMP"
  assert_success
  # ck-archive.sh, ck-supersede.sh, ck-supersede-propose.md = 3
  assert_output --partial "3 content paths"
}

@test "check fails when a listed content file is empty" {
  : >"$TMP/ck-archive.sh"
  run bash "$SCRIPT" check "$TMP"
  assert_failure
  assert_output --partial "empty content"
  assert_output --partial "NOT assemblable"
}

@test "check fails when the formatVersion marker is missing (V6)" {
  cat >"$TMP/SPEC.md" <<'EOF'
# SPEC
## §V INVARIANTS
EOF
  run bash "$SCRIPT" check "$TMP"
  assert_failure
  assert_output --partial "no formatVersion marker"
}

# --- default ROOT (own dir) ---

@test "defaults REPO_ROOT to the script's own directory" {
  # Copy the script into the fake tree; it should assemble that tree.
  cp "$SCRIPT" "$TMP/ck-assemble.sh"
  cd /
  run bash "$TMP/ck-assemble.sh" version
  assert_success
  assert_output "1"
}

@test "real repo self-assembles: this repo's own content lists + checks" {
  run bash "$SCRIPT" list "$REPO_ROOT"
  assert_success
  assert_line "ck-assemble.sh"
  assert_line "ck-archive.sh"
  run bash "$SCRIPT" check "$REPO_ROOT"
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
  run bash "$SCRIPT" bogus "$TMP"
  assert_failure
  assert_output --partial "unknown subcommand"
}

@test "--help prints usage with all subcommands" {
  run bash "$SCRIPT" --help
  assert_success
  assert_output --partial "ck-assemble"
  assert_output --partial "list"
  assert_output --partial "manifest"
  assert_output --partial "version"
  assert_output --partial "check"
}

@test "unknown option → error" {
  run bash "$SCRIPT" --bogus
  assert_failure
  assert_output --partial "unknown option"
}
