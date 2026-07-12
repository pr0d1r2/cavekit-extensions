# cavekit-extensions

pr0d1r2's cavekit format + tooling extensions — spec compaction (`ck:archive`),
supersession (`ck:supersede`), and archival — layered on upstream
[cavekit](https://github.com/JuliusBrussee/cavekit), packaged and propagated by
`nix-cavekit`.

Portable content destined for upstream. See `SPEC.md` for the design; the tend
loop drives the pending §T.

- `ck-archive.sh` — deterministic, lossless SPEC.md compaction (shipped).
- `ck-supersede.sh` — mechanical supersession tagging (pending, §T1).
