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
+-------------+---------------+  Record metrics.started_at
              |
              v
+-----------------------------+
|  Auto-select agent          |  < 5 issues → single agent
|  based on issue count       |  >= 5 issues → parallel coordinator
+------+-------------+-------+
       |             |
       v             v
+-------------+  +---------------------------+
| Single      |  | Coordinator               |
| Agent       |  |  Group by file             |
| (Sonnet)    |  |  Spawn up to 5 workers     |
|             |  |  Each worker: fix its files |
| Fix one at  |  |  Workers report results     |
| a time      |  +---------------------------+
+------+------+         |
       |                 v
       |         +---------------------------+
       |         | Verification Gate         |
       +-------->| Re-read each file         |
                 | Confirm fix addresses     |
                 | the CodeRabbit comment    |
                 | VERIFIED / MISSED / SKIP  |
                 +-------------+-------------+
                               |
                               v
                 +---------------------------+
                 | cr-done (verified only)   |
                 | Build once                |
                 | Commit once               |
                 | Push → re-gather          |
                 | (max 3 rounds)            |
                 +---------------------------+
                               |
                               v
                 +---------------------------+
                 | cr-metrics end            |
                 | Log timing, counts        |
                 | Show trend table          |
                 +---------------------------+
```

## Plugin Structure

```text
coderabbit-fixer/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest (name, version, keywords)
├── commands/
│   ├── fix-coderabbit.md     # /fix-coderabbit slash command (auto-selects agent)
│   └── coderabbit-cli-review.md  # /coderabbit-review slash command
├── agents/
│   ├── coderabbit-pr-reviewer.md  # Single-agent fixer (< 5 issues)
│   └── coderabbit-coordinator.md  # Parallel orchestrator (>= 5 issues)
├── bin/
│   ├── cr-gather             # Fetch + classify CodeRabbit comments
│   ├── cr-next               # Return next batch (file-grouped, severity-filtered)
│   ├── cr-done               # Mark fixed + resolve GitHub threads
│   ├── cr-status             # Progress dashboard
│   └── cr-metrics            # Track run timing + comparison table
├── docs/
│   └── ARCHITECTURE.md       # This file
├── install.sh                # Legacy manual installer
├── README.md
└── LICENSE
```

## Components

| Component | Type | Role |
|-----------|------|------|
| `/fix-coderabbit` | Slash command | Auto-selects agent, detects build command |
| `/coderabbit-review` | Slash command | Local review via CodeRabbit CLI |
| `coderabbit-pr-reviewer` | Agent (Sonnet) | Single-agent fix loop with verification gate |
| `coderabbit-coordinator` | Agent (Sonnet) | Parallel orchestrator: groups by file, spawns up to 5 workers |
| `cr-gather` | CLI tool | Fetches + classifies CodeRabbit comments, records start time |
| `cr-next` | CLI tool | Returns next batch (file-grouped, severity-filtered) |
| `cr-done` | CLI tool | Marks fixed + resolves GitHub threads |
| `cr-status` | CLI tool | Progress dashboard |
| `cr-metrics` | CLI tool | Track run timing, comparison table, trends |

## Agent Selection

| Condition | Agent | Reason |
|-----------|-------|--------|
| < 5 issues | `coderabbit-pr-reviewer` | Single agent, low overhead, verification gate |
| >= 5 issues | `coderabbit-coordinator` | Parallel workers (max 5), grouped by file |

## Parallel Worker Safety

Workers run in parallel but are isolated by file ownership:

```text
Worker 1: [src/auth/login.ts, src/auth/session.ts]     ← owns these files
Worker 2: [src/api/routes.ts]                           ← owns this file
Worker 3: [src/components/Nav.tsx, src/components/Sidebar.tsx]
```

**Safety rules:**
- Same file → same worker (NEVER split across workers)
- Workers do NOT touch `.coderabbit-review.json` (orchestrator owns state)
- Workers do NOT run git commands (orchestrator owns commits)
- Workers do NOT run build commands (orchestrator builds once)
- Orchestrator verifies every fix before calling `cr-done`

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

cr-metrics end --builds 1 --commits 1 --rounds 1   # Log a completed run
cr-metrics show --pr 42 --last 5                    # Compare runs for a PR
cr-metrics reset                                     # Clear all metrics
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
  ],
  "metrics": {
    "started_at": "2026-02-08T19:03:22Z"
  }
}
```

**Why a state file?**

1. **Rate limits** — re-fetching 100+ threads on every iteration burns GitHub API quota
2. **Progress tracking** — the agent needs to know which issues it already fixed
3. **Deterministic ordering** — issues are sorted once by severity, then by file
4. **Metrics** — `started_at` timestamp enables duration tracking

This file is temporary and deleted after the fix cycle completes. Add it to `.gitignore`:

```bash
echo '.coderabbit-review.json' >> .gitignore
```

## Metrics File

Run history is stored in `~/.coderabbit-metrics.jsonl` (one JSON object per line):

```json
{"pr":42,"repo":"owner/name","started_at":"...","ended_at":"...","duration_s":270,"issues":{"total":10,"critical":0,"major":2,"minor":5,"nitpick":3},"fixed":7,"builds":1,"commits":1,"rounds":1}
```

## Severity Classification

Issues are classified at gather time into four severity tiers:

| Severity | Meaning | Examples |
|----------|---------|---------|
| `critical` | Security vulnerabilities, data loss risks | SQL injection, missing auth checks |
| `major` | Bugs, missing error handling, logic errors | Unhandled exceptions, race conditions |
| `minor` | Code quality, inconsistencies | Missing types, naming conventions |
| `nitpick` | Style, minor suggestions | Formatting, comment wording |
