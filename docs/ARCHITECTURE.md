# Architecture

Internal details for contributors and advanced users.

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

## Plugin Structure

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
├── docs/
│   └── ARCHITECTURE.md       # This file
├── install.sh                # Legacy manual installer
├── README.md
└── LICENSE
```

## Components

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

## State File

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

This file is temporary and deleted after the fix cycle completes. Add it to `.gitignore`:

```bash
echo '.coderabbit-review.json' >> .gitignore
```

## Severity Classification

Issues are classified at gather time into four severity tiers:

| Severity | Meaning | Examples |
|----------|---------|---------|
| `critical` | Security vulnerabilities, data loss risks | SQL injection, missing auth checks |
| `major` | Bugs, missing error handling, logic errors | Unhandled exceptions, race conditions |
| `minor` | Code quality, inconsistencies | Missing types, naming conventions |
| `nitpick` | Style, minor suggestions | Formatting, comment wording |
