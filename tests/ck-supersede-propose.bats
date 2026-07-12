#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031
# Coverage for ck-supersede mode B skill — LLM proposer (V3/T4).
# The skill is a markdown file (.claude/skills/ck-supersede-propose.md).
# These tests verify: (a) the skill file's structural completeness,
# (b) integration: commands in the skill's prescribed format are valid
# mode-A invocations of ck-supersede.sh.

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-file/load.bash"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SKILL="$REPO_ROOT/.claude/skills/ck-supersede-propose.md"
  SCRIPT="$REPO_ROOT/ck-supersede.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

# --- Skill file structure ---

@test "skill file exists" {
  assert_file_exist "$SKILL"
}

@test "skill has YAML frontmatter with description" {
  run head -5 "$SKILL"
  assert_output --partial "description:"
}

@test "skill defines all three tiers: HIGH, MED, LOW (V3)" {
  run grep -c '### HIGH' "$SKILL"
  assert_output "1"
  run grep -c '### MED' "$SKILL"
  assert_output "1"
  run grep -c '### LOW' "$SKILL"
  assert_output "1"
}

@test "skill defines HIGH as explicit statement (V3)" {
  run grep -A1 '### HIGH' "$SKILL"
  assert_output --partial "explicit"
}

@test "skill defines MED as redefine (V3)" {
  run grep -A1 '### MED' "$SKILL"
  assert_output --partial "redefine"
}

@test "skill defines LOW as inferred (V3)" {
  run grep -A1 '### LOW' "$SKILL"
  assert_output --partial "inferred"
}

@test "skill specifies never-mutate contract (C3/V7)" {
  run grep -i 'never mutate' "$SKILL"
  assert_success
}

@test "skill references ck-supersede.sh command format (V3)" {
  run grep 'ck-supersede.sh' "$SKILL"
  assert_success
}

@test "skill specifies --apply-eligible for HIGH tier (V3)" {
  run grep -i 'apply-eligible' "$SKILL"
  assert_success
}

@test "skill specifies confirm for MED tier (V3)" {
  run grep 'confirm' "$SKILL"
  assert_success
}

@test "skill specifies evidence/citation requirement (V3)" {
  run grep -i 'evidence' "$SKILL"
  assert_success
}

@test "skill specifies intra-kind constraint (V2)" {
  run grep -i 'intra-kind' "$SKILL"
  assert_success
}

@test "skill specifies skip already-tagged lines (V3)" {
  run grep -i 'skip.*superseded\|already.*tagged' "$SKILL"
  assert_success
}

@test "skill specifies output format with Command block" {
  run grep 'Command:' "$SKILL"
  assert_success
}

@test "skill specifies no-candidates output" {
  run grep 'No supersession candidates' "$SKILL"
  assert_success
}

@test "skill defines supersession keywords (V3)" {
  run grep -c 'supersedes\|replaces\|absorbs\|obsoletes' "$SKILL"
  [ "$output" -ge 4 ]
}

@test "skill references SPEC.md as default input" {
  run grep 'SPEC.md' "$SKILL"
  assert_success
}

# --- Integration: skill-prescribed commands work with mode A ---

@test "HIGH-tier command format is valid mode-A invocation (V2/V3)" {
  cat >"$TMP/SPEC.md" <<'EOF'
## §V INVARIANTS
- V1: first invariant
- V2: second invariant supersedes V1
EOF
  run bash "$SCRIPT" V2 V1 "$TMP/SPEC.md"
  assert_success
  assert_output --partial "tagged 1 loser(s)"
}

@test "multi-loser command format is valid mode-A invocation (V3)" {
  cat >"$TMP/SPEC.md" <<'EOF'
## §V INVARIANTS
- V1: old invariant
- V2: another old invariant
- V3: new combined invariant
EOF
  run bash "$SCRIPT" V3 V1 V2 "$TMP/SPEC.md"
  assert_success
  assert_output --partial "tagged 2 loser(s)"
}

@test "command with --link flag is valid mode-A invocation (V3)" {
  cat >"$TMP/SPEC.md" <<'EOF'
## §V INVARIANTS
- V1: old approach
- V2: new approach replaces old
EOF
  run bash "$SCRIPT" --link V2 V1 "$TMP/SPEC.md"
  assert_success
  run grep '\[supersedes V1\]' "$TMP/SPEC.md"
  assert_success
}

@test "mode-A preserves already-superseded (skill skips these)" {
  cat >"$TMP/SPEC.md" <<'EOF'
## §V INVARIANTS
- V1: old thing [superseded by V3]
- V2: another old thing
- V3: current thing
EOF
  run bash "$SCRIPT" V3 V1 "$TMP/SPEC.md"
  assert_success
  assert_output --partial "already tagged"
  assert_output --partial "noop"
}

@test "mode-A refuses cross-kind (skill constrains intra-kind)" {
  cat >"$TMP/SPEC.md" <<'EOF'
## §V INVARIANTS
- V1: an invariant
## §T TASKS
| T1 | . | a task | V1 |
EOF
  run bash "$SCRIPT" V1 T1 "$TMP/SPEC.md"
  assert_failure
  assert_output --partial "cross-kind"
}
