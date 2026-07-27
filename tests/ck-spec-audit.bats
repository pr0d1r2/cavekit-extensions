#!/usr/bin/env bats
# Coverage for ck:spec audit-mode — skill-judged proportional ceremony.

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

@test "missing project setting defaults audit on" {
  run grep -F 'no committed `.cavekit.toml`, no `[spec]` table, or no `audit` key means' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F '`audit = true`' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "only committed project setting can disable audit" {
  run grep -F 'only a committed `[spec]` table with `audit = false` means disabled' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F '`git show HEAD:.cavekit.toml`' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'An untracked, unstaged, or staged' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'must not disable audit-mode' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "malformed audit setting fails closed" {
  run grep -F 'malformed or non-boolean' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'never interpret it as disabled' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "per-command audit can only escalate to full ceremony" {
  run grep -F 'only per-command control is `--audit`' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'escalates to full ceremony' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'it can never lower it' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "per-command audit disable is rejected" {
  run grep -F 'reject `--no-audit` and every equivalent flag' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "committed disable uses normal upstream flow without audit commits" {
  run grep -F 'Audit: disabled by committed .cavekit.toml' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'without audit classification, decomposition,' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'or audit commits' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "skill judges weight from approved diff instead of a user flag" {
  run grep -i 'skill judges that weight from the approved diff' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'author never selects' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'or declares a change trivial' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F '`--no-audit`' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'cannot lower the tier warranted by the diff' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "classification happens after content approval and before mutation" {
  run grep -i 'After content approval and before mutating' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "full ceremony covers substantive G C and multi-decision changes" {
  run grep -E 'New or substantively changed §G/§C.*multiple independent substantive decisions.*full' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'one reasoned commit per unit' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "light ceremony covers one substantive decision confined to V I or T" {
  run grep -E 'Exactly one substantive decision confined to §V, §I, or §T.*light' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'do not manufacture a' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'multi-unit decomposition' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'WHY:' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "classification covers edits removals and future substantive sections" {
  run grep -i 'whether it adds, edits, or removes text' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'full-tier fallback' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'future spec section' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "none ceremony covers meaning-preserving edits" {
  run grep -E 'Renumbering, formatting, typo correction.*none' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'without an audit commit or decomposition' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "mixed and ambiguous changes cannot under-classify ceremony" {
  run grep -F 'full > light > none' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'unclear whether an edit preserves meaning, choose the higher tier' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "decomposition defines independently revisitable decision units" {
  run grep -i 'decision the author' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'may want to revisit independently' "$SKILL"
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
  run grep -i 'never stage or commit files other than `SPEC.md`' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "pre-existing SPEC changes are never absorbed" {
  run grep -i 'pre-existing staged or unstaged changes' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'Never absorb, overwrite, reset, or commit them' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "pre-existing staged paths cannot leak into an audit commit" {
  run grep -F 'git diff --cached --name-only' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -i 'If any path is staged, stop' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "repository hooks are never bypassed" {
  run grep -F 'Never use `--no-verify`' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "partial failure preserves successful audit commits" {
  run grep -i 'unit commit is durable' "$SKILL"
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
