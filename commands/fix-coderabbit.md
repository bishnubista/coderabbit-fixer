---
description: "Fix CodeRabbit PR review comments. Usage: /fix-coderabbit [PR#] [--quick] [--bg]. Default: all severities. --quick: critical + major only. --bg: run in background."
allowed-tools: Task, Bash
---

Auto-selects single agent or parallel coordinator based on issue count. Do NOT fix code yourself.

The cr-* tools are at `${CLAUDE_PLUGIN_ROOT}/bin/`. If `${CLAUDE_PLUGIN_ROOT}` is not set, use `cr-gather` directly (assumes PATH).

## Steps

1. **Get PR number** from `$ARGUMENTS` or auto-detect: `gh pr view --json number -q '.number'`
   - If not found: tell user to run `/fix-coderabbit <PR>`

2. **Clean slate**: `rm -f .coderabbit-review.json`

3. **Detect build command** — smart detection based on changed files:

   ```bash
   # Get changed files in this PR
   CHANGED=$(gh pr diff --name-only)
   HAS_BACKEND=$(echo "$CHANGED" | grep -q '^backend/' && echo true || echo false)
   HAS_FRONTEND=$(echo "$CHANGED" | grep -qE '^frontend/|^src/' && echo true || echo false)
   ```

   Build only what changed:
   - Backend only (`uv.lock`): `cd backend && uv run ruff check .`
   - Frontend only (`bun.lockb`): `cd frontend && bun run tsc --noEmit && bun run lint && bun run build`
   - Both changed: run both commands
   - Fallback detection by lockfile if `gh pr diff` fails:
     - `pnpm-lock.yaml` → `pnpm run typecheck && pnpm run lint && pnpm run build`
     - `package.json` → `npm run typecheck && npm run lint && npm run build`

4. **Parse flags** from `$ARGUMENTS`:
   - `--quick` → add "Use --quick mode (critical + major only)." to agent prompt
   - `--bg` → set `run_in_background: true` on the Task tool call

5. **Gather and decide agent**: Run `${CLAUDE_PLUGIN_ROOT}/bin/cr-gather` (or `cr-gather`) first, then read issue/file counts from `.coderabbit-review.json`:

   ```bash
   TOTAL=$(jq '.summary.total' .coderabbit-review.json)
   FILES=$(jq '.summary.files' .coderabbit-review.json)
   ```

   **Auto-select**:
   - `TOTAL < 5` → use `coderabbit-pr-reviewer` (single agent, verification gate)
   - `TOTAL >= 5` → use `coderabbit-coordinator` (parallel workers grouped by file)

   Tell user which mode was selected: "X issues across Y files → using [single agent / parallel coordinator (up to 5 workers)]"

6. **Spawn agent**:

   **If single agent** (`TOTAL < 5`):
   ```
   Task:
     subagent_type: coderabbit-pr-reviewer
     run_in_background: [true if --bg, false otherwise]
     prompt: |
       Fix CodeRabbit comments on PR #[NUMBER].
       Build command: [DETECTED_COMMAND]
       [If --quick: "Use --quick mode (critical + major only)."]
       After pushing, re-gather to verify no new comments. Max 3 rounds.
   ```

   **If coordinator** (`TOTAL >= 5`):
   ```
   Task:
     subagent_type: coderabbit-coordinator
     run_in_background: [true if --bg, false otherwise]
     prompt: |
       Fix CodeRabbit comments on PR #[NUMBER].
       Build command: [DETECTED_COMMAND]
       [If --quick: "Use --quick mode (critical + major only)."]
       Use up to 5 parallel workers. Group issues by file.
       After pushing, re-gather to verify no new comments. Max 3 rounds.
   ```

7. **Report**:
   - If foreground: issues fixed, rounds needed, workers used, PR link. Clean up: `rm -f .coderabbit-review.json`
   - If `--bg`: tell user the agent is running in background and provide the output file path to check progress

8. **Show metrics history** (foreground only):
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/bin/cr-metrics show --pr <NUMBER> --last 5
   ```
   If `${CLAUDE_PLUGIN_ROOT}` is not set, use `cr-metrics` directly.
   Display the output to the user — this shows performance trends across runs.
