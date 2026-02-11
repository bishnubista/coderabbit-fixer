#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT_DIR}/tests/runtime-parity.sh"
"${ROOT_DIR}/tests/cr-gather-fixtures.sh"
"${ROOT_DIR}/tests/cr-state-tools.sh"
"${ROOT_DIR}/tests/runtime-dispatch.sh"
