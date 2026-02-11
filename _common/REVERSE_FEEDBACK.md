# Reverse Feedback Protocol

下流エージェント→上流エージェントの品質フィードバック。

---

## Format

```yaml
REVERSE_FEEDBACK:
  Source_Agent: "[報告元]"
  Target_Agent: "[問題のある出力を出したエージェント]"
  Feedback_Type: quality_issue | incorrect_output | incomplete_deliverable
  Priority: high | medium | low
  Issue:
    description: "[問題の具体的説明]"
    impact: "[これにより何が壊れるか]"
  Suggested_Action:
    action: "[修正すべき内容]"
    urgency: immediate | next_cycle | backlog
```

---

## Common Scenarios

| Source → Target | Scenario | Priority |
|-----------------|----------|----------|
| Radar → Builder | テストできないコード構造 | high |
| Sentinel → Builder | セキュリティ脆弱性 | high |
| Builder → Scout | 根本原因分析が不正確 | high |
| Judge → Builder | コード品質の問題 | medium |

---

## Priority Handling

| Priority | Response | Guardrail |
|----------|----------|-----------|
| high | 即時修正 | L2 Checkpoint |
| medium | 次サイクル | L1 Monitoring |
| low | バックログ | L1 Monitoring |

---

## Processing

```
RECEIVE → VALIDATE → ASSESS → ACT → NOTIFY → PREVENT
```
