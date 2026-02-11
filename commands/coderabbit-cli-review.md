---
description: Run CodeRabbit CLI for local AI code review (before pushing to PR)
allowed-tools: Bash, Read, Edit, Write
---

# CodeRabbit CLI Local Review

Run AI-powered code reviews locally using the CodeRabbit CLI, catching issues before they reach your PR.

## When to Use

- Before opening a PR to catch issues early
- After making changes to validate code quality
- To get security, logic, and best practice feedback

## Instructions

### Step 0: Check Prerequisites

Before running the review, verify the CodeRabbit CLI is installed:

```bash
command -v coderabbit &>/dev/null
```

If the command is NOT found, stop and tell the user:

> **CodeRabbit CLI is not installed.** Install it with one of:
>
> - **curl (macOS/Linux):** `curl -sSL https://cli.coderabbit.ai/install.sh | sh`
> - **Homebrew (macOS):** `brew install coderabbitai/tap/coderabbit`
>
> Then restart your shell and retry.
>
> See: https://docs.coderabbit.ai/cli/getting-started

Do NOT proceed to Step 1 if the CLI is missing.

### Step 1: Determine Review Type

Parse `$ARGUMENTS` and build a valid CodeRabbit CLI command:

| Argument | CLI Value | Description |
|----------|-----------|-------------|
| (none) | `all` | Review both committed + uncommitted changes |
| `committed` | `committed` | Review committed changes |
| `uncommitted` | `uncommitted` | Review working tree changes |
| `all` | `all` | Explicit default mode |
| `--base <branch>` | `--base <branch>` | Compare committed changes against a base branch |

Backward compatibility aliases (map silently):
- `--committed` → `committed`
- `--staged` → `uncommitted`
- `--branch` → `committed --base main`

### Step 2: Run CodeRabbit CLI

```bash
# Default: review all changes
coderabbit --plain --type all

# Specific mode:
coderabbit --plain --type <all|committed|uncommitted>

# Compare against a specific base branch:
coderabbit --plain --type committed --base <branch>
```

### Step 3: Present Results

Display the CodeRabbit output to the user. If issues are found:

1. Summarize the key findings by category (security, logic, style, etc.)
2. Ask if the user wants help fixing any specific issues
3. If yes, make the fixes and re-run the review to verify

### Step 4: Optional - Fix Issues

If the user wants fixes:
1. Address issues one at a time
2. Re-run `coderabbit --plain --type all` (or the same mode) after fixes
3. Continue until clean or user is satisfied

## Examples

```bash
/coderabbit-review              # Review all changes
/coderabbit-review committed    # Review committed changes
/coderabbit-review uncommitted  # Review working tree changes
/coderabbit-review committed --base main
```

## Notes

- CodeRabbit CLI is free under usage limits
- Reviews only analyze diffs, not entire codebase
- Output is in plain text format for easy parsing
- Uses locally installed `coderabbit` CLI (on your PATH; location varies by install method)
- CLI is currently available on macOS, Linux, and Windows via WSL
