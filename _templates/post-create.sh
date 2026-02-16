#!/bin/bash
set -euo pipefail

echo "=== Codespace Setup ==="

# Python venv + dependencies
if [ -f pyproject.toml ]; then
  python -m venv .venv
  source .venv/bin/activate
  pip install --upgrade pip
  pip install -e ".[dev]" 2>/dev/null || pip install -e "." 2>/dev/null || true
fi

# Node.js dependencies
if [ -f package.json ]; then
  npm install
fi

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# .env from secrets
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  [ -n "${ANTHROPIC_API_KEY:-}" ] && echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> .env
fi

echo "=== Setup Complete ==="
echo "Run 'claude' to start Claude Code"
