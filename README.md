# CodeRabbit Fixer

Claude Code plugin that automatically fixes [CodeRabbit](https://www.coderabbit.ai/) PR review comments.

## The Problem

CodeRabbit leaves great review comments — but fixing them is painful:

- **AI agents forget fixes** — You ask Claude Code to fix the comments, it processes some and silently skips others. You end up manually checking every comment.
- **Tedious iteration** — 15 comments = open each one, understand it, edit the file, repeat for 30-60 minutes.
- **No accountability** — No way to know how many were actually fixed vs. skipped until you check yourself.

## Quick Start

**Prerequisites:** [Claude Code](https://code.claude.com/) + [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your repo + `gh` and `jq` (`brew install gh jq`)

**Step 1** — Install the plugin (run inside Claude Code):

```bash
/plugin install https://github.com/bishnubista/coderabbit-fixer
```

**Step 2** — Open a PR that has CodeRabbit review comments, then run:

```bash
/fix-coderabbit
```

That's it. It gathers all comments, fixes them, verifies every fix, resolves the GitHub threads, and pushes.

## How It Works

- **Verification gate** — After fixing, re-reads every file to confirm each fix actually landed. Only verified fixes get marked done.
- **Auto-scales** — < 5 issues uses a single agent. >= 5 issues spawns up to 5 parallel workers, each owning a file group.
- **Metrics** — `cr-metrics show` tracks fixed/total across runs so you can see if anything was missed.

## More Options

```bash
/fix-coderabbit 71           # Fix issues on specific PR
/fix-coderabbit --quick      # Critical + major only (skip nitpicks)
/fix-coderabbit --bg         # Run in background
/coderabbit-review           # Local review before pushing (needs CodeRabbit CLI)
```

<details>
<summary>Manual install (without plugin system)</summary>

```bash
git clone https://github.com/bishnubista/coderabbit-fixer.git
cd coderabbit-fixer && ./install.sh
```

</details>

## Docs

- [Setup, FAQ & Troubleshooting](docs/SETUP.md)
- [Architecture & Internals](docs/ARCHITECTURE.md)

## License

MIT
