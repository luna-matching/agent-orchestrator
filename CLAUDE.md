# Agent Orchestrator Framework

## Overview

This repository defines the standard framework for building AI agent teams with Claude Code.
All agent team designs MUST follow the architecture and patterns defined here.

**Origin**: Based on [simota/agent-skills](https://github.com/simota/agent-skills) design philosophy.

## Core Principles

1. **Hub-spoke, never direct** - All agent communication flows through the orchestrator (Nexus/Rally). No direct agent-to-agent handoffs.
2. **Minimum viable chain** - Use the fewest agents necessary. Don't over-orchestrate.
3. **File ownership is law** - In parallel execution, each file has exactly one owner. No exceptions.
4. **Fail fast, recover smart** - Detect issues early via guardrails (L1-L4). Auto-recover when possible.
5. **Context is precious** - Preserve and share context across agent handoffs via `.agents/PROJECT.md`.

## Architecture

```
User Request
     |
     v
  [Nexus] ---- Single-session orchestrator (role simulation)
     |
     +---> [Sherpa] ---- Task decomposition into atomic steps
     |
     +---> [Rally] ----- Multi-session parallel orchestrator
              |
              +---> [Teammate A] (general-purpose agent)
              +---> [Teammate B] (general-purpose agent)
              +---> [Teammate C] (general-purpose agent)
```

## When to Use Which

| Scenario | Agent |
|----------|-------|
| Sequential multi-step task | **Nexus** (simulates agent roles in single session) |
| Break large task into steps | **Sherpa** (decomposition only, no execution) |
| Parallel implementation work | **Rally** (spawns real Claude instances via TeamCreate/Task) |
| Single focused task | Direct agent invocation (`/Scout`, `/Builder`, etc.) |

## Agent Catalog

See `agents/` directory. Each agent has a `SKILL.md` defining:
- Role and philosophy
- Boundaries (Always do / Ask first / Never do)
- Interaction triggers
- AUTORUN support format
- Nexus hub mode handoff format

## Shared Knowledge

All agents share knowledge through `.agents/` in the target project:

| File | Purpose |
|------|---------|
| `PROJECT.md` | Shared knowledge + activity log (ALL agents update after work) |
| `{agent}.md` | Agent-specific learnings |

## Common Rules

- Changes under 50 lines per step
- Respect existing project patterns
- Run tests before and after changes
- Use Conventional Commits: `type(scope): description`
- Never include agent names in commits or PR titles
- All user-facing output in Japanese

## Guardrail Levels

| Level | Trigger | Action |
|-------|---------|--------|
| L1 | lint_warning | Log, continue |
| L2 | test_failure <20% | Auto-fix attempt |
| L3 | test_failure >50% | Rollback + re-decompose |
| L4 | critical_security | Abort immediately |

## Installation

```bash
# Clone into Claude Code skills directory
git clone https://github.com/luna-matching/agent-orchestrator.git ~/.claude/skills

# Or reference from any project's CLAUDE.md:
# See ~/.claude/skills/agent-orchestrator/ for agent team framework
```
