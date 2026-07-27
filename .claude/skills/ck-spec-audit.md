---
description: >-
  ck:spec audit-mode — decompose approved SPEC.md writes into independently
  revisitable decision units and commit each with its WHY
---

# ck:spec audit-mode

Apply this workflow to every `ck:spec` mutation of `SPEC.md`. Audit-mode is
default-on. It extends the upstream spec skill's diff-and-approval contract;
it does not replace its dispatch, section ownership, numbering, or caveman
rules.

The spec entry preserves the compact **what**. The commit bonded to that exact
diff preserves the rich **why**.

## Preconditions

Before proposing or writing:

1. Confirm the working directory is inside a Git repository.
2. Inspect `git status --short -- SPEC.md`.
3. If `SPEC.md` has pre-existing staged or unstaged changes, stop and ask the
   author how to handle them. Never absorb, overwrite, reset, or commit them.
4. Follow the upstream spec flow through its proposed diff and obtain the
   author's normal content approval.

If there is no Git repository, explain that audit commits are unavailable and
ask whether to apply the approved spec diff without the audit trail. Never
silently downgrade.

## Decision units

After content approval, partition the approved diff by rationale. One unit is
a decision the author may want to revisit independently:

- one §C choice plus its supporting §I, §V, and §T entries;
- one §V cluster whose entries share a single rationale;
- one targeted amendment or backprop decision and its directly supporting
  entries.

Keep entries together when separating them would leave a constraint,
interface, invariant, or task unsupported. Split entries whose alternatives,
tradeoffs, or reasons differ. Do not default to one unit per entry and do not
collapse multiple independent choices into one mega-unit.

Every changed `SPEC.md` line must belong to exactly one unit. Preserve the
approved final file content, section order, and monotonic IDs.

## Decomposition review gate

Before mutating `SPEC.md` or creating any commit, show the proposed units in
commit order. For every unit show:

1. one-line decision;
2. all affected IDs (for example `C8,V8,I.ck-spec-audit,T8`);
3. the exact entries or diff hunk assigned to it;
4. WHY: problem, choice, rejected alternative and why;
5. tradeoff or risk accepted, plus what it supersedes (or `none`).

Also show any approved diff lines not yet assigned; this list must say `none`
before proceeding.

Ask the author to approve or revise the decomposition. **Do not write or
commit until the author explicitly approves this split.** Content approval
alone is not decomposition approval.

## Apply and commit

After decomposition approval:

1. Apply the units in the reviewed order, one at a time.
2. After each unit, verify its assigned diff and confirm no unrelated path is
   staged.
3. Stage only `SPEC.md`.
4. Commit that unit before applying the next. Never bypass repository hooks.
5. If a hook fails, fix the failure, show any changed decomposition impact,
   and retry normally. Never use `--no-verify`.
6. After the final unit, compare `SPEC.md` with the content-approved final
   result and report the commit hashes in unit order.

Use this exact message shape:

```text
spec: <one-line decision> (<ids>)

WHY (decision audit-trail):
<problem · the choice · the alternative rejected + why>
<tradeoff / risk accepted / what it supersedes>
```

The subject describes the decision, not the editing action. The body must name
an alternative and why it lost; do not merely restate the diff. If there is no
meaningful supersession or accepted risk, say so explicitly.

## Failure safety

- A successful unit commit is durable; never rewrite or squash it
  automatically if a later unit fails.
- On failure, stop with already-created commit hashes, the failing unit, hook
  output, and remaining approved units.
- Never stage or commit files other than `SPEC.md`.
- Never amend, rebase, reset, or force-push as part of audit-mode.
- An empty unit is an error: return it to decomposition review.
