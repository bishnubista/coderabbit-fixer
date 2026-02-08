# Claude Code x CodeRabbit Plugin

Automated [CodeRabbit](https://www.coderabbit.ai/) PR review fixer for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Fetches CodeRabbit review comments, fixes them autonomously with build validation, resolves GitHub threads, and pushes — all from a single slash command.

## Quickstart

### Option A: Install as Claude Code Plugin

```bash
# Inside Claude Code, run:
/plugin install https://github.com/bishnubista/claude-coderabbit-plugin
```

### Option B: Manual Install (legacy)

```bash
git clone https://github.com/bishnubista/claude-coderabbit-plugin.git
cd claude-coderabbit-plugin && ./install.sh
```

Then in any repo with a CodeRabbit-reviewed PR:

```bash
/fix-coderabbit 71
```

That's it. The agent gathers comments, classifies severity, fixes in batches, validates the build, commits, pushes, and verifies.

## Prerequisites

### Required

| Dependency | Purpose | Install |
|------------|---------|---------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | AI coding agent (the platform this plugin runs on) | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Fetches PR comments, resolves threads via GraphQL API | `brew install gh` then `gh auth login` |
| [jq](https://jqlang.github.io/jq/) | JSON processing for state management | `brew install jq` |
| [CodeRabbit](https://www.coderabbit.ai/) GitHub App | Provides the PR review comments to fix | [Install on your repo](https://github.com/apps/coderabbitai) |

### Optional

| Dependency | Purpose | Install |
|------------|---------|---------|
| [CodeRabbit CLI](https://www.coderabbit.ai/cli) | Local code review before pushing (for `/coderabbit-review`) | `curl -fsSL https://cli.coderabbit.ai/install.sh \| sh` |

### Verify Setup

```bash
# Check all required dependencies
gh auth status          # GitHub CLI authenticated
jq --version            # jq installed
which claude            # Claude Code installed
```

## Installation Details

### Plugin Install (recommended)

When installed via `/plugin`, Claude Code manages all files automatically. The `cr-*` CLI tools are referenced via `${CLAUDE_PLUGIN_ROOT}/bin/` — no PATH changes needed.

### Manual Install (legacy)

The `install.sh` script copies files to the standard Claude Code locations:

| Source | Destination | Purpose |
|--------|-------------|---------|
| `bin/cr-*` | `~/.local/bin/` | CLI state management tools |
| `commands/*.md` | `~/.claude/commands/` | Slash commands |
| `agents/*.md` | `~/.claude/agents/` | Agent definitions |

If `~/.local/bin` is not in your PATH, the installer will prompt you to add it.

### Generated Files

The plugin creates a `.coderabbit-review.json` state file in your project directory during operation. Add it to your project's `.gitignore`:

```bash
echo '.coderabbit-review.json' >> .gitignore
```

This file is temporary and deleted after the fix cycle completes.

## Commands

### `/fix-coderabbit` — Fix PR Review Comments

The primary command. Fetches all CodeRabbit comments from a PR, then dispatches an autonomous agent to fix them in batches with build validation.

```bash
/fix-coderabbit              # Fix all issues on current PR
/fix-coderabbit 71           # Fix issues on PR #71
/fix-coderabbit --quick      # Critical + major issues only (skip minor/nitpick)
/fix-coderabbit --bg         # Run in background
/fix-coderabbit 71 --quick --bg  # Combine flags
```

**What happens:**

1. `cr-gather` fetches all CodeRabbit comments via GitHub GraphQL API
2. Issues are classified by severity and grouped by file
3. Agent fixes 2 issues per batch, validates the build after each batch
4. Each batch is committed separately (allows partial rollback)
5. After all fixes, pushes and waits for CodeRabbit re-analysis
6. If new comments appear, repeats (max 3 rounds)

### `/coderabbit-review` — Local Review Before Pushing

Runs the CodeRabbit CLI locally to catch issues before they reach your PR. Requires the [CodeRabbit CLI](https://www.coderabbit.ai/cli) (optional dependency).

```bash
/coderabbit-review              # Review uncommitted changes
/coderabbit-review --staged     # Review only staged changes
/coderabbit-review --committed  # Review the last commit
/coderabbit-review --branch     # Review current branch vs main
```

## How It Works

```text
/fix-coderabbit 71
    |
    v
+-----------------------------+
|  cr-gather                  |  Fetch all CodeRabbit comments via GitHub API
|  (pagination, severity      |  Classify: critical > major > minor > nitpick
|   classification, grouping) |  Group by file for efficient fixes
+-------------+---------------+
              |
              v
+-----------------------------+
|  Agent Loop (Sonnet)        |  For each batch of 2 issues:
|                             |    1. Read file -> apply fix
|  cr-next -> fix -> build -> |    2. Run build validation
|  cr-done -> commit -> repeat|    3. Mark done + resolve GitHub thread
|                             |    4. Commit batch
+-------------+---------------+
              |
              v
+-----------------------------+
|  Verify                     |  Push -> wait for CodeRabbit re-analysis
|                             |  Re-gather -> fix new comments (max 3 rounds)
+-----------------------------+
```

## Features

### Smart Build Detection

Detects which stack changed in your PR and only validates what's needed:

- Backend only (`backend/` files changed) — runs backend validation
- Frontend only (`frontend/` or `src/` files changed) — runs frontend validation
- Both changed — runs both

Supported build systems: `uv` (Python), `bun`, `pnpm`, `npm`

### Severity Classification

Issues are classified at gather time into four severity tiers:

| Severity | Meaning | Examples |
|----------|---------|---------|
| `critical` | Security vulnerabilities, data loss risks | SQL injection, missing auth checks |
| `major` | Bugs, missing error handling, logic errors | Unhandled exceptions, race conditions |
| `minor` | Code quality, inconsistencies | Missing types, naming conventions |
| `nitpick` | Style, minor suggestions | Formatting, comment wording |

Use `--quick` to fix only critical + major — useful for fast merges.

### File Grouping

Issues are sorted by severity, then grouped by file. The agent fixes related issues together with fewer context switches:

```text
# Instead of:          # You get:
fix router.py:45       fix router.py:45
fix service.ts:100     fix router.py:89   <- same file, adjacent
fix router.py:89       fix service.ts:100
```

### GitHub Thread Resolution

When `cr-done` marks an issue as fixed, it resolves the corresponding GitHub review thread via GraphQL API. The PR immediately shows green checkmarks instead of waiting for CodeRabbit's re-analysis.

### Per-Batch Commits

The agent commits after every batch of 2 fixes (not all at once):

- Partial rollback is possible if one fix is wrong
- Progress is saved if the agent crashes mid-way
- Git history shows incremental work

### Auto-Escalation

When `cr-gather` finds 5+ issues across 3+ files, it suggests using the `coderabbit-coordinator` agent for parallel fixes across multiple sub-agents.

### Pagination

Handles PRs with 100+ review threads via cursor-based GraphQL pagination. No silent truncation.

## CLI Tools

The `cr-*` tools can be used standalone outside Claude Code:

```bash
cr-gather 71            # Fetch all CodeRabbit comments into .coderabbit-review.json

cr-status               # Progress dashboard
cr-status --full        # All issues grouped by file
cr-status --json        # Raw JSON output

cr-next                 # Next 2 pending issues (default)
cr-next 5               # Next 5 issues
cr-next --quick         # Critical + major only
cr-next --all           # All pending issues
cr-next --brief         # Truncated output (500 chars)

cr-done thread-123 thread-456   # Mark specific issues as fixed + resolve threads
cr-done --last 2                # Mark last 2 shown issues
cr-done --no-resolve            # Skip GitHub thread resolution
```

## Architecture

### Plugin Structure

```text
coderabbit-fixer/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest (name, version, keywords)
├── commands/
│   ├── fix-coderabbit.md     # /fix-coderabbit slash command
│   └── coderabbit-cli-review.md  # /coderabbit-review slash command
├── agents/
│   ├── coderabbit-pr-reviewer.md  # Autonomous fix agent (Sonnet)
│   └── coderabbit-coordinator.md  # Multi-agent orchestrator (Sonnet)
├── bin/
│   ├── cr-gather             # Fetch + classify CodeRabbit comments
│   ├── cr-next               # Return next batch (file-grouped, severity-filtered)
│   ├── cr-done               # Mark fixed + resolve GitHub threads
│   └── cr-status             # Progress dashboard
├── install.sh                # Legacy manual installer
├── README.md
└── LICENSE
```

### Components

| Component | Type | Role |
|-----------|------|------|
| `/fix-coderabbit` | Slash command | Dispatches to agent, detects build command |
| `/coderabbit-review` | Slash command | Local review via CodeRabbit CLI |
| `coderabbit-pr-reviewer` | Agent (Sonnet) | Autonomous fix loop, 2 issues per batch |
| `coderabbit-coordinator` | Agent (Sonnet) | Orchestrates parallel sub-agents for large PRs |
| `cr-gather` | CLI tool | Fetches + classifies CodeRabbit comments |
| `cr-next` | CLI tool | Returns next batch (file-grouped, severity-filtered) |
| `cr-done` | CLI tool | Marks fixed + resolves GitHub threads |
| `cr-status` | CLI tool | Progress dashboard |

### State File

All tools share a local JSON state file (`.coderabbit-review.json`):

```json
{
  "repository": "owner/repo",
  "pr_number": 71,
  "gathered_at": "2026-02-08T19:03:22Z",
  "summary": {
    "total": 39, "critical": 0, "major": 1,
    "minor": 3, "nitpick": 35,
    "pending": 39, "fixed": 0, "files": 19
  },
  "issues": [
    {
      "id": "thread-2779625348",
      "thread_id": "PRRT_kwDORAtAgs5tWuHM",
      "file": "backend/review/router.py",
      "line": 36,
      "severity": "major",
      "status": "pending"
    }
  ]
}
```

**Why a state file?**

1. **Rate limits** — re-fetching 100+ threads on every iteration burns GitHub API quota
2. **Progress tracking** — the agent needs to know which issues it already fixed
3. **Deterministic ordering** — issues are sorted once by severity, then by file

## Troubleshooting

### `gh` not authenticated

```text
ERROR: gh not authenticated (gh auth login)
```

Run `gh auth login` and follow the prompts. The plugin needs read/write access to PRs.

### `cr-gather` returns 0 issues

- Verify CodeRabbit has reviewed the PR (check for the `coderabbitai` bot comments)
- Ensure the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) is installed on the repository
- Check if all threads are already resolved: `cr-gather` only fetches unresolved threads

### `cr-*` commands not found (manual install only)

Ensure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"  # Add to ~/.zshrc or ~/.bashrc
```

This is not needed when installed via `/plugin` — the plugin uses `${CLAUDE_PLUGIN_ROOT}/bin/` paths.

### `/coderabbit-review` fails

This command requires the CodeRabbit CLI (separate from the GitHub App):

```bash
curl -fsSL https://cli.coderabbit.ai/install.sh | sh
```

## Updating

### Plugin Install

```bash
# Inside Claude Code:
/plugin update coderabbit-fixer
```

### Manual Install

```bash
cd claude-coderabbit-plugin
git pull
./install.sh
```

## Uninstalling

### Plugin Install

```bash
# Inside Claude Code:
/plugin uninstall coderabbit-fixer
```

### Manual Install

```bash
./install.sh --uninstall
```

## License

MIT

---

**Version:** 1.0.0 | **Author:** Bishnu Bista
