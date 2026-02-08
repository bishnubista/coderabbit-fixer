# Claude Code x CodeRabbit Plugin

Automated CodeRabbit PR review fixer for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Reads CodeRabbit review comments, fixes them autonomously, validates the build, and pushes — with optional GitHub thread resolution.

## What It Does

```text
/fix-coderabbit 71
    │
    ▼
┌─────────────────────────────┐
│  cr-gather                  │  Fetch all CodeRabbit comments via GitHub API
│  (pagination, severity      │  Classify: critical > major > minor > nitpick
│   classification, grouping) │  Group by file for efficient fixes
└────────────┬────────────────┘
             ▼
┌─────────────────────────────┐
│  Agent Loop (Sonnet)        │  For each batch of 2 issues:
│                             │    1. Read file → apply fix
│  cr-next → fix → build →   │    2. Run build validation
│  cr-done → commit → repeat  │    3. Mark done + resolve GitHub thread
│                             │    4. Commit batch
└────────────┬────────────────┘
             ▼
┌─────────────────────────────┐
│  Verify                     │  Push → wait for CodeRabbit re-analysis
│                             │  Re-gather → fix new comments (max 3 rounds)
└─────────────────────────────┘
```

## Installation

```bash
# Clone the repo
git clone https://github.com/bishnubista/claude-coderabbit-plugin.git
cd claude-coderabbit-plugin

# Run the installer
./install.sh
```

The installer copies files to the correct locations:

| Source | Destination | Purpose |
|--------|-------------|---------|
| `bin/cr-*` | `~/.local/bin/` | CLI state management tools |
| `commands/*.md` | `~/.claude/commands/` | Claude Code slash commands |
| `agents/*.md` | `~/.claude/agents/` | Claude Code agent definitions |

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- [jq](https://jqlang.github.io/jq/) installed (`brew install jq`)

## Usage

### Quick Start

```bash
# In any repo with an open PR that has CodeRabbit reviews:
/fix-coderabbit              # Fix all issues on current PR
/fix-coderabbit 71           # Fix issues on PR #71
/fix-coderabbit --quick      # Fix only critical + major issues
/fix-coderabbit --bg         # Run in background
/fix-coderabbit 71 --quick --bg  # Combine flags
```

### Local Review (Before Pushing)

```bash
/coderabbit-review           # Review uncommitted changes
/coderabbit-review --staged  # Review only staged changes
/coderabbit-review --branch  # Review current branch vs main
```

### Manual CLI Tools

The `cr-*` tools can also be used standalone outside Claude Code:

```bash
# Fetch all CodeRabbit comments into local state
cr-gather 71

# Show progress dashboard
cr-status
cr-status --full    # Grouped by file
cr-status --json    # Raw JSON

# Get next issues to fix
cr-next             # Next 2 issues (default)
cr-next 5           # Next 5 issues
cr-next --quick     # Critical + major only
cr-next --all       # All pending issues
cr-next --brief     # Truncated output

# Mark issues as fixed (+ resolve GitHub thread)
cr-done thread-123 thread-456
cr-done --last 2        # Mark last 2 shown issues
cr-done --no-resolve    # Skip GitHub thread resolution
```

## Features

### Smart Build Detection

The plugin detects which stack changed in your PR and only validates what's needed:

```bash
# If only backend/ files changed → runs backend validation only
# If only frontend/ files changed → runs frontend validation only
# If both changed → runs both
```

Supported build systems: `uv` (Python), `bun`, `pnpm`, `npm`

### Severity Classification

Issues are classified once at gather time into a `severity` field:

| Severity | Emoji | Meaning |
|----------|-------|---------|
| `critical` | 🔴 | Security vulnerabilities, data loss risks |
| `major` | 🟠 | Bugs, missing error handling, logic errors |
| `minor` | 🟡 | Code quality, inconsistencies |
| `nitpick` | 💬 | Style, naming, minor suggestions |

`--quick` mode filters to critical + major only — useful for fast merges.

### File Grouping

Issues are sorted by severity, then grouped by file within each tier. This means the agent fixes related issues together with fewer context switches:

```text
# Instead of:          # You get:
fix router.py:45       fix router.py:45
fix service.ts:100     fix router.py:89   ← same file, adjacent
fix router.py:89       fix service.ts:100
```

### GitHub Thread Resolution

When `cr-done` marks an issue as fixed, it also resolves the corresponding GitHub review thread via the GraphQL API. The PR immediately shows green checkmarks instead of waiting for CodeRabbit's re-analysis.

Use `--no-resolve` to skip this (e.g., for testing).

### Pagination

Handles PRs with 100+ review threads via cursor-based GraphQL pagination. No silent truncation.

### Per-Batch Commits

The agent commits after every batch of 2 fixes (not all at once). This means:
- Partial rollback is possible if one fix is wrong
- Progress is saved if the agent crashes mid-way
- Git history shows incremental work

### Auto-Escalation

When `cr-gather` finds 5+ issues across 3+ files, it suggests using the `coderabbit-coordinator` agent for parallel fixes:

```text
💡 Tip: 39 issues across 19 files — consider using the coderabbit-coordinator agent for parallel fixes.
```

### Polling Backoff

After pushing fixes, the agent polls CodeRabbit with exponential backoff (10s → 15s → 20s → 30s) instead of a fixed sleep. Adapts to CodeRabbit's re-analysis speed.

## Architecture

### State File

All tools share a local JSON state file (`.coderabbit-review.json`) that tracks:

```json
{
  "repository": "owner/repo",
  "pr_number": 71,
  "gathered_at": "2026-02-08T19:03:22Z",
  "summary": {
    "total": 39,
    "critical": 0,
    "major": 1,
    "minor": 3,
    "nitpick": 35,
    "pending": 39,
    "fixed": 0,
    "files": 19
  },
  "issues": [
    {
      "id": "thread-2779625348",
      "thread_id": "PRRT_kwDORAtAgs5tWuHM",
      "type": "inline",
      "file": "backend/review/router.py",
      "line": 36,
      "severity": "major",
      "body": "...",
      "status": "pending"
    }
  ]
}
```

### Agent Architecture

| Component | Role |
|-----------|------|
| `/fix-coderabbit` | Slash command — dispatches to agent, detects build command |
| `coderabbit-pr-reviewer` | Sonnet agent — autonomous fix loop (2 issues/batch) |
| `coderabbit-coordinator` | Sonnet agent — orchestrates parallel sub-agents for large PRs |
| `cr-gather` | CLI — fetches + classifies CodeRabbit comments |
| `cr-next` | CLI — returns next batch (file-grouped, severity-filtered) |
| `cr-done` | CLI — marks fixed + resolves GitHub threads |
| `cr-status` | CLI — progress dashboard |

### Why a State File?

1. **Rate limits** — Re-fetching 100+ threads on every iteration burns GitHub API quota
2. **Progress tracking** — The agent needs to know which issues it already fixed
3. **Deterministic ordering** — Issues are sorted once by severity, then by file

## Updating

```bash
cd claude-coderabbit-plugin
git pull
./install.sh
```

## Uninstalling

```bash
./install.sh --uninstall
```

## License

MIT
