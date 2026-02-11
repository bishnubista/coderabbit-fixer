#!/usr/bin/env bash
#
# install.sh - Install Claude Code x CodeRabbit plugin
#
# Usage:
#   ./install.sh                       # Install all components (default runtime: python)
#   ./install.sh --runtime <python|bash|bun>
#   ./install.sh --uninstall # Remove all components
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="${HOME}/.local/bin"
COMMANDS_DIR="${HOME}/.claude/commands"
AGENTS_DIR="${HOME}/.claude/agents"
SHARE_DIR="${HOME}/.local/share/coderabbit-fixer"
RUNTIME_DIR="${SHARE_DIR}/runtime"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/coderabbit-fixer"
RUNTIME_CONFIG="${CONFIG_DIR}/runtime"

die() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  exit 1
}
usage() {
  cat <<'EOF'
Usage:
  ./install.sh
  ./install.sh --runtime <python|bash|bun>
  ./install.sh --uninstall
EOF
}

# Parse arguments
UNINSTALL=false
RUNTIME="python"
while [[ $# -gt 0 ]]; do
  case $1 in
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    --runtime)
      [[ $# -ge 2 ]] || die "--runtime requires one of: python | bash | bun"
      case "$2" in
        python|bash|bun) RUNTIME="$2" ;;
        *) die "Invalid runtime '$2'. Use: python | bash | bun" ;;
      esac
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

# ── Uninstall ──────────────────────────────────────────────────────────────
if [[ "$UNINSTALL" == "true" ]]; then
  echo -e "${CYAN}Uninstalling Claude Code x CodeRabbit plugin...${NC}"
  echo ""

  for tool in cr-gather cr-status cr-next cr-done cr-metrics _cr_dispatch.sh; do
    if [[ -f "$BIN_DIR/$tool" ]]; then
      rm -f "$BIN_DIR/$tool"
      echo -e "  ${RED}✗${NC} Removed $BIN_DIR/$tool"
    fi
  done

  for cmd in fix-coderabbit.md coderabbit-cli-review.md; do
    if [[ -f "$COMMANDS_DIR/$cmd" ]]; then
      rm -f "$COMMANDS_DIR/$cmd"
      echo -e "  ${RED}✗${NC} Removed $COMMANDS_DIR/$cmd"
    fi
  done

  for agent in coderabbit-pr-reviewer.md coderabbit-coordinator.md; do
    if [[ -f "$AGENTS_DIR/$agent" ]]; then
      rm -f "$AGENTS_DIR/$agent"
      echo -e "  ${RED}✗${NC} Removed $AGENTS_DIR/$agent"
    fi
  done

  if [[ -d "$SHARE_DIR" ]]; then
    rm -rf "$SHARE_DIR"
    echo -e "  ${RED}✗${NC} Removed $SHARE_DIR"
  fi

  if [[ -f "$RUNTIME_CONFIG" ]]; then
    rm -f "$RUNTIME_CONFIG"
    echo -e "  ${RED}✗${NC} Removed $RUNTIME_CONFIG"
  fi

  echo ""
  echo -e "${GREEN}Uninstalled successfully.${NC}"
  exit 0
fi

# ── Install ────────────────────────────────────────────────────────────────
echo -e "${CYAN}Installing Claude Code x CodeRabbit plugin...${NC}"
echo ""

# Check prerequisites
MISSING=""
command -v gh >/dev/null 2>&1 || MISSING="$MISSING gh"
command -v jq >/dev/null 2>&1 || MISSING="$MISSING jq"

if [[ -n "$MISSING" ]]; then
  echo -e "${YELLOW}Warning: Missing prerequisites:${MISSING}${NC}"
  echo "  Install with: brew install${MISSING}"
  echo ""
fi

if [[ "$RUNTIME" == "python" ]] && ! command -v python3 >/dev/null 2>&1; then
  echo -e "${YELLOW}Warning: python3 not found. Runtime may fall back to bash at execution time.${NC}"
fi
if [[ "$RUNTIME" == "bun" ]] && ! command -v bun >/dev/null 2>&1; then
  echo -e "${YELLOW}Warning: bun not found. Runtime may fall back to bash at execution time.${NC}"
fi

# Create directories
mkdir -p "$BIN_DIR" "$COMMANDS_DIR" "$AGENTS_DIR" "$SHARE_DIR" "$CONFIG_DIR"

# Counters
NEW=0
UPDATED=0
CURRENT=0

# ── Helper: install a file with status reporting ──────────────────────────
# Usage: install_file <source> <dest> [--chmod]
install_file() {
  local src="$1" dest="$2" do_chmod="${3:-}"
  local name
  name=$(basename "$dest")

  if [[ ! -f "$src" ]]; then
    echo -e "  ${RED}✗${NC} $name not found in source"
    return
  fi

  if [[ ! -f "$dest" ]]; then
    # New install
    cp "$src" "$dest"
    [[ "$do_chmod" == "--chmod" ]] && chmod +x "$dest"
    echo -e "  ${GREEN}✓${NC} $dest ${GREEN}(new)${NC}"
    NEW=$((NEW + 1))
  elif diff -q "$src" "$dest" >/dev/null 2>&1; then
    # Already up to date
    echo -e "  ${DIM}──${NC} $dest ${DIM}(up to date)${NC}"
    CURRENT=$((CURRENT + 1))
  else
    # Changed — backup and update
    cp "$dest" "$dest.bak"
    cp "$src" "$dest"
    [[ "$do_chmod" == "--chmod" ]] && chmod +x "$dest"
    echo -e "  ${YELLOW}↑${NC} $dest ${YELLOW}(updated)${NC}"
    UPDATED=$((UPDATED + 1))
  fi
}

# Install CLI tools
for tool in cr-gather cr-status cr-next cr-done cr-metrics; do
  install_file "$SCRIPT_DIR/bin/$tool" "$BIN_DIR/$tool" --chmod
done
install_file "$SCRIPT_DIR/bin/_cr_dispatch.sh" "$BIN_DIR/_cr_dispatch.sh" --chmod

# Install runtime files
if [[ -d "$SCRIPT_DIR/runtime" ]]; then
  rm -rf "$RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR"
  cp -R "$SCRIPT_DIR/runtime/." "$RUNTIME_DIR/"
  find "$RUNTIME_DIR" -type f -exec chmod +x {} \;
  echo -e "  ${GREEN}✓${NC} $RUNTIME_DIR ${GREEN}(synced)${NC}"
else
  die "runtime directory missing in source"
fi

# Install slash commands
for cmd in fix-coderabbit.md coderabbit-cli-review.md; do
  install_file "$SCRIPT_DIR/commands/$cmd" "$COMMANDS_DIR/$cmd"
done

# Install agents
for agent in coderabbit-pr-reviewer.md coderabbit-coordinator.md; do
  install_file "$SCRIPT_DIR/agents/$agent" "$AGENTS_DIR/$agent"
done

# Persist selected runtime
echo "$RUNTIME" > "$RUNTIME_CONFIG"
echo -e "  ${GREEN}✓${NC} Runtime set to '${RUNTIME}' (${RUNTIME_CONFIG})"

# Summary
TOTAL=$((NEW + UPDATED + CURRENT))
echo ""
if [[ "$NEW" -eq 0 && "$UPDATED" -eq 0 ]]; then
  echo -e "${GREEN}All $TOTAL components up to date.${NC}"
elif [[ "$NEW" -gt 0 && "$UPDATED" -eq 0 ]]; then
  echo -e "${GREEN}Installed $NEW new component(s). $CURRENT already current.${NC}"
elif [[ "$NEW" -eq 0 && "$UPDATED" -gt 0 ]]; then
  echo -e "${GREEN}Updated $UPDATED component(s). $CURRENT already current.${NC}"
else
  echo -e "${GREEN}Installed $NEW new, updated $UPDATED. $CURRENT already current.${NC}"
fi
echo ""

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "$BIN_DIR"; then
  echo -e "${YELLOW}Note: $BIN_DIR is not in your PATH.${NC}"
  echo "  Add this to your shell profile (~/.zshrc or ~/.bashrc):"
  echo ""
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
fi

echo "Usage:"
echo "  /fix-coderabbit              # Fix all CodeRabbit issues on current PR"
echo "  /fix-coderabbit --quick      # Critical + major only"
echo "  /fix-coderabbit --bg         # Run in background"
echo "  /coderabbit-review           # Local review before pushing"
echo ""
echo "CLI tools:"
echo "  cr-gather <PR>   cr-status   cr-next   cr-done <id>   cr-metrics"
echo ""
echo "Runtime selection:"
echo "  Default: $RUNTIME"
echo "  Override once: CR_IMPL=bash cr-next"
echo "  Reinstall with runtime: ./install.sh --runtime bun"
