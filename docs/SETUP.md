# Setup & FAQ

## Prerequisites

| Dependency | Required? | Purpose | Install |
|------------|-----------|---------|---------|
| [Claude Code](https://code.claude.com/) | Yes | Platform this plugin runs on | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Yes | Fetches PR comments, resolves threads | See [below](#how-do-i-install-the-github-cli-gh) |
| [jq](https://jqlang.github.io/jq/) | Yes | JSON processing for state management | See [below](#how-do-i-install-jq) |
| [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) | Yes | Provides the review comments to fix | [Install on your repo](https://github.com/apps/coderabbitai) |
| [CodeRabbit CLI](https://docs.coderabbit.ai/cli/overview) | No | Local review via `/coderabbit-review` | See [below](#how-do-i-install-the-coderabbit-cli) |

Verify your setup:

```bash
gh auth status          # GitHub CLI authenticated
jq --version            # jq installed
which claude            # Claude Code installed
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
