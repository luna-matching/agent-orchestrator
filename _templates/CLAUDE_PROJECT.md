# Agent Orchestrator - Framework Protocol

> このファイルは `.claude/agents/_framework.md` としてプロジェクトに配置される。
> 全エージェントがこのプロトコルに従って動作する。

---

## Architecture

```
User Request
     |
     v
  [Nexus] ---- 単一セッションオーケストレーター（ロールシミュレーション）
     |
     +---> Sequential: Agent1 → Agent2 → Agent3
     |
     +---> Parallel: Rally → TeamCreate → Teammates（実セッション並列）
```

### Core Rules

1. **Hub-spoke** - 全通信はオーケストレーター（Nexus/Rally）経由。直接Agent-to-Agent通信は禁止
2. **Minimum viable chain** - 必要最小限のエージェントで構成
3. **File ownership is law** - 並列実行時、各ファイルのオーナーは1つだけ
4. **Fail fast, recover smart** - ガードレール L1-L4 で早期検出、可能なら自動回復
5. **Context is precious** - `.agents/PROJECT.md` でエージェント間の知識を共有

---

## Execution Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| AUTORUN_FULL | Default | 全自動実行（ガードレールのみ） |
| AUTORUN | `## NEXUS_AUTORUN` | SIMPLE自動、COMPLEX→Guided |
| GUIDED | `## NEXUS_GUIDED` | 判断ポイントで確認 |
| INTERACTIVE | `## NEXUS_INTERACTIVE` | 各ステップで確認 |

---

## Chain Templates

| タスク | チェーン |
|--------|---------|
| バグ修正(簡単) | Scout → Builder → Radar |
| バグ修正(複雑) | Scout → Sherpa → Builder → Radar → Sentinel |
| 機能開発(小) | Builder → Radar |
| 機能開発(中) | Sherpa → Forge → Builder → Radar |
| 機能開発(大) | Sherpa → Rally(Builder + Artisan + Radar) |
| リファクタリング | Zen → Radar |
| セキュリティ監査 | Sentinel → Builder → Radar |
| PR準備 | Guardian → Judge |

---

## Guardrail Levels

| Level | Trigger | Action |
|-------|---------|--------|
| L1 | lint_warning | ログのみ、続行 |
| L2 | test_failure <20% | 自動修正試行（最大3回） |
| L3 | test_failure >50% | ロールバック + 再分解 |
| L4 | critical_security | 即時停止 |

### Escalation

```
L1 → 改善なし → L2 → 自動回復成功 → CONTINUE
                    → 回復失敗 → L3 → 解決 → CONTINUE
                                    → 重大 → L4 → ROLLBACK + STOP
```

---

## Parallel Execution (Rally)

### File Ownership

```yaml
ownership_map:
  teammate_a:
    exclusive_write: [src/features/auth/**]
    shared_read: [src/types/**]
  teammate_b:
    exclusive_write: [src/features/profile/**]
    shared_read: [src/types/**]
```

- `exclusive_write`: そのチームメイトのみ書き込み可
- `shared_read`: 読み取り専用（全員）
- オーナーシップの重複は禁止

### Limits

| Metric | Limit |
|--------|-------|
| 最大ブランチ数 | 4 |
| ブランチあたり最大ステップ | 5 |
| 合計並列ステップ | 15 |

---

## Complexity Assessment

| 指標 | SIMPLE | COMPLEX |
|------|--------|---------|
| 推定ステップ | 1-2 | 3+ |
| 影響ファイル | 1-3 | 4+ |
| セキュリティ関連 | No | Yes |
| 破壊的変更 | No | Yes |

---

## Git Commit & PR

### Commit Format (Conventional Commits)

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`, `security`

### Rules

- エージェント名をコミット・PRに含めない
- 50文字以内、命令形
- Body は "why" を説明

### Branch Naming

```
<type>/<short-description>
```

---

## Reverse Feedback

下流→上流の品質フィードバック:

```yaml
REVERSE_FEEDBACK:
  Source_Agent: "[報告元]"
  Target_Agent: "[問題元]"
  Feedback_Type: quality_issue | incorrect_output | incomplete_deliverable
  Priority: high | medium | low
  Issue:
    description: "[問題]"
    impact: "[影響]"
```

| Priority | Response |
|----------|----------|
| high | 即時修正 |
| medium | 次サイクル |
| low | バックログ |

---

## Shared Knowledge

`.agents/PROJECT.md` に以下を蓄積（全エージェント必須更新）:

- Architecture Decisions
- Domain Glossary
- Known Gotchas
- Activity Log

### Activity Log（必須）

作業完了後、必ず追記:

```
| YYYY-MM-DD | AgentName | (action) | (files) | (outcome) |
```

---

## AUTORUN Support

### Input Format

```yaml
_AGENT_CONTEXT:
  Role: AgentName
  Task: [タスク内容]
  Mode: AUTORUN
```

### Output Format

```yaml
_STEP_COMPLETE:
  Agent: AgentName
  Status: SUCCESS | PARTIAL | BLOCKED
  Output: [結果]
  Next: [NextAgent] | VERIFY | DONE
```

---

## Nexus Hub Mode Handoff

```text
## NEXUS_HANDOFF
- Step: [X/Y]
- Agent: AgentName
- Summary: [1-3行]
- Key findings: [list]
- Artifacts: [files/commands]
- Risks: [list]
- Suggested next agent: [Agent] (reason)
- Next action: CONTINUE | VERIFY | DONE
```

---

## Output Language

全ての出力は **日本語** で記述すること。
