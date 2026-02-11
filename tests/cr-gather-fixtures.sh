#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CR_GATHER="${ROOT_DIR}/runtime/bash/cr-gather"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

FIXTURES_DIR="${TMP_DIR}/fixtures"
BIN_DIR="${TMP_DIR}/bin"
mkdir -p "${FIXTURES_DIR}" "${BIN_DIR}"

cat > "${FIXTURES_DIR}/graphql-page-1.json" <<'JSON'
{
  "data": {
    "repository": {
      "pullRequest": {
        "reviewThreads": {
          "pageInfo": {
            "hasNextPage": true,
            "endCursor": "CURSOR_PAGE_1"
          },
          "nodes": [
            {
              "id": "PRRT_thread_1",
              "isResolved": false,
              "path": "src/a.ts",
              "line": 10,
              "comments": {
                "nodes": [
                  {
                    "databaseId": 1001,
                    "author": { "login": "coderabbitai[bot]" },
                    "body": "Severity: Critical - add a null check.",
                    "url": "https://example.com/t/1001"
                  }
                ]
              }
            },
            {
              "id": "PRRT_thread_2",
              "isResolved": false,
              "path": "src/a.ts",
              "line": 15,
              "comments": {
                "nodes": [
                  {
                    "databaseId": 1002,
                    "author": { "login": "coderabbitai[bot]" },
                    "body": "Severity: Minor - simplify this branch.",
                    "url": "https://example.com/t/1002"
                  }
                ]
              }
            },
            {
              "id": "PRRT_thread_3",
              "isResolved": false,
              "path": "src/ignore.ts",
              "line": 5,
              "comments": {
                "nodes": [
                  {
                    "databaseId": 1003,
                    "author": { "login": "octocat" },
                    "body": "Not from CodeRabbit.",
                    "url": "https://example.com/t/1003"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }
}
JSON

cat > "${FIXTURES_DIR}/graphql-page-2.json" <<'JSON'
{
  "data": {
    "repository": {
      "pullRequest": {
        "reviewThreads": {
          "pageInfo": {
            "hasNextPage": false,
            "endCursor": null
          },
          "nodes": [
            {
              "id": "PRRT_thread_4",
              "isResolved": false,
              "path": "src/b.ts",
              "line": 20,
              "comments": {
                "nodes": [
                  {
                    "databaseId": 1004,
                    "author": { "login": "coderabbitai[bot]" },
                    "body": "Severity: High - this should be major.",
                    "url": "https://example.com/t/1004"
                  }
                ]
              }
            },
            {
              "id": "PRRT_thread_5",
              "isResolved": false,
              "path": "src/c.ts",
              "line": 30,
              "comments": {
                "nodes": [
                  {
                    "databaseId": 1005,
                    "author": { "login": "coderabbitai[bot]" },
                    "body": "Nitpick: improve naming.",
                    "url": "https://example.com/t/1005"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }
}
JSON

cat > "${FIXTURES_DIR}/summary-body.txt" <<'TXT'
- [ ] Context > Tighten error handling around retries
- [ ] Follow-up > Add explicit docs for runtime fallback
TXT

cat > "${FIXTURES_DIR}/reviews-body.txt" <<'TXT'
**src/review.ts**
Nitpick: prefer a clearer variable name in this block.
TXT

cat > "${BIN_DIR}/gh" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
  exit 0
fi

if [[ "${1:-}" == "repo" && "${2:-}" == "view" ]]; then
  echo "acme/repo"
  exit 0
fi

if [[ "${1:-}" == "pr" && "${2:-}" == "view" ]]; then
  echo "42"
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "graphql" ]]; then
  query=""
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f)
        shift
        if [[ "${1:-}" == query=* ]]; then
          query="${1#query=}"
        fi
        ;;
    esac
    shift || true
  done

  if [[ "${query}" == *'after: "CURSOR_PAGE_1"'* ]]; then
    cat "${GH_FIXTURES}/graphql-page-2.json"
  else
    cat "${GH_FIXTURES}/graphql-page-1.json"
  fi
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "repos/acme/repo/issues/42/comments" ]]; then
  cat "${GH_FIXTURES}/summary-body.txt"
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "repos/acme/repo/pulls/42/reviews" ]]; then
  cat "${GH_FIXTURES}/reviews-body.txt"
  exit 0
fi

echo "unexpected gh invocation: $*" >&2
exit 1
BASH
chmod +x "${BIN_DIR}/gh"

(
  cd "${TMP_DIR}"
  PATH="${BIN_DIR}:$PATH" GH_FIXTURES="${FIXTURES_DIR}" "${CR_GATHER}" 42 --repo acme/repo >/dev/null
)

STATE_FILE="${TMP_DIR}/.coderabbit-review.json"
[[ -f "${STATE_FILE}" ]] || { echo "FAIL: state file not created" >&2; exit 1; }

TOTAL=$(jq -r '.summary.total' "${STATE_FILE}")
CRITICAL=$(jq -r '.summary.critical' "${STATE_FILE}")
MAJOR=$(jq -r '.summary.major' "${STATE_FILE}")
MINOR=$(jq -r '.summary.minor' "${STATE_FILE}")
NITPICK=$(jq -r '.summary.nitpick' "${STATE_FILE}")
FILES=$(jq -r '.summary.files' "${STATE_FILE}")

[[ "${TOTAL}" == "7" ]] || { echo "FAIL: expected total=7 got ${TOTAL}" >&2; exit 1; }
[[ "${CRITICAL}" == "1" ]] || { echo "FAIL: expected critical=1 got ${CRITICAL}" >&2; exit 1; }
[[ "${MAJOR}" == "1" ]] || { echo "FAIL: expected major=1 got ${MAJOR}" >&2; exit 1; }
[[ "${MINOR}" == "3" ]] || { echo "FAIL: expected minor=3 got ${MINOR}" >&2; exit 1; }
[[ "${NITPICK}" == "2" ]] || { echo "FAIL: expected nitpick=2 got ${NITPICK}" >&2; exit 1; }
[[ "${FILES}" == "4" ]] || { echo "FAIL: expected files=4 got ${FILES}" >&2; exit 1; }

jq -e '.issues[] | select(.id == "thread-1004" and .severity == "major" and .file == "src/b.ts")' "${STATE_FILE}" >/dev/null \
  || { echo "FAIL: expected paginated major issue for thread-1004" >&2; exit 1; }

jq -e '.issues[] | select(.type == "finishing")' "${STATE_FILE}" >/dev/null \
  || { echo "FAIL: expected finishing issues to be parsed" >&2; exit 1; }

jq -e '.issues[] | select(.type == "nitpick" and .file == "src/review.ts")' "${STATE_FILE}" >/dev/null \
  || { echo "FAIL: expected nitpick issue from review body" >&2; exit 1; }

echo "cr-gather fixture tests passed."
