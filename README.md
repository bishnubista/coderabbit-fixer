# CodeRabbit Fixer

Claude Code plugin that automatically fixes [CodeRabbit](https://www.coderabbit.ai/) PR review comments. From a single command: gathers comments, classifies by severity, fixes with build validation, verifies every fix, resolves GitHub threads, and pushes.

## The Problem

CodeRabbit reviews your PRs and leaves detailed comments — but fixing them is a manual grind:

1. **Tedious iteration** — Open each comment, understand the suggestion, edit the file, repeat. A PR with 15 comments takes 30-60 minutes of mechanical work.
2. **AI agents forget fixes** — When you ask Claude Code to fix CodeRabbit comments, it processes some and silently skips others. You end up manually checking every comment to verify it was actually addressed.
3. **Slow feedback loop** — Fix, push, wait for CodeRabbit to re-review, find new comments, repeat. Each round takes 3-5 minutes of waiting.
4. **No visibility** — There's no easy way to see how many issues were fixed vs. skipped, or track performance across runs.

## The Solution

CodeRabbit Fixer turns the entire fix cycle into one command:

```bash
/fix-coderabbit
```

**How it prevents forgotten fixes:**
- **Verification gate** — After fixing, the agent re-reads every file to confirm each fix actually landed. Issues are classified as VERIFIED, MISSED, or SKIPPED. Only verified fixes get marked as done.
- **Structured state tracking** — A JSON state file tracks every issue by ID. `cr-done` is only called on issues that pass verification. Nothing slips through.
- **Parallel workers for large PRs** — 5+ issues automatically triggers parallel sub-agents, each owning a file group. Same-file issues always go to the same worker (no conflicts, no context overload).
- **Metrics across runs** — `cr-metrics show` displays a comparison table so you can see fixed/total ratio and catch regressions.

## Commands

### `/fix-coderabbit` — Fix PR Review Comments

Fetches all CodeRabbit comments from a PR, then autonomously fixes them with build validation.

```bash
/fix-coderabbit              # Fix all issues on current PR
/fix-coderabbit 71           # Fix issues on PR #71
/fix-coderabbit --quick      # Critical + major only (skip minor/nitpick)
/fix-coderabbit --bg         # Run in background
/fix-coderabbit 71 --quick --bg  # Combine flags
```

**What happens:**

| Issues | Agent | Strategy |
|--------|-------|----------|
| < 5 | `coderabbit-pr-reviewer` | Single agent, fixes one at a time, verification gate, one build + commit |
| >= 5 | `coderabbit-coordinator` | Groups by file, spawns up to 5 parallel workers, orchestrator verifies all, one build + commit |

After pushing, waits for CodeRabbit to re-review and fixes new comments (max 3 rounds). Shows metrics history at the end.

### `/coderabbit-review` — Local Review Before Pushing

Runs the [CodeRabbit CLI](https://docs.coderabbit.ai/cli/overview) locally to catch issues before they reach your PR.

```bash
/coderabbit-review              # Review uncommitted changes
/coderabbit-review --staged     # Review only staged changes
/coderabbit-review --committed  # Review the last commit
/coderabbit-review --branch     # Review current branch vs main
```

Requires the CodeRabbit CLI (optional dependency). See [How do I install the CodeRabbit CLI?](#how-do-i-install-the-coderabbit-cli) below.

## Agents

| Agent | When | Strategy |
|-------|------|----------|
| `coderabbit-pr-reviewer` | < 5 issues | Single agent fixes one-at-a-time with verification gate |
| `coderabbit-coordinator` | >= 5 issues | Spawns up to 5 parallel workers grouped by file, orchestrator verifies all fixes |

## Installation

### As a Claude Code Plugin (recommended)

```bash
# Inside Claude Code, run:
/plugin install https://github.com/bishnubista/coderabbit-fixer
```

### Manual Install

```bash
git clone https://github.com/bishnubista/coderabbit-fixer.git
cd coderabbit-fixer && ./install.sh
```

## Prerequisites

| Dependency | Required? | Purpose | Install |
|------------|-----------|---------|---------|
| [Claude Code](https://code.claude.com/) | Yes | Platform this plugin runs on | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Yes | Fetches PR comments, resolves threads | See [install instructions](#how-do-i-install-the-github-cli-gh) |
| [jq](https://jqlang.github.io/jq/) | Yes | JSON processing for state management | See [install instructions](#how-do-i-install-jq) |
| [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) | Yes | Provides the review comments to fix | [Install on your repo](https://github.com/apps/coderabbitai) |
| [CodeRabbit CLI](https://docs.coderabbit.ai/cli/overview) | No | Local review via `/coderabbit-review` | See [install instructions](#how-do-i-install-the-coderabbit-cli) |

Verify your setup:

```bash
gh auth status          # GitHub CLI authenticated
jq --version            # jq installed
which claude            # Claude Code installed
```

## Features

- **Verification gate** — re-reads every file after fixing to confirm each change actually landed. Only verified fixes get marked done.
- **Parallel workers** — 5+ issues triggers the coordinator, which spawns up to 5 sub-agents grouped by file. Same-file issues always go to the same worker.
- **Smart build detection** — detects which stack changed (backend/frontend) and only validates what's needed. Supports `uv`, `bun`, `pnpm`, `npm`.
- **Severity classification** — critical, major, minor, nitpick. Use `--quick` to fix only critical + major.
- **Metrics tracking** — `cr-metrics show` displays a comparison table across runs with timing, fix counts, and trends.
- **File grouping** — issues in the same file are processed together for fewer context switches.
- **GitHub thread resolution** — resolved threads show green checkmarks immediately via GraphQL API.
- **Auto-selection** — `/fix-coderabbit` picks the right agent (single vs. parallel) based on issue count.
- **Pagination** — handles PRs with 100+ review threads without truncation.

## CLI Tools

Standalone tools for manual use or scripting:

```bash
cr-gather 71                    # Fetch all CodeRabbit comments
cr-status                       # Progress dashboard
cr-next --all                   # See all pending issues
cr-done thread-123 thread-456   # Mark issues as fixed
cr-metrics show --pr 71         # Compare runs for a PR
cr-metrics reset                # Clear metrics history
```

## FAQ

### How do I install the GitHub CLI (`gh`)?

Required for all `cr-*` tools to fetch PR comments and resolve threads.

| Platform | Command |
|----------|---------|
| macOS (Homebrew) | `brew install gh` |
| Windows (WinGet) | `winget install --id GitHub.cli` |
| Debian/Ubuntu | See [official instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) |
| Other | See [cli.github.com](https://cli.github.com/) |

After installing, run `gh auth login`.

### How do I install the CodeRabbit CLI?

Optional — only needed for `/coderabbit-review` (local review). The main `/fix-coderabbit` command does not need it.

| Platform | Command |
|----------|---------|
| macOS/Linux (curl) | `curl -fsSL https://cli.coderabbit.ai/install.sh \| sh` |
| macOS (Homebrew) | `brew install --cask coderabbit` |

After installing, restart your shell and verify with `coderabbit --version`. See the [CodeRabbit CLI docs](https://docs.coderabbit.ai/cli/overview).

### Do I need a CodeRabbit subscription?

**For `/fix-coderabbit`:** You need the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your repo.
- **Open-source repos:** Free — full Pro features at no cost for public repositories.
- **Private repos:** Requires a paid plan (Lite $12/seat/mo, Pro $24/seat/mo, Enterprise custom). Free 14-day trial available. See [CodeRabbit Pricing](https://www.coderabbit.ai/pricing).

**For `/coderabbit-review`:** The CLI is free under usage limits. No subscription required.

### How do I install `jq`?

Required for JSON processing in the `cr-*` tools.

| Platform | Command |
|----------|---------|
| macOS (Homebrew) | `brew install jq` |
| Windows (WinGet) | `winget install jqlang.jq` |
| Debian/Ubuntu | `sudo apt install jq` |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `gh` not authenticated | Run `gh auth login` — the plugin needs read and write access to PRs |
| `cr-gather` returns 0 issues | Verify CodeRabbit has reviewed the PR and the [GitHub App](https://github.com/apps/coderabbitai) is installed |
| `cr-*` commands not found | Add `~/.local/bin` to PATH (manual install only). Not needed with `/plugin` install |
| `/coderabbit-review` fails | Install the [CodeRabbit CLI](#how-do-i-install-the-coderabbit-cli) (separate from the GitHub App) |

## Updating

```bash
# Plugin install:
/plugin update coderabbit-fixer

# Manual install:
cd coderabbit-fixer && git pull && ./install.sh
```

## Uninstalling

```bash
# Plugin install:
/plugin uninstall coderabbit-fixer

# Manual install:
./install.sh --uninstall
```

## Architecture

For internals (state file format, CLI tool reference, flow diagrams, component details), see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

MIT

---

**Version:** 1.1.0 | **Author:** [Bishnu Bista](https://github.com/bishnubista)
