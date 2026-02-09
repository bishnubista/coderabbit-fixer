# CodeRabbit Fixer

Claude Code plugin that automatically fixes [CodeRabbit](https://www.coderabbit.ai/) PR review comments.

## The Problem

CodeRabbit leaves great review comments — but fixing them is painful:

- **AI agents forget fixes** — You ask Claude Code to fix the comments, it processes some and silently skips others. You end up manually checking every comment.
- **Tedious iteration** — 15 comments = open each one, understand it, edit the file, repeat for 30-60 minutes.
- **No accountability** — No way to know how many were actually fixed vs. skipped until you check yourself.

## The Solution

```bash
/fix-coderabbit
```

One command. Every comment gets fixed, verified, and resolved.

- **Verification gate** — After fixing, re-reads every file to confirm each fix actually landed. Only verified fixes get marked done.
- **Parallel workers** — 5+ issues triggers up to 5 sub-agents, each owning a file group. Same-file issues always go to the same worker.
- **Metrics** — `cr-metrics show` tracks fixed/total across runs so you can see if anything was missed.

## Install

```bash
# Claude Code plugin (recommended):
/plugin install https://github.com/bishnubista/coderabbit-fixer

# Manual:
git clone https://github.com/bishnubista/coderabbit-fixer.git
cd coderabbit-fixer && ./install.sh
```

Requires: [Claude Code](https://code.claude.com/), [`gh`](https://cli.github.com/), [`jq`](https://jqlang.github.io/jq/), [CodeRabbit GitHub App](https://github.com/apps/coderabbitai). See [docs/SETUP.md](docs/SETUP.md) for install details.

## Usage

```bash
/fix-coderabbit              # Fix all issues on current PR
/fix-coderabbit 71           # Fix issues on PR #71
/fix-coderabbit --quick      # Critical + major only
/fix-coderabbit --bg         # Run in background
```

Auto-selects the right strategy:

| Issues | Strategy |
|--------|----------|
| < 5 | Single agent, one-at-a-time fixes, verification gate |
| >= 5 | Parallel workers grouped by file, orchestrator verifies all |

```bash
/coderabbit-review           # Local review before pushing (needs CodeRabbit CLI)
```

## Docs

- [Setup, FAQ & Troubleshooting](docs/SETUP.md)
- [Architecture & Internals](docs/ARCHITECTURE.md)

## License

MIT

---

**Version:** 1.1.0 | **Author:** [Bishnu Bista](https://github.com/bishnubista)
