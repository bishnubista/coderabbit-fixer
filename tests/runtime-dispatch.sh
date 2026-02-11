#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CR_NEXT="${ROOT_DIR}/bin/cr-next"
CR_DONE="${ROOT_DIR}/bin/cr-done"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

seed_state() {
  cat > "${TMP_DIR}/.coderabbit-review.json" <<'JSON'
{
  "issues": [
    {"id":"a","status":"pending","severity":"major","file":"src/a.ts","line":1,"body":"A","thread_id":null},
    {"id":"b","status":"pending","severity":"minor","file":"src/b.ts","line":1,"body":"B","thread_id":null}
  ],
  "summary": {"fixed":0,"pending":2}
}
JSON
}

run_case() {
  local label="$1"
  local expected_ids="$2"
  local got_ids
  shift
  shift
  (
    cd "${TMP_DIR}"
    "$@" >"${TMP_DIR}/out.txt"
  )
  grep -q "# CodeRabbit Issues" "${TMP_DIR}/out.txt" || {
    echo "FAIL: ${label} did not produce expected output" >&2
    exit 1
  }
  got_ids=$(jq -c '.session.last_shown_ids' "${TMP_DIR}/.coderabbit-review.json")
  if [[ "${got_ids}" != "${expected_ids}" ]]; then
    echo "FAIL: ${label} session IDs mismatch (got=${got_ids}, want=${expected_ids})" >&2
    exit 1
  fi
}

seed_done_state() {
  cat > "${TMP_DIR}/.coderabbit-review.json" <<'JSON'
{
  "issues": [
    {"id":"a","status":"pending","severity":"major","file":"src/a.ts","line":1,"body":"A","thread_id":null},
    {"id":"b","status":"pending","severity":"minor","file":"src/b.ts","line":1,"body":"B","thread_id":null}
  ],
  "summary": {"fixed":0,"pending":2},
  "session": {"last_shown_ids": ["b", "a"]}
}
JSON
}

run_done_case() {
  local label="$1"
  shift
  (
    cd "${TMP_DIR}"
    "$@" >"${TMP_DIR}/done_out.txt"
  )
  grep -q "Progress: 1/2 fixed (1 remaining)" "${TMP_DIR}/done_out.txt" || {
    echo "FAIL: ${label} progress output mismatch" >&2
    exit 1
  }
  local status_a status_b summary_fixed summary_pending
  status_a=$(jq -r '.issues[] | select(.id == "a") | .status' "${TMP_DIR}/.coderabbit-review.json")
  status_b=$(jq -r '.issues[] | select(.id == "b") | .status' "${TMP_DIR}/.coderabbit-review.json")
  summary_fixed=$(jq -r '.summary.fixed' "${TMP_DIR}/.coderabbit-review.json")
  summary_pending=$(jq -r '.summary.pending' "${TMP_DIR}/.coderabbit-review.json")

  [[ "${status_a}" == "pending" ]] || { echo "FAIL: ${label} expected a=pending" >&2; exit 1; }
  [[ "${status_b}" == "fixed" ]] || { echo "FAIL: ${label} expected b=fixed" >&2; exit 1; }
  [[ "${summary_fixed}" == "1" ]] || { echo "FAIL: ${label} expected summary.fixed=1" >&2; exit 1; }
  [[ "${summary_pending}" == "1" ]] || { echo "FAIL: ${label} expected summary.pending=1" >&2; exit 1; }
}

echo "Test: runtime dispatch with bash"
seed_state
run_case "bash runtime" '["a"]' env CR_IMPL=bash "${CR_NEXT}" 1

echo "Test: runtime dispatch with python"
seed_state
run_case "python runtime" '["a"]' env CR_IMPL=python "${CR_NEXT}" 1

if command -v bun >/dev/null 2>&1; then
  echo "Test: runtime dispatch with bun"
  seed_state
  run_case "bun runtime" '["a"]' env CR_IMPL=bun "${CR_NEXT}" 1
else
  echo "Test: runtime dispatch with bun (skipped: bun not installed)"
fi

echo "Test: runtime quick mode parity"
seed_state
run_case "quick mode python" '["a"]' env CR_IMPL=python "${CR_NEXT}" --quick --all
if command -v bun >/dev/null 2>&1; then
  seed_state
  run_case "quick mode bun" '["a"]' env CR_IMPL=bun "${CR_NEXT}" --quick --all
fi

echo "Test: unknown runtime falls back"
seed_state
run_case "unknown runtime fallback" '["a"]' env CR_IMPL=does-not-exist "${CR_NEXT}" 1

echo "Test: cr-done runtime dispatch with bash"
seed_done_state
run_done_case "bash cr-done runtime" env CR_IMPL=bash "${CR_DONE}" --last 1 --no-resolve

echo "Test: cr-done runtime dispatch with python"
seed_done_state
run_done_case "python cr-done runtime" env CR_IMPL=python "${CR_DONE}" --last 1 --no-resolve

if command -v bun >/dev/null 2>&1; then
  echo "Test: cr-done runtime dispatch with bun"
  seed_done_state
  run_done_case "bun cr-done runtime" env CR_IMPL=bun "${CR_DONE}" --last 1 --no-resolve
fi

echo "Test: unknown runtime fallback for cr-done"
seed_done_state
run_done_case "unknown runtime fallback for cr-done" env CR_IMPL=does-not-exist "${CR_DONE}" --last 1 --no-resolve

echo "Runtime dispatch tests passed."
