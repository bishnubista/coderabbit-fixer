# Setup & FAQ

## Prerequisites

| Dependency | Required? | Purpose | Install |
|------------|-----------|---------|---------|
| [Claude Code](https://code.claude.com/) | Yes | Platform this plugin runs on | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Yes | Fetches PR comments, resolves threads | See [below](#how-do-i-install-the-github-cli-gh) |
| [jq](https://jqlang.github.io/jq/) | Yes | JSON processing for state management | See [below](#how-do-i-install-jq) |
| Python 3 | Default runtime | Runs `cr-*` commands by default | `python3 --version` |
| [Bun](https://bun.sh/) | Optional runtime | Alternative `cr-*` runtime if selected | `bun --version` |
| [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) | Yes | Provides the review comments to fix | [Install on your repo](https://github.com/apps/coderabbitai) |
| [CodeRabbit CLI](https://docs.coderabbit.ai/cli/reference) | No | Local review via `/coderabbit-review` | See [below](#how-do-i-install-the-coderabbit-cli) |

Verify your setup:

```bash
gh auth status          # GitHub CLI authenticated
jq --version            # jq installed
python3 --version       # Python runtime (default)
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
| macOS/Linux (install script) | `curl -sSL https://cli.coderabbit.ai/install.sh \| sh` |
| macOS (Homebrew) | `brew install coderabbitai/tap/coderabbit` |
| Windows | Use WSL, then run the Linux install script in WSL |

After installing, restart your shell and verify with `coderabbit --version`. See the [CodeRabbit CLI docs](https://docs.coderabbit.ai/cli/getting-started).

### Do I need a CodeRabbit subscription?

**For `/fix-coderabbit`:** You need the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your repo.
- **Open-source repos:** Free — full Pro features at no cost for public repositories.
- **Private repos:** Requires a paid plan. See [CodeRabbit Pricing](https://www.coderabbit.ai/pricing) for current tiers.

**For `/coderabbit-review`:** The CLI is free under usage limits. No subscription required.

### How do I install `jq`?

Required for JSON processing in the `cr-*` tools.

| Platform | Command |
|----------|---------|
| macOS (Homebrew) | `brew install jq` |
| Windows (WinGet) | `winget install jqlang.jq` |
| Debian/Ubuntu | `sudo apt install jq` |

### How do runtime selection and fallback work?

`cr-*` commands support three runtimes: `python` (default), `bash`, `bun`.

Set runtime on manual install:

```bash
./install.sh --runtime python
./install.sh --runtime bash
./install.sh --runtime bun
```

Override per command:

```bash
CR_IMPL=bash cr-next
CR_IMPL=bun cr-next
```

If the chosen runtime is unavailable, commands automatically fall back to Bash.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `gh` not authenticated | Run `gh auth login` — the plugin needs read and write access to PRs |
| `cr-gather` returns 0 issues | Verify CodeRabbit has reviewed the PR and the [GitHub App](https://github.com/apps/coderabbitai) is installed |
| `cr-*` commands not found | Add `~/.local/bin` to PATH (manual install only). Not needed with `/plugin` install |
| `python3` or `bun` missing | Install the runtime or select another with `./install.sh --runtime ...` |
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
