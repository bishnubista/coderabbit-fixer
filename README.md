# CodeRabbit Fixer

Claude Code plugin that automatically fixes [CodeRabbit](https://www.coderabbit.ai/) PR review comments. Gathers comments, classifies by severity, fixes in batches with build validation, resolves GitHub threads, and pushes — from a single command.

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

**What happens:** Gathers comments via GitHub API, classifies severity (critical > major > minor > nitpick), fixes 2 issues per batch, validates build after each batch, commits incrementally, pushes and re-checks (max 3 rounds).

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

| Agent | Description |
|-------|-------------|
| `coderabbit-pr-reviewer` | Autonomous fix loop — reads issues, applies fixes, validates build, commits in batches of 2 |
| `coderabbit-coordinator` | Orchestrates parallel sub-agents for large PRs (5+ issues across 3+ files) |

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

- **Smart build detection** — detects which stack changed (backend/frontend) and only validates what's needed. Supports `uv`, `bun`, `pnpm`, `npm`.
- **Severity classification** — critical, major, minor, nitpick. Use `--quick` to fix only critical + major.
- **File grouping** — related issues in the same file are fixed together for fewer context switches.
- **GitHub thread resolution** — resolved threads show green checkmarks immediately via GraphQL API.
- **Per-batch commits** — commits after every 2 fixes for safe partial rollback.
- **Auto-escalation** — suggests the coordinator agent when 5+ issues span 3+ files.
- **Pagination** — handles PRs with 100+ review threads without truncation.

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

**Version:** 1.0.0 | **Author:** [Bishnu Bista](https://github.com/bishnubista)
