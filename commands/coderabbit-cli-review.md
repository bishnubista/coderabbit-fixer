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

### Step 1: Determine Review Type

Parse `$ARGUMENTS` to determine the review type:

| Argument | Review Type | Description |
|----------|-------------|-------------|
| (none) | `uncommitted` | Review staged + unstaged changes |
| `--staged` | `staged` | Review only staged changes |
| `--committed` | `committed` | Review last commit vs parent |
| `--branch` | `branch` | Review current branch vs main |

### Step 2: Run CodeRabbit CLI

```bash
# Default: review uncommitted changes
coderabbit review --plain

# Or with specific type:
coderabbit review --plain --type <TYPE>

# For branch comparison:
coderabbit review --plain --type branch --base-branch main
```

### Step 3: Present Results

Display the CodeRabbit output to the user. If issues are found:

1. Summarize the key findings by category (security, logic, style, etc.)
2. Ask if the user wants help fixing any specific issues
3. If yes, make the fixes and re-run the review to verify

### Step 4: Optional - Fix Issues

If the user wants fixes:
1. Address issues one at a time
2. Re-run `coderabbit review --plain` after fixes
3. Continue until clean or user is satisfied

## Examples

```bash
/coderabbit-review              # Review all uncommitted changes
/coderabbit-review --staged     # Review only staged changes
/coderabbit-review --committed  # Review the last commit
/coderabbit-review --branch     # Review branch vs main
```

## Notes

- CodeRabbit CLI is free under usage limits
- Reviews only analyze diffs, not entire codebase
- Output is in plain text format for easy parsing
- Uses locally installed `coderabbit` CLI (installed at `~/.local/bin/coderabbit`)
