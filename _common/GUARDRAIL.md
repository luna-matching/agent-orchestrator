# Guardrail Protocol

AUTORUN_FULL モードでの安全な自律実行のためのガードレールシステム。

---

## Guardrail Levels

| Level | Name | Action | Use Case |
|-------|------|--------|----------|
| L1 | MONITORING | ログのみ | lint警告、軽微な非推奨 |
| L2 | CHECKPOINT | 自動検証 | テスト失敗<20%、セキュリティ警告 |
| L3 | PAUSE | 自動回復 or 待機 | テスト失敗>50%、破壊的変更 |
| L4 | ABORT | 即時停止 | クリティカルセキュリティ、データ整合性リスク |

---

## Auto-Recovery

### L2 Recovery

| Trigger | Recovery | Max Attempts |
|---------|----------|--------------|
| test_failure_minor | Builder修正→再テスト | 3 |
| type_error | Builder型強化 | 2 |
| lint_error | auto-fix | 1 |

### L3 Recovery

| Trigger | Recovery | Max Attempts |
|---------|----------|--------------|
| test_failure_major | ロールバック + Sherpa再分解 | 2 |
| breaking_change | Atlas影響分析 + マイグレーション | 1 |
| build_failure | ロールバック + 修正 | 2 |

---

## Task Type Defaults

```yaml
FEATURE:
  default_level: L2
  post_checks: [tests_pass, build_success]

SECURITY:
  default_level: L2
  pre_checks: [sentinel_scan]

REFACTOR:
  default_level: L2
  post_checks: [tests_unchanged, no_behavior_change]

INCIDENT:
  default_level: L3
  post_checks: [service_restored, no_regression]
```

---

## Escalation Path

```
L1 (Log) → issue persists → L2 (Checkpoint)
  → auto_recovery_success → CONTINUE
  → recovery_failed → L3 (Pause)
    → resolved → CONTINUE
    → critical → L4 (Abort) → ROLLBACK + STOP
```
