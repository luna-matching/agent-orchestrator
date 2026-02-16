#!/bin/bash
set -euo pipefail

# Agent Orchestrator Installer
# Usage:
#   curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash
#   curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash -s -- nexus rally builder radar
#   ./install.sh                    # Install all agents
#   ./install.sh nexus rally builder # Install specific agents
#   ./install.sh --with-mcp         # Install agents + setup MCP servers
#   ./install.sh --with-cloud       # Install agents + cloud execution scripts

REPO="luna-matching/agent-orchestrator"
BRANCH="main"

# All 68 agents (65 simota + 3 Luna originals: ceo, analyst, auditor)
ALL_AGENTS="analyst anvil architect arena artisan atlas auditor bard bolt bridge builder canon canvas ceo cipher compete director echo experiment flow forge gateway gear grove growth guardian harvest hone horizon judge launch lens magi morph muse navigator nexus palette polyglot probe pulse quill radar rally reel researcher retain rewind ripple scaffold schema scout scribe sentinel sherpa showcase spark specter stream sweep trace triage tuner vision voice voyager warden zen"

# Parse flags
WITH_MCP=false
WITH_CLOUD=false
AGENT_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --with-mcp) WITH_MCP=true ;;
    --with-cloud) WITH_CLOUD=true ;;
    *) AGENT_ARGS+=("$arg") ;;
  esac
done

# Default: install all if no agent args
AGENTS="${AGENT_ARGS[*]:-$ALL_AGENTS}"

echo "=== Agent Orchestrator Installer ==="
echo "Source: github.com/${REPO}"
echo ""

# Create directories
mkdir -p .claude/agents
mkdir -p .claude/commands
mkdir -p .agents

# Clone to temp directory for reliable file access
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Downloading agent definitions..."
git clone --depth 1 --branch "$BRANCH" "https://github.com/${REPO}.git" "$TMPDIR" 2>/dev/null

INSTALLED=0
SKIPPED=0

echo "[1/8] Installing agent definitions..."
for agent in $AGENTS; do
  if [ -d "$TMPDIR/agents/$agent" ]; then
    # Copy SKILL.md as flat file for Claude Code agent discovery
    cp "$TMPDIR/agents/$agent/SKILL.md" ".claude/agents/${agent}.md"
    # Copy references/ if they exist (for agents that need supplementary docs)
    if [ -d "$TMPDIR/agents/$agent/references" ]; then
      mkdir -p ".claude/agents/${agent}"
      cp -r "$TMPDIR/agents/$agent/references" ".claude/agents/${agent}/"
    fi
    INSTALLED=$((INSTALLED + 1))
    echo "  -> ${agent}"
  else
    echo "  [WARN] Agent '${agent}' not found, skipping"
    SKIPPED=$((SKIPPED + 1))
  fi
done

echo "[2/8] Installing custom commands..."
COMMANDS_INSTALLED=0
for cmd_file in "$TMPDIR"/commands/*.md; do
  if [ -f "$cmd_file" ]; then
    cp "$cmd_file" ".claude/commands/"
    cmd_name=$(basename "$cmd_file" .md)
    COMMANDS_INSTALLED=$((COMMANDS_INSTALLED + 1))
    echo "  -> ${cmd_name}"
  fi
done

echo "[3/8] Downloading framework protocol..."
cp "$TMPDIR/_templates/CLAUDE_PROJECT.md" ".claude/agents/_framework.md"

echo "[4/8] Setting up shared knowledge..."
if [ ! -f ".agents/PROJECT.md" ]; then
  cp "$TMPDIR/_templates/PROJECT.md" ".agents/PROJECT.md"
  echo "  -> Created .agents/PROJECT.md"
else
  echo "  -> .agents/PROJECT.md already exists, skipping"
fi

echo "[5/8] Setting up business context..."
if [ ! -f ".agents/LUNA_CONTEXT.md" ]; then
  cp "$TMPDIR/_templates/LUNA_CONTEXT.md" ".agents/LUNA_CONTEXT.md"
  echo "  -> Created .agents/LUNA_CONTEXT.md (customize for your project)"
else
  echo "  -> .agents/LUNA_CONTEXT.md already exists, skipping"
fi

echo "[6/8] Copying MCP scripts and templates..."
mkdir -p .claude/scripts
if [ -f "$TMPDIR/scripts/setup-mcp.sh" ]; then
  cp "$TMPDIR/scripts/setup-mcp.sh" ".claude/scripts/setup-mcp.sh"
  chmod +x ".claude/scripts/setup-mcp.sh"
  echo "  -> Copied scripts/setup-mcp.sh"
else
  echo "  [WARN] scripts/setup-mcp.sh not found in repo, skipping"
fi
if [ -f "$TMPDIR/_templates/mcp-settings.json" ]; then
  cp "$TMPDIR/_templates/mcp-settings.json" ".claude/mcp-settings.template.json"
  echo "  -> Copied mcp-settings.template.json"
else
  echo "  [WARN] _templates/mcp-settings.json not found in repo, skipping"
fi
# Cloud scripts (Codespaces)
if [ -d "$TMPDIR/scripts/cloud" ]; then
  mkdir -p .claude/scripts/cloud
  cp "$TMPDIR/scripts/cloud/codespace.sh" ".claude/scripts/cloud/codespace.sh"
  chmod +x ".claude/scripts/cloud/codespace.sh"
  cp "$TMPDIR/scripts/cloud/.env.example" ".claude/scripts/cloud/.env.example"
  echo "  -> Copied cloud execution scripts (Codespaces)"
fi

echo "[7/8] Checking CLAUDE.md..."
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
echo "  Installed: ${INSTALLED} agents"
echo "  Installed: ${COMMANDS_INSTALLED} custom commands"
[ "$SKIPPED" -gt 0 ] && echo "  Skipped: ${SKIPPED} agents"
echo ""
echo "Installed agents:"
for f in .claude/agents/*.md; do
  name=$(basename "$f" .md)
  [ "$name" != "_framework" ] && echo "  - $name"
done
echo ""
echo "Installed commands:"
for f in .claude/commands/*.md; do
  if [ -f "$f" ]; then
    name=$(basename "$f" .md)
    echo "  - /$name"
  fi
done
echo ""
echo "Next steps:"
echo "  1. Customize .agents/LUNA_CONTEXT.md for your project"
echo "  2. Review .agents/PROJECT.md for shared knowledge"
echo "  3. Customize CLAUDE.md for your project"
echo ""
echo "Usage (agents):"
echo "  /ceo この機能の優先度を判断して"
echo "  /nexus ログイン機能を実装したい"
echo "  /analyst ユーザー離脱率を分析して"
echo "  /rally フロントエンドとバックエンドを並列実装して"
echo ""
echo "Usage (commands):"
echo "  /superpowers 認証システムをリファクタリングして"
echo "  /frontend-design ダッシュボードのUIを設計して"
echo "  /code-simplifier 直近の変更をクリーンアップして"
echo "  /playground マークダウンエディタを作って"
echo "  /chrome このページのデータを収集して"
echo "  /pr-review #123"
echo ""
echo "MCP Integration:"
echo "  # Global MCP setup (recommended)"
echo "  bash scripts/setup-mcp.sh"
echo ""
echo "  # Project-specific PostgreSQL MCP"
echo "  claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres 'postgresql://user:pass@host:5432/db'"
echo ""
echo "Cloud Execution (Codespaces):"
echo "  # Setup"
echo "  cp .claude/scripts/cloud/.env.example .claude/scripts/cloud/.env"
echo "  # Usage:"
echo "  bash .claude/scripts/cloud/codespace.sh create --repo OWNER/REPO"
echo "  bash .claude/scripts/cloud/codespace.sh status"

echo ""
echo "[8/8] MCP setup..."
if [ "$WITH_MCP" = true ]; then
  if [ -f ".claude/scripts/setup-mcp.sh" ]; then
    echo "  -> Running MCP setup (--with-mcp flag detected)..."
    bash ".claude/scripts/setup-mcp.sh"
  else
    echo "  [WARN] .claude/scripts/setup-mcp.sh not found, skipping MCP setup"
  fi
else
  echo "  -> Skipped (use --with-mcp to auto-setup)"
fi
