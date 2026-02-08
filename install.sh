#!/usr/bin/env bash
#
# install.sh - Install Claude Code x CodeRabbit plugin
#
# Usage:
#   ./install.sh             # Install all components
#   ./install.sh --uninstall # Remove all components
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="${HOME}/.local/bin"
COMMANDS_DIR="${HOME}/.claude/commands"
AGENTS_DIR="${HOME}/.claude/agents"

# ── Uninstall ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  echo -e "${CYAN}Uninstalling Claude Code x CodeRabbit plugin...${NC}"
  echo ""

  for tool in cr-gather cr-status cr-next cr-done cr-metrics; do
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

# Create directories
mkdir -p "$BIN_DIR" "$COMMANDS_DIR" "$AGENTS_DIR"

# Install CLI tools
INSTALLED=0
for tool in cr-gather cr-status cr-next cr-done cr-metrics; do
  if [[ -f "$SCRIPT_DIR/bin/$tool" ]]; then
    cp "$SCRIPT_DIR/bin/$tool" "$BIN_DIR/$tool"
    chmod +x "$BIN_DIR/$tool"
    echo -e "  ${GREEN}✓${NC} $BIN_DIR/$tool"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} bin/$tool not found"
  fi
done

# Install slash commands
for cmd in fix-coderabbit.md coderabbit-cli-review.md; do
  if [[ -f "$SCRIPT_DIR/commands/$cmd" ]]; then
    # Backup existing if different
    if [[ -f "$COMMANDS_DIR/$cmd" ]] && ! diff -q "$SCRIPT_DIR/commands/$cmd" "$COMMANDS_DIR/$cmd" >/dev/null 2>&1; then
      cp "$COMMANDS_DIR/$cmd" "$COMMANDS_DIR/$cmd.bak"
      echo -e "  ${YELLOW}↳${NC} Backed up existing $cmd → $cmd.bak"
    fi
    cp "$SCRIPT_DIR/commands/$cmd" "$COMMANDS_DIR/$cmd"
    echo -e "  ${GREEN}✓${NC} $COMMANDS_DIR/$cmd"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} commands/$cmd not found"
  fi
done

# Install agents
for agent in coderabbit-pr-reviewer.md coderabbit-coordinator.md; do
  if [[ -f "$SCRIPT_DIR/agents/$agent" ]]; then
    if [[ -f "$AGENTS_DIR/$agent" ]] && ! diff -q "$SCRIPT_DIR/agents/$agent" "$AGENTS_DIR/$agent" >/dev/null 2>&1; then
      cp "$AGENTS_DIR/$agent" "$AGENTS_DIR/$agent.bak"
      echo -e "  ${YELLOW}↳${NC} Backed up existing $agent → $agent.bak"
    fi
    cp "$SCRIPT_DIR/agents/$agent" "$AGENTS_DIR/$agent"
    echo -e "  ${GREEN}✓${NC} $AGENTS_DIR/$agent"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} agents/$agent not found"
  fi
done

echo ""
echo -e "${GREEN}Installed $INSTALLED components successfully.${NC}"
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
