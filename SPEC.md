# SPEC — cavekit-extensions

## §G GOAL

pr0d1r2's **cavekit format + tooling extensions** — spec compaction, supersession,
and archival on top of upstream cavekit (JuliusBrussee/cavekit). Portable plugin
content DESTINED FOR UPSTREAM; packaged + versioned + fleet-propagated by
`nix-cavekit`. Keeps a fat SPEC.md's HOT path small (the loop greps less) without
losing history.

## §C CONSTRAINTS

- C1: **portable content** — scripts (bash) + skill markdown + FORMAT deltas, usable with/without nix; PR-able to upstream cavekit. `nix-cavekit` merely ASSEMBLES + versions + propagates (it pins upstream + this repo).
- C2: **format-version ⊥ plugin-version** — a repo declares `formatVersion`; the plugin READS ≥ its min (offers migrate), WRITES current; migrators bridge vN→vN+1 (deterministic, confirmator-gated). "≥4.1.0" means "≥ the tooling that speaks format vN".
- C3: **the nix↔LLM seam** — DETERMINISTIC mechanical tools = bash scripts (hookable, cost-0); JUDGMENT = LLM skills (proposers). Never mix: a mechanical verb ⊥ calls an LLM; a proposer ⊥ mutates directly.
- C4: **`archived` is a COMPACTION SINK only** — written ONLY when the spec is compacted (size-triggered), INDEPENDENT of the §T task lifecycle. `/build` never moves rows; it flips status in place (upstream-unchanged).
- C5: **lossless** — supersedes upstream's ">500 lines, compact §B drop oldest": same trigger + `/spec` diff discipline, but rows MOVE to a file, ⊥ `/dev/null`. The LIVE spec stays one file (upstream's "⊥ more files" holds — archive is cold).
- C6: **incubate → extract → graduate** — born in hallucinogen `contrib/`, extracted to this repo, graduated by upstream PR (dropped here once merged).
- C7: **§T are SELF-CONTAINED** (in-repo, loop-drivable); plugin/upstream-integration tasks (touch the installed cavekit plugin, ⊥ this repo) are flagged **out-of-loop** (graduation, human PR).

## §I INTERFACES

- I.ck-archive: `ck-archive.sh [--dry-run] [--threshold N=500] [--keep-recent K=20] [SPEC.md]` — DETERMINISTIC, lossless spec compaction (V1). Evicts the coldest done §T (`x`) + §B rows to `archived.md` (dated block, raw pipe rows),
  keeping the newest K; threshold-gated; never touches live rows (pending/in-progress §T, §G/§C/§I/§V). IDs global-monotonic across SPEC + archived. `--dry-run` previews. SHIPPED (seeded from hallucinogen).
- I.ck-supersede: `ck-supersede.sh <winner> <loser>…` (mode A, mechanical) tags each loser `[superseded by <winner>]` (validate ids exist, idempotent, intra-kind, refuse self);
  `ck-supersede` no-args (mode B, LLM skill) analyzes §V prose → proposes tiered `ck-supersede` commands with cited evidence (proposal-only, human/gate approves). See V2, V3.
- I.archived-shard: when `archived.md` grows, shard to `archived/<YYYY-MM>.md` by completion month + a GENERATED `archived/INDEX.md` (id→shard, ranges). grep-by-id spans SPEC + all shards. See V5.
- I.check-skip: `/check` SKIPS a `[superseded by V\d+]`-tagged §V (stop enforcing dead law) — OUT-OF-LOOP (edits the cavekit plugin's `/check`, ⊥ this repo; graduation). See V4.
- I.format-version: `lib.formatVersion` (the on-disk schema constant) + a repo-declared `formatVersion` marker; the plugin/format axis split (C2). See V6.

## §V INVARIANTS

- V1: `ck-archive` — DETERMINISTIC, lossless, threshold-gated compaction: evict cold done-§T(`x`)/§B rows to `archived.md` (keep newest K), never live rows, IDs preserved global-monotonic across SPEC+archived, `--dry-run` mutates nothing. A pure text transform (no LLM ⇒ hookable/CI-able).
- V2: `ck-supersede` mode A is MECHANICAL — tags loser §V `[superseded by <winner>]` (winner id first, rest lose); validates both ids exist, idempotent (already-tagged = noop),
  intra-kind (V supersedes V), refuses self/unknown. Tags but does NOT evict — reversible, visible, caught before eviction (V1 does that separately).
- V3: `ck-supersede` mode B is an LLM PROPOSER — analyzes §V prose for supersession (explicit "supersedes VN" / "redefined" / subject-gone), emits tiered proposals
  (HIGH explicit → `--apply`-eligible · MED redefine → confirm · LOW inferred → confirm+quote-reasoning), each CITING evidence;
  NEVER mutates — outputs mode-A commands a human/gate runs. Mirrors the V104/V105 explicit-vs-inferred trust tiers.
- V4: **supersession pipeline** — judgment at WRITE-time, mechanical archival: `/spec` tags `[superseded by VN]` when it writes a superseding §V →
  `ck-archive` evicts `[superseded]`-tagged §V (extends V1 past §T/§B) → `/check` SKIPS tagged §V. The tag is an unambiguous delimiter ⇒
  archival stays 100% mechanical; a retrospective LLM sweep is ⊥ needed (mode B backfills legacy untagged claims once).
- V5: `archived` is a COMPACTION SINK, ⊥ a task-lifecycle move (C4) — written only when `ck-archive` runs (size-triggered). Start FLAT (`archived.md`);
  shard to `archived/<YYYY-MM>.md` + a GENERATED INDEX only when the flat file hurts (⊥ premature). Time-partition serves the journal/audit read;
  id-lookup stays cheap (narrow grep spans SPEC + shards).
- V6: format-version is DECOUPLED from plugin/tooling version (C2) — a repo declares `formatVersion`; migrators (`apps.migrate`, deterministic, idempotent, confirmator-gated)
  bridge vN→vN+1; the plugin reads ≥ v1 (offers migrate), writes current. Propagation rides `nix-cavekit → set-and-setting → leaves` (a lock-bump, ⊥ O(N) copies).
- V7: the nix↔LLM seam (C3) — nix owns package/version/**migrate**/validate (pure, reproducible); LLM owns AUTHORING (`/spec`, mode-B propose). Mechanical verbs (`ck-archive`, `ck-supersede` mode A) are deterministic scripts; proposers/authors are skills. A change to one ⊥ leaks into the other.

## §T TASKS

| id | st | task | cites |
| --- | --- | --- | --- |
| T1 | . | **`ck-supersede.sh` mode A (mechanical tag)** — `<winner> <loser>…` → tag losers `[superseded by <winner>]`; validate ids, idempotent, intra-kind, refuse self/unknown; `--link` annotates the winner. + bats. | V2,I.ck-supersede |
| T2 | . | **`ck-archive` tagged-§V eviction** — extend `ck-archive.sh` to also evict `[superseded by V\d+]`-tagged §V lines (past v1's §T/§B), IDs preserved. + bats. | V1,V4,I.ck-archive |
| T3 | . | **`archived/` time-sharding + generated INDEX** — when `archived.md` exceeds a size, shard to `archived/<YYYY-MM>.md` + a generated `INDEX.md` (id→shard); grep-by-id spans all. + bats. | V5,I.archived-shard |
| T4 | . | **`ck-supersede` mode B (LLM proposer skill)** — a skill: analyze §V prose → tiered, evidence-cited `ck-supersede` command proposals (HIGH/MED/LOW); proposal-only. | V3,I.ck-supersede |
| T5 | . | **format-version primitive** — `lib.formatVersion` + a repo-declared `formatVersion` marker; the plugin/format axis split. | V6,I.format-version |
| T6 | . | (OUT-OF-LOOP — graduation/upstream PR, edits the cavekit plugin) **`/check` skip-superseded** — `/check` stops enforcing a `[superseded by VN]`-tagged §V. | V4,I.check-skip |
| T7 | . | (OUT-OF-LOOP — cross-repo) **nix-cavekit assembly** — `nix-cavekit` pins this repo + merges its content into the plugin derivation; propagate via set-and-setting lock-bump. | V6,C1 |

## §B BUGS

| id | date | cause | fix |
| --- | --- | --- | --- |
| B1 | 2026-07-12 | CI: nix-lefthook-ci-action install step uses `--ignore-environment` without `--keep HOME`; git fatally errors | Override devShells to prepend `export HOME="${HOME:-/tmp}"` before mkDevShells base hook |
| B2 | 2026-07-12 | CI: SPEC.md lines in §I/§V exceed 300-char markdownlint limit → lefthook pre-push fails | Wrap long lines with 2-space continuation indent |
| B3 | 2026-07-12 | CI: `install-nix-action@v27` on macOS: `dscl eDSRecordAlreadyExists` — runner has pre-existing Nix build users | Pre-step in `build-darwin` deletes `_nixbld*` users and groups before install |
| B4 | 2026-07-12 | CI: `install-nix-action@v27` installs Nix 2.22.1 with `--darwin-use-unencrypted-nix-store-volume`, incompatible with macOS 26 runners (`macos-latest` migrated 2026-06-15) | Upgrade `install-nix-action` v27→v31 (Nix 2.34.8, drops obsolete macOS volume flag) |
