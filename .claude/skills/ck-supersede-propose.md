---
description: >-
  ck-supersede mode B — analyze §V prose for supersession,
  emit tiered command proposals (V3/T4)
---

# ck-supersede propose (mode B)

Analyze the §V INVARIANTS section of a cavekit SPEC.md for
supersession relationships between invariants. Emit tiered,
evidence-cited `ck-supersede` command proposals.

**Contract: NEVER mutate any file.** Output proposals only — a
human or gate runs the commands (C3/V7 seam).

## Step 1 — extract §V lines

Read the target SPEC.md (default: `SPEC.md` in the working
directory). Collect every line matching `^- V<N>:` (with a space) under the
`## §V INVARIANTS` heading.

Skip any §V already tagged `[superseded by V<N>]` — it is
already resolved.

## Step 2 — detect supersession signals

Compare every pair of live (non-superseded) §V entries. For
each candidate, classify into exactly one tier.

### HIGH — explicit statement

The prose of one §V contains an explicit supersession claim
about another §V by id:

- "supersedes V`<N>`"
- "replaces V`<N>`"
- "absorbs V`<N>`"
- "obsoletes V`<N>`"
- "V`<N>` is superseded"
- winner prose says "superseded by V`<N>`" naming itself as
  the replacement

These are unambiguous. Mark the proposal `--apply`-eligible
(a human/gate can run it without further review).

### MED — redefine

Two §V entries govern the **same subject** (same noun or
concern), but one provides a newer, broader, or corrected
rule. Neither mentions the other by id.

Evidence required: quote the overlapping subject phrase from
both §V lines.

Mark the proposal `confirm` — needs human review.

### LOW — inferred

A §V's subject has been absorbed into a broader §V, rendered
moot by a structural change, or its concern no longer exists
in the spec. No explicit mention, no direct subject overlap.

Evidence required: quote reasoning **and** the relevant §V
text.

Mark the proposal `confirm + quote-reasoning`.

## Step 3 — emit proposals

For each finding, output a block in this exact format:

```text
### <TIER>: V<winner> supersedes V<loser>

Evidence: <quoted §V prose supporting the finding>

Command:
  ck-supersede.sh V<winner> V<loser>

Action: <--apply-eligible | confirm | confirm + quote-reasoning>
```

Group by tier: all HIGH first, then MED, then LOW. Within a
tier, sort by winner id ascending.

If a single winner supersedes multiple losers, emit one
block with a single command:

```text
Command:
  ck-supersede.sh V<winner> V<loser1> V<loser2>
```

If no supersession candidates are found, output exactly:

```text
No supersession candidates found in §V.
```

## Constraints

1. **Never mutate** — read SPEC.md, write proposals to stdout.
2. **Intra-kind only** — V supersedes V (never T, B, C, I).
3. **Skip already-tagged** — ignore `[superseded by ...]` lines.
4. **Cite evidence** — every proposal quotes the actual §V prose
    that supports the finding. Never fabricate quotes.
5. **Prefer lower tier** when uncertain (MED over false HIGH,
    LOW over false MED).
6. **Valid mode-A syntax** — every emitted `ck-supersede.sh`
    command must be a valid mode-A invocation:
    `ck-supersede.sh [--link] <winner> <loser>...`
7. The `--link` flag is optional; include it only when the
    winner's prose does not already reference the loser.
