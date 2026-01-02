#!/bin/bash
# Install Flow skills and prompts into Codex CLI (~/.codex)
#
# Usage: ./scripts/install-codex.sh
#
# What gets installed:
#   - Skills:  plugins/flow/skills/*  → ~/.codex/skills/
#   - Prompts: plugins/flow/commands/flow/*.md → ~/.codex/prompts/
#
# Note: Flow's subagents (parallel research) won't run in Codex since it
# doesn't support Claude Code's Task tool. The core plan/work flow still
# works well without them.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CODEX_DIR="$HOME/.codex"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Installing Flow to Codex CLI..."
echo

# Check codex dir exists
if [ ! -d "$CODEX_DIR" ]; then
    echo -e "${RED}Error: ~/.codex not found. Is Codex CLI installed?${NC}"
    exit 1
fi

# Create dirs if needed
mkdir -p "$CODEX_DIR/skills"
mkdir -p "$CODEX_DIR/prompts"

# Install skills
echo "Installing skills..."
SKILLS=(flow-plan flow-work flow-plan-review flow-impl-review rp-explorer worktree-kit)
for skill in "${SKILLS[@]}"; do
    if [ -d "$REPO_ROOT/plugins/flow/skills/$skill" ]; then
        rm -rf "$CODEX_DIR/skills/$skill"
        cp -r "$REPO_ROOT/plugins/flow/skills/$skill" "$CODEX_DIR/skills/"
        echo -e "  ${GREEN}✓${NC} $skill"
    fi
done

# Install prompts (commands)
echo "Installing prompts..."
for cmd in "$REPO_ROOT/plugins/flow/commands/flow/"*.md; do
    if [ -f "$cmd" ]; then
        name=$(basename "$cmd")
        cp "$cmd" "$CODEX_DIR/prompts/$name"
        echo -e "  ${GREEN}✓${NC} $name"
    fi
done

echo
echo -e "${GREEN}Done!${NC} Flow installed to ~/.codex"
echo
echo -e "${YELLOW}Note:${NC} Subagents (parallel research) won't run in Codex."
echo "The core /flow:plan and /flow:work commands still work well."
