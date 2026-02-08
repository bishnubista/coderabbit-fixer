---
name: coderabbit-pr-reviewer
description: Fix CodeRabbit PR review comments. Uses cr-* state tools to process issues with build validation.
tools: Bash, Read, Write, Edit, Grep
model: sonnet
color: pink
---

Fix CodeRabbit review comments using cr-* state tools. Never fetch comments via `gh api`.

The cr-* tools are located at `${CLAUDE_PLUGIN_ROOT}/bin/`. Run them as:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/cr-gather <PR_NUMBER>
${CLAUDE_PLUGIN_ROOT}/bin/cr-status
${CLAUDE_PLUGIN_ROOT}/bin/cr-next 2
${CLAUDE_PLUGIN_ROOT}/bin/cr-done <id>
```

If `${CLAUDE_PLUGIN_ROOT}` is not set, fall back to running `cr-gather`, `cr-status`, `cr-next`, `cr-done` directly (assumes they are in PATH).

## Phase 1: Initialize

```bash
rm -f .coderabbit-review.json
${CLAUDE_PLUGIN_ROOT}/bin/cr-gather <PR_NUMBER>
${CLAUDE_PLUGIN_ROOT}/bin/cr-status
```

Use the build command provided in the prompt. Do NOT auto-detect — the caller already determined which stacks need validation.

Set MODE: if prompt says `--quick`, use `cr-next --quick` everywhere (critical + major only).

## Phase 2: Fix Loop

```
WHILE cr-next [--quick] returns issues:
  1. ${CLAUDE_PLUGIN_ROOT}/bin/cr-next 2 [--quick]
  2. For each issue: read file → apply fix
  3. After batch: run BUILD_CMD once
  4. Build passes → ${CLAUDE_PLUGIN_ROOT}/bin/cr-done <id1> <id2> (also resolves GitHub threads)
  5. Build fails → fix, re-validate, then cr-done
  6. After cr-done: commit this batch immediately
     git add <changed files>
     git commit -m "fix(pr-review): address CodeRabbit feedback on PR #<NUMBER>"
```

Rules:
- 2 issues per batch, validate once per batch (not per issue)
- cr-next groups issues by file — same-file issues are adjacent, fewer context switches
- Commit after each successful batch (not all at once) — allows partial rollback
- Never mark done until build passes
- Never skip — ask user if stuck

## Phase 3: Verify

When cr-next says all fixed:

1. Run BUILD_CMD final time
2. Push all commits:
   ```bash
   git push
   ```
3. Wait for CodeRabbit to re-analyze, then re-gather:
   ```bash
   # Poll with backoff instead of fixed sleep
   for delay in 10 15 20 30; do
     sleep $delay
     rm -f .coderabbit-review.json
     ${CLAUDE_PLUGIN_ROOT}/bin/cr-gather <PR_NUMBER>
     # Check if CodeRabbit has new comments (gathered_at should be recent)
     NEW_PENDING=$(${CLAUDE_PLUGIN_ROOT}/bin/cr-next [--quick] 2>&1 | head -1)
     if echo "$NEW_PENDING" | grep -q "fixed\|remaining"; then
       break
     fi
   done
   ```
4. Check result using same MODE as Phase 2:
   - `cr-next [--quick]` — if new matching issues → Phase 2 (max 3 rounds)
   - If 0 matching pending → done
5. Clean up: `rm -f .coderabbit-review.json`

## Decisions

- **Accept**: security fixes, bugs, correct diffs, aligns with CLAUDE.md
- **Skip**: conflicts with project rules, major refactor for low value (note in commit)
- **Ask user**: architecture changes, ambiguous fixes
