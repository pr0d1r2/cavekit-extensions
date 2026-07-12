#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2030,SC2031
# Coverage for ck-archive-shard.sh — time-shard archived.md to
# archived/<YYYY-MM>.md + INDEX.md (V5/I.archived-shard/T3).

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-file/load.bash"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/ck-archive-shard.sh"
  TMP="$(mktemp -d)"
  ARCHIVE="$TMP/archived.md"
  # Three months of archived data: 2026-05, 2026-06, 2026-07.
  # 16 content lines ⇒ threshold 4 triggers sharding.
  cat >"$ARCHIVE" <<'EOF'

## Archived 2026-05-15 (ck:archive)

| T1 | x | oldest done | C1 |
| T2 | x | done two | C1 |
| B1 | 2026-01-01 | old bug | fixed |

## Archived 2026-06-20 (ck:archive)

| T3 | x | done three | C1 |
- V2: old invariant [superseded by V1]

## Archived 2026-07-12 (ck:archive)

| T4 | x | done four | C1 |
| B2 | 2026-07-01 | recent bug | fixed |
EOF
}
teardown() { rm -rf "$TMP"; }

@test "script exists" {
  assert_file_exist "$SCRIPT"
}

@test "below threshold → noop, file unchanged" {
  before="$(cat "$ARCHIVE")"
  run bash "$SCRIPT" --threshold 500 "$ARCHIVE"
  assert_success
  assert_output --partial "noop"
  assert_equal "$(cat "$ARCHIVE")" "$before"
  assert_file_not_exist "$TMP/archived"
}

@test "above threshold → creates shard directory" {
  run bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  assert_success
  [ -d "$TMP/archived" ]
}

@test "shards by month from ## Archived header (V5)" {
  run bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  assert_success
  assert_file_exist "$TMP/archived/2026-05.md"
  assert_file_exist "$TMP/archived/2026-06.md"
  assert_file_exist "$TMP/archived/2026-07.md"
}

@test "shard content matches source block (V5)" {
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  run grep -E '^\| T1 \| x ' "$TMP/archived/2026-05.md"
  assert_success
  run grep -E '^\| T2 \| x ' "$TMP/archived/2026-05.md"
  assert_success
  run grep -E '^\| B1 ' "$TMP/archived/2026-05.md"
  assert_success
  run grep -E '^\| T3 \| x ' "$TMP/archived/2026-06.md"
  assert_success
  run grep -E '^- V2: ' "$TMP/archived/2026-06.md"
  assert_success
  run grep -E '^\| T4 \| x ' "$TMP/archived/2026-07.md"
  assert_success
  run grep -E '^\| B2 ' "$TMP/archived/2026-07.md"
  assert_success
}

@test "shard preserves ## Archived header in each file (V5)" {
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  run grep -E '^## Archived 2026-05-15' "$TMP/archived/2026-05.md"
  assert_success
  run grep -E '^## Archived 2026-06-20' "$TMP/archived/2026-06.md"
  assert_success
  run grep -E '^## Archived 2026-07-12' "$TMP/archived/2026-07.md"
  assert_success
}

@test "removes archived.md after sharding (V5)" {
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  assert_file_not_exist "$ARCHIVE"
}

@test "generates INDEX.md with id→shard mapping (V5)" {
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  assert_file_exist "$TMP/archived/INDEX.md"
  run grep -E '^\| T1 \| 2026-05 \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| T2 \| 2026-05 \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| B1 \| 2026-05 \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| T3 \| 2026-06 \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| V2 \| 2026-06 \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| T4 \| 2026-07 \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| B2 \| 2026-07 \|' "$TMP/archived/INDEX.md"
  assert_success
}

@test "INDEX.md has table header (V5)" {
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  run grep -E '^\| id \| shard \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| --- \| --- \|' "$TMP/archived/INDEX.md"
  assert_success
}

@test "INDEX.md ids are sorted (V5)" {
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  ids="$(grep -E '^\| [A-Z]' "$TMP/archived/INDEX.md" |
    grep -v '| id ' | awk -F'|' '{ gsub(/ /, "", $2); print $2 }')"
  sorted="$(echo "$ids" | sort -V)"
  assert_equal "$ids" "$sorted"
}

@test "--dry-run mutates nothing" {
  before="$(cat "$ARCHIVE")"
  run bash "$SCRIPT" --dry-run --threshold 4 "$ARCHIVE"
  assert_success
  assert_output --partial "DRY-RUN"
  assert_equal "$(cat "$ARCHIVE")" "$before"
  assert_file_not_exist "$TMP/archived"
}

@test "grep-by-id spans all shards (V5)" {
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  run grep -rhE '^\| T1 ' "$TMP/archived/"????-??.md
  assert_success
  run grep -rhE '^\| T4 ' "$TMP/archived/"????-??.md
  assert_success
  run grep -rhE '^- V2: ' "$TMP/archived/"????-??.md
  assert_success
}

@test "multiple blocks same month → single shard (V5)" {
  cat >"$ARCHIVE" <<'EOF'

## Archived 2026-07-01 (ck:archive)

| T1 | x | first batch | C1 |

## Archived 2026-07-15 (ck:archive)

| T2 | x | second batch | C1 |
EOF
  run bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  assert_success
  assert_file_exist "$TMP/archived/2026-07.md"
  run grep -cE '^\| T' "$TMP/archived/2026-07.md"
  assert_output "2"
  # Both headers preserved
  run grep -cE '^## Archived 2026-07' "$TMP/archived/2026-07.md"
  assert_output "2"
}

@test "merges into existing shards (V5)" {
  mkdir -p "$TMP/archived"
  cat >"$TMP/archived/2026-05.md" <<'EOF'

## Archived 2026-05-01 (ck:archive)

| T0 | x | pre-existing | C1 |
EOF
  bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  # Pre-existing T0 still present
  run grep -E '^\| T0 \| x ' "$TMP/archived/2026-05.md"
  assert_success
  # Newly sharded T1 also present
  run grep -E '^\| T1 \| x ' "$TMP/archived/2026-05.md"
  assert_success
  # INDEX includes both
  run grep -E '^\| T0 \| 2026-05 \|' "$TMP/archived/INDEX.md"
  assert_success
  run grep -E '^\| T1 \| 2026-05 \|' "$TMP/archived/INDEX.md"
  assert_success
}

@test "no dated blocks → noop" {
  cat >"$ARCHIVE" <<'EOF'
some random content
that has no archive headers
but is long enough
to exceed the threshold
and then some more lines
EOF
  run bash "$SCRIPT" --threshold 2 "$ARCHIVE"
  assert_success
  assert_output --partial "noop"
}

@test "missing file → error" {
  run bash "$SCRIPT" /nonexistent/archived.md
  assert_failure
  assert_output --partial "no such file"
}

@test "--help prints usage" {
  run bash "$SCRIPT" --help
  assert_success
  assert_output --partial "ck-archive-shard"
}

@test "unknown option → error" {
  run bash "$SCRIPT" --bogus "$ARCHIVE"
  assert_failure
  assert_output --partial "unknown option"
}

@test "output reports shard count (V5)" {
  run bash "$SCRIPT" --threshold 4 "$ARCHIVE"
  assert_success
  assert_output --partial "3 shard(s)"
  assert_output --partial "INDEX.md"
}
