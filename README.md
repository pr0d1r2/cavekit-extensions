# cavekit-extensions

<!-- hallucinogen:autonomy-disclaimer start -->
> Read [LLM-DISCLAIMER](docs/LLM-DISCLAIMER.md) first. This repository is
> tended by an autonomous loop, and that file says what the loop may do here,
> what it may not, and what to check before trusting anything in this tree.
<!-- hallucinogen:autonomy-disclaimer end -->

pr0d1r2's cavekit format + tooling extensions — spec compaction (`ck:archive`),
supersession (`ck:supersede`), and archival — layered on upstream
[cavekit](https://github.com/JuliusBrussee/cavekit), packaged and propagated by
`nix-cavekit`.

Portable content destined for upstream. See `SPEC.md` for the design; the tend
loop drives the pending §T.

- `ck-archive.sh` — deterministic, lossless SPEC.md compaction (shipped).
- `ck-supersede.sh` — mechanical supersession tagging (pending, §T1).
- `ck-format-version.sh` — format-version primitive: reads/checks/stamps the
  repo-declared formatVersion marker (T5/V6).
- `ck-check-skip.sh` — mechanical superseded-§V filter: lists active/skipped
  §V ids so `/check` skips `[superseded by VN]`-tagged invariants (T6/V4).
- `ck-assemble.sh` — deterministic assembly manifest: lists the portable
  content `nix-cavekit` merges into the plugin derivation and reports the
  `formatVersion` that rides the set-and-setting lock-bump (T7/V6/C1).
- `.claude/skills/ck-spec-audit.md` — default-on `ck:spec` audit-mode:
  skill-judged proportional ceremony — full decision-unit commits for heavy
  changes (including any substantive goal or constraint change), one WHY commit
  for a single substantive §V/§I/§T decision, and none for meaning-preserving
  edits. Per-command `--audit` can force full ceremony; only a committed
  `.cavekit.toml` `[spec] audit = false` can disable the audit trail
  (T8/V8).
- `.claude/skills/ck-supersede-propose.md` — LLM proposer skill for
  §V supersession analysis (T4/V3).
