#!/bin/bash
set -euo pipefail

# Agent Orchestrator Installer
# Usage:
#   curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash
#   curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash -s -- nexus rally builder radar
#   ./install.sh                    # Install all agents
#   ./install.sh nexus rally builder # Install specific agents

REPO="luna-matching/agent-orchestrator"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

# All available agents
ALL_AGENTS="ceo nexus rally sherpa builder scout radar sentinel guardian judge zen forge artisan architect analyst"

# Default: install all if no args
AGENTS="${@:-$ALL_AGENTS}"

echo "=== Agent Orchestrator Installer ==="
echo "Source: github.com/${REPO}"
echo "Agents: ${AGENTS}"
echo ""

# Create directories
mkdir -p .claude/agents
mkdir -p .agents

echo "[1/5] Downloading agent definitions..."
for agent in $AGENTS; do
  echo "  -> ${agent}"
  curl -sfL "${BASE_URL}/agents/${agent}/SKILL.md" -o ".claude/agents/${agent}.md" 2>/dev/null || {
    echo "  [WARN] Agent '${agent}' not found, skipping"
    continue
  }
done

echo "[2/5] Downloading framework protocol..."
curl -sfL "${BASE_URL}/_templates/CLAUDE_PROJECT.md" -o ".claude/agents/_framework.md" 2>/dev/null || true

echo "[3/5] Setting up shared knowledge..."
if [ ! -f ".agents/PROJECT.md" ]; then
  curl -sfL "${BASE_URL}/_templates/PROJECT.md" -o ".agents/PROJECT.md" 2>/dev/null || true
  echo "  -> Created .agents/PROJECT.md"
else
  echo "  -> .agents/PROJECT.md already exists, skipping"
fi

echo "[4/5] Setting up business context..."
if [ ! -f ".agents/LUNA_CONTEXT.md" ]; then
  curl -sfL "${BASE_URL}/_templates/LUNA_CONTEXT.md" -o ".agents/LUNA_CONTEXT.md" 2>/dev/null || true
  echo "  -> Created .agents/LUNA_CONTEXT.md (customize for your project)"
else
  echo "  -> .agents/LUNA_CONTEXT.md already exists, skipping"
fi

echo "[5/5] Checking CLAUDE.md..."
if [ -f "CLAUDE.md" ]; then
  if grep -q "Agent Orchestrator" CLAUDE.md 2>/dev/null; then
    echo "  -> CLAUDE.md already has framework reference, skipping"
  else
    cat >> CLAUDE.md << 'FRAMEWORK_EOF'

## Agent Team Framework

This project uses [Agent Orchestrator](https://github.com/luna-matching/agent-orchestrator).
Agent definitions are in `.claude/agents/`. Framework protocol is in `.claude/agents/_framework.md`.

### Key Rules
- Hub-spoke pattern: all communication through orchestrator (Nexus/Rally)
- CEO handles business decisions before technical execution
- File ownership is law in parallel execution
- Guardrails L1-L4 for safe autonomous execution
- All outputs in Japanese
- Conventional Commits, no agent names in commits/PRs

### Business Context
- `.agents/LUNA_CONTEXT.md` - Business context for CEO decisions
- `.agents/PROJECT.md` - Shared knowledge across agents
FRAMEWORK_EOF
    echo "  -> Appended framework reference to CLAUDE.md"
  fi
else
  cat > CLAUDE.md << 'FRAMEWORK_EOF'
# Project Instructions

## Agent Team Framework

This project uses [Agent Orchestrator](https://github.com/luna-matching/agent-orchestrator).
Agent definitions are in `.claude/agents/`. Framework protocol is in `.claude/agents/_framework.md`.

### Key Rules
- Hub-spoke pattern: all communication through orchestrator (Nexus/Rally)
- CEO handles business decisions before technical execution
- File ownership is law in parallel execution
- Guardrails L1-L4 for safe autonomous execution
- All outputs in Japanese
- Conventional Commits, no agent names in commits/PRs

### Business Context
- `.agents/LUNA_CONTEXT.md` - Business context for CEO decisions
- `.agents/PROJECT.md` - Shared knowledge across agents
FRAMEWORK_EOF
  echo "  -> Created CLAUDE.md with framework reference"
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Installed agents:"
for f in .claude/agents/*.md; do
  [ -f "$f" ] && echo "  - $(basename "$f" .md)"
done
echo ""
echo "Next steps:"
echo "  1. Customize .agents/LUNA_CONTEXT.md for your project"
echo "  2. Review .agents/PROJECT.md for shared knowledge"
echo "  3. Customize CLAUDE.md for your project"
echo ""
echo "Usage:"
echo "  /ceo この機能の優先度を判断して"
echo "  /nexus ログイン機能を実装したい"
echo "  /analyst ユーザー離脱率を分析して"
echo "  /rally フロントエンドとバックエンドを並列実装して"
