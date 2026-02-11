#!/usr/bin/env bash
set -euo pipefail

resolve_runtime_root() {
  local script_dir repo_root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "${script_dir}/.." && pwd)"

  if [[ -d "${repo_root}/runtime" ]]; then
    echo "${repo_root}/runtime"
    return 0
  fi

  if [[ -d "${HOME}/.local/share/coderabbit-fixer/runtime" ]]; then
    echo "${HOME}/.local/share/coderabbit-fixer/runtime"
    return 0
  fi

  return 1
}

resolve_default_runtime() {
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/coderabbit-fixer/runtime"

  if [[ -n "${CR_IMPL:-}" ]]; then
    echo "${CR_IMPL}"
    return 0
  fi

  if [[ -f "${config_file}" ]]; then
    tr -d '[:space:]' < "${config_file}"
    return 0
  fi

  echo "python"
}

resolve_runtime_target() {
  local runtime_root="$1"
  local runtime="$2"
  local command_name="$3"

  case "${runtime}" in
    python)
      if command -v python3 >/dev/null 2>&1 && [[ -x "${runtime_root}/python/${command_name}" ]]; then
        echo "${runtime_root}/python/${command_name}"
        return 0
      fi
      ;;
    bun)
      if command -v bun >/dev/null 2>&1 && [[ -x "${runtime_root}/bun/${command_name}" ]]; then
        echo "${runtime_root}/bun/${command_name}"
        return 0
      fi
      ;;
    bash)
      if [[ -x "${runtime_root}/bash/${command_name}" ]]; then
        echo "${runtime_root}/bash/${command_name}"
        return 0
      fi
      ;;
    *)
      echo "WARN: Unknown runtime '${runtime}'. Falling back." >&2
      ;;
  esac

  if [[ -x "${runtime_root}/bash/${command_name}" ]]; then
    echo "${runtime_root}/bash/${command_name}"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1 && [[ -x "${runtime_root}/python/${command_name}" ]]; then
    echo "${runtime_root}/python/${command_name}"
    return 0
  fi

  if command -v bun >/dev/null 2>&1 && [[ -x "${runtime_root}/bun/${command_name}" ]]; then
    echo "${runtime_root}/bun/${command_name}"
    return 0
  fi

  return 1
}

cr_dispatch_main() {
  local command_name="$1"
  shift || true

  local runtime_root runtime target

  runtime_root="$(resolve_runtime_root)" || {
    echo "ERROR: Could not locate runtime files." >&2
    exit 1
  }

  runtime="$(resolve_default_runtime)"
  target="$(resolve_runtime_target "${runtime_root}" "${runtime}" "${command_name}")" || {
    echo "ERROR: No implementation found for '${command_name}'." >&2
    echo "Tried runtime '${runtime}' under '${runtime_root}'." >&2
    exit 1
  }

  exec "${target}" "$@"
}
