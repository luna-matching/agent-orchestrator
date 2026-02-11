# Interaction Rules

全エージェントが参照する対話制御ルール。

---

## Execution Modes

| Mode | Trigger | Behavior | Interaction |
|------|---------|----------|-------------|
| AUTORUN_FULL | Default | 全自動実行 | ガードレールのみ |
| AUTORUN | `## NEXUS_AUTORUN` | SIMPLE自動 | エラー時のみ |
| GUIDED | `## NEXUS_GUIDED` | 判断ポイント確認 | INTERACTION_TRIGGERS |
| INTERACTIVE | `## NEXUS_INTERACTIVE` | 毎ステップ確認 | 常時 |

---

## Question Format (AskUserQuestion Compliant)

```yaml
questions:
  - question: "質問文（?で終わる、具体的）"
    header: "短いラベル"  # 12文字以内
    options:  # 2-4個（"Other"は自動追加）
      - label: "選択肢名"  # 1-5語
        description: "選択の影響を説明"
    multiSelect: false  # true = 複数選択可
```

---

## Complexity Assessment

| 指標 | SIMPLE | COMPLEX |
|------|--------|---------|
| 推定ステップ | 1-2 | 3+ |
| 影響ファイル | 1-3 | 4+ |
| セキュリティ関連 | No | Yes |
| 破壊的変更 | No | Yes |

- SIMPLE + AUTORUN → 自動実行
- COMPLEX → GUIDED に自動切替

---

## Standard Triggers

### ON_SECURITY_RISK
```yaml
questions:
  - question: "セキュリティリスクが検出されました。どう対応しますか？"
    header: "セキュリティ"
    options:
      - label: "Sentinelで監査（推奨）"
        description: "セキュリティ専門エージェントに確認を依頼"
      - label: "リスクを承知で続行"
        description: "自己責任で調査を継続"
      - label: "作業を中断"
        description: "安全のため作業を停止"
```

### ON_BREAKING_CHANGE
```yaml
questions:
  - question: "破壊的変更が必要です。進めますか？"
    header: "破壊的変更"
    options:
      - label: "影響範囲を先に確認（推奨）"
        description: "影響を受けるコードの一覧を表示"
      - label: "変更を実行"
        description: "破壊的変更を含めて実装"
      - label: "互換性を維持"
        description: "破壊的変更を避ける代替案を検討"
```

### ON_MULTIPLE_APPROACHES
```yaml
questions:
  - question: "複数の実装アプローチがあります。どれを採用しますか？"
    header: "アプローチ"
    options:
      - label: "[アプローチA]（推奨）"
        description: "[推奨理由]"
      - label: "[アプローチB]"
        description: "[特徴/トレードオフ]"
```

---

## Escalation Rules

| Level | 条件 | アクション |
|-------|------|-----------|
| 1 | 軽微な不明点 | 最安全な選択肢で自動進行 |
| 2 | 複数の有効な選択肢 | AskUserQuestion で確認 |
| 3 | ブロッキングな不明点 | 作業一時停止、ユーザー確認必須 |
| 4 | 3回エスカレーション後も未解決 | 作業中断、手動対応を推奨 |

---

## Output Language

全ての質問文・選択肢・説明は **日本語** で出力すること。
