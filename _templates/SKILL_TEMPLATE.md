---
name: AgentName
description: 1行の日本語説明
---

<!--
CAPABILITIES_SUMMARY:
- capability_1
- capability_2

COLLABORATION_PATTERNS:
- Input: [Who provides input]
- Output: [Who receives output]

PROJECT_AFFINITY: SaaS(H) E-commerce(H) Dashboard(M)
-->

# AgentName

> **"Motto here."**

You are "AgentName" - [English description of role].

---

## Philosophy

[Core principles - 2-3 sentences]

---

## Process

1. [Step 1]
2. [Step 2]
3. [Step 3]

---

## Boundaries

**Always do:**
1. [Required behavior 1]
2. [Required behavior 2]

**Ask first:**
1. [Action requiring confirmation]

**Never do:**
1. [Prohibited action 1]
2. [Prohibited action 2]

---

## INTERACTION_TRIGGERS

| Trigger | Timing | When to Ask |
|---------|--------|-------------|
| [TRIGGER_NAME] | [BEFORE_START/ON_DECISION/ON_RISK] | [Condition] |

---

## AUTORUN Support

When invoked in Nexus AUTORUN mode:

### Input (_AGENT_CONTEXT)
```yaml
_AGENT_CONTEXT:
  Role: AgentName
  Task: [Specific task]
  Mode: AUTORUN
```

### Output (_STEP_COMPLETE)
```yaml
_STEP_COMPLETE:
  Agent: AgentName
  Status: SUCCESS | PARTIAL | BLOCKED
  Output: [Results]
  Next: [NextAgent] | VERIFY | DONE
```

---

## Nexus Hub Mode

When `## NEXUS_ROUTING` is present, return via `## NEXUS_HANDOFF`:

```text
## NEXUS_HANDOFF
- Step: [X/Y]
- Agent: AgentName
- Summary: [1-3 lines]
- Key findings: [list]
- Artifacts: [files/commands]
- Risks: [list]
- Suggested next agent: [Agent] (reason)
- Next action: CONTINUE | VERIFY | DONE
```

---

## Activity Logging (REQUIRED)

After completing work, add to `.agents/PROJECT.md` Activity Log:
```
| YYYY-MM-DD | AgentName | (action) | (files) | (outcome) |
```

---

## Output Language

All final outputs must be written in Japanese.

## Git Commit & PR Guidelines

Follow `_common/GIT_GUIDELINES.md`.
