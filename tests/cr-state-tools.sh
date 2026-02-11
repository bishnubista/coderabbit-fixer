#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CR_NEXT="${ROOT_DIR}/bin/cr-next"
CR_DONE="${ROOT_DIR}/bin/cr-done"
CR_STATUS="${ROOT_DIR}/bin/cr-status"
CR_METRICS="${ROOT_DIR}/bin/cr-metrics"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  local msg="$3"
  if [[ "$got" != "$want" ]]; then
    fail "${msg} (got='${got}', want='${want}')"
  fi
}

write_state() {
  local json="$1"
  cat > "${TMP_DIR}/.coderabbit-review.json" <<<"${json}"
}

run_in_tmp() {
  (
    cd "${TMP_DIR}"
    "$@"
  )
}

expect_failure() {
  if run_in_tmp "$@" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

echo "Test: cr-next records last shown IDs from the current batch"
write_state '{
  "issues": [
    {"id":"a","status":"pending","severity":"major","file":"src/a.ts","line":1,"body":"A","thread_id":null},
    {"id":"b","status":"pending","severity":"major","file":"src/b.ts","line":1,"body":"B","thread_id":null},
    {"id":"c","status":"pending","severity":"minor","file":"src/c.ts","line":1,"body":"C","thread_id":null}
  ],
  "summary": {"fixed":0,"pending":3}
}'
run_in_tmp "${CR_NEXT}" 2 >/dev/null
LAST_IDS=$(jq -c '.session.last_shown_ids' "${TMP_DIR}/.coderabbit-review.json")
assert_eq "${LAST_IDS}" '["a","b"]' "cr-next should record IDs shown in batch order"

echo "Test: cr-done --last prefers latest cr-next batch IDs"
write_state '{
  "issues": [
    {"id":"a","status":"pending","severity":"major","file":"src/a.ts","line":1,"body":"A","thread_id":null},
    {"id":"b","status":"pending","severity":"major","file":"src/b.ts","line":1,"body":"B","thread_id":null},
    {"id":"c","status":"pending","severity":"minor","file":"src/c.ts","line":1,"body":"C","thread_id":null}
  ],
  "summary": {"fixed":0,"pending":3},
  "session": {"last_shown_ids":["b","c"]}
}'
run_in_tmp "${CR_DONE}" --last 1 --no-resolve >/dev/null
STATUS_A=$(jq -r '.issues[] | select(.id == "a") | .status' "${TMP_DIR}/.coderabbit-review.json")
STATUS_B=$(jq -r '.issues[] | select(.id == "b") | .status' "${TMP_DIR}/.coderabbit-review.json")
assert_eq "${STATUS_A}" "pending" "cr-done --last should not mark first pending when session IDs exist"
assert_eq "${STATUS_B}" "fixed" "cr-done --last should mark first latest-shown ID"

echo "Test: cr-done --last falls back for legacy state without session IDs"
write_state '{
  "issues": [
    {"id":"x","status":"pending","severity":"major","file":"src/x.ts","line":1,"body":"X","thread_id":null},
    {"id":"y","status":"pending","severity":"minor","file":"src/y.ts","line":1,"body":"Y","thread_id":null}
  ],
  "summary": {"fixed":0,"pending":2}
}'
run_in_tmp "${CR_DONE}" --last 1 --no-resolve >/dev/null
STATUS_X=$(jq -r '.issues[] | select(.id == "x") | .status' "${TMP_DIR}/.coderabbit-review.json")
assert_eq "${STATUS_X}" "fixed" "legacy fallback should mark first pending ID"

echo "Test: unknown flag handling across tools"
write_state '{
  "issues": [
    {"id":"x","status":"pending","severity":"major","file":"src/x.ts","line":1,"body":"X","thread_id":null}
  ],
  "summary": {"fixed":0,"pending":1}
}'
if ! expect_failure "${CR_NEXT}" --unknown; then
  fail "cr-next should fail on unknown flag"
fi
if ! expect_failure "${CR_STATUS}" --unknown; then
  fail "cr-status should fail on unknown flag"
fi
if ! expect_failure "${CR_DONE}" --unknown; then
  fail "cr-done should fail on unknown flag"
fi
if ! expect_failure "${CR_METRICS}" show --unknown; then
  fail "cr-metrics show should fail on unknown flag"
fi

echo "All state-tool tests passed."
