#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMANDS=(cr-gather cr-status cr-next cr-done cr-metrics)
RUNTIMES=(bash python bun)

for runtime in "${RUNTIMES[@]}"; do
  for command in "${COMMANDS[@]}"; do
    target="${ROOT_DIR}/runtime/${runtime}/${command}"
    if [[ ! -f "${target}" ]]; then
      echo "FAIL: Missing runtime command: ${target}" >&2
      exit 1
    fi
    if [[ ! -x "${target}" ]]; then
      echo "FAIL: Runtime command is not executable: ${target}" >&2
      exit 1
    fi
  done
done

echo "Runtime parity checks passed."
