#!/usr/bin/env bats
# Coverage for ck:spec audit-mode — decision-unit review + reasoned commits.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SKILL="$REPO_ROOT/.claude/skills/ck-spec-audit.md"
}

@test "audit-mode skill exists" {
  [ -f "$SKILL" ]
}

@test "audit-mode is default-on for every ck:spec mutation" {
  run grep -E 'every `ck:spec` mutation|default-on' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "decomposition defines independently revisitable decision units" {
  run grep -i 'decision the author may want to revisit independently' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "decomposition groups supporting C I V T entries" {
  run grep -E '§C.*§I.*§V.*§T' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "decomposition rejects per-entry and mega-unit defaults" {
  run grep -i 'one unit per entry' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'mega-unit' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "every changed line must map to exactly one unit" {
  run grep -i 'Every changed `SPEC.md` line must belong to exactly one unit' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "author reviews decomposition before mutation or commits" {
  run grep -i 'Before mutating `SPEC.md` or creating any commit' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'explicitly approves this split' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "review includes ids diff rationale alternatives and tradeoffs" {
  run grep -E 'all affected IDs' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -E 'exact entries or diff hunk' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -E 'rejected alternative and why' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -E 'tradeoff or risk accepted' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "audit-mode emits one commit per reviewed unit" {
  run grep -i 'Commit that unit before applying the next' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "commit message carries structured decision record" {
  run grep -F 'spec: <one-line decision> (<ids>)' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'WHY (decision audit-trail):' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "WHY must name rejected alternative rather than restate diff" {
  run grep -i 'alternative and why it lost' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'do not merely restate the diff' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "audit commits stage only SPEC.md" {
  run grep -i 'Stage only `SPEC.md`' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'Never stage or commit files other than `SPEC.md`' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "pre-existing SPEC changes are never absorbed" {
  run grep -i 'pre-existing staged or unstaged changes' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'Never absorb, overwrite, reset, or commit them' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "repository hooks are never bypassed" {
  run grep -F 'Never use `--no-verify`' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "partial failure preserves successful audit commits" {
  run grep -i 'successful unit commit is durable' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'already-created commit hashes' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "non-git fallback requires explicit author choice" {
  run grep -i 'audit commits are unavailable' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'silently downgrade' "$SKILL"
  [ "$status" -eq 0 ]
}
