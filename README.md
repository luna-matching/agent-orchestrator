# Agent Orchestrator

Claude Code でエージェントチームを構築するためのフレームワーク。

各プロジェクトにインストールして使用する。中央リポジトリからエージェント定義を取得し、プロジェクトごとに独立したエージェントチームを構成。

[simota/agent-skills](https://github.com/simota/agent-skills) の設計思想をベースに再設計。

## Install

```bash
# 全エージェントをインストール
curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash

# 特定のエージェントのみ
curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash -s -- nexus rally builder radar

# ローカルクローンから
git clone https://github.com/luna-matching/agent-orchestrator.git /tmp/agent-orchestrator
cd your-project && /tmp/agent-orchestrator/install.sh
```

### インストール結果

```
your-project/
├── .claude/
│   └── agents/
│       ├── _framework.md    # フレームワークプロトコル
│       ├── nexus.md          # オーケストレーター
│       ├── rally.md          # 並列オーケストレーター
│       ├── builder.md        # 実装
│       ├── ...               # 他のエージェント
│       └── architect.md      # メタデザイナー
├── .agents/
│   └── PROJECT.md            # 共有知識ファイル
└── CLAUDE.md                 # フレームワーク参照を追記
```

## Usage

```
/nexus ログイン機能を実装したい
/scout このバグの原因を調査して
/rally フロントエンドとバックエンドを並列実装して
/builder ユーザー認証APIを実装して
```

## Architecture

```
User Request
     |
     v
  [Nexus] ---- 単一セッションオーケストレーター
     |
     +---> Sequential: Agent1 → Agent2 → Agent3 (role simulation)
     |
     +---> Parallel: Rally → TeamCreate → Teammates (実セッション並列)
```

### Design: Registry Pattern

```
                 ┌──────────────────────────┐
                 │  GitHub Repository        │
                 │  (luna-matching/          │
                 │   agent-orchestrator)     │
                 │                          │
                 │  Central agent registry  │
                 └────────┬─────────────────┘
                          │
            curl / install.sh
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          v               v               v
     Project A       Project B       Project C
     .claude/agents/ .claude/agents/ .claude/agents/
     (独立動作)       (独立動作)       (独立動作)
```

各プロジェクトは独立したエージェントチームを持ち、同時並行で実行可能。

## Agents

### オーケストレーション

| Agent | Role | Description |
|-------|------|-------------|
| **Nexus** | 統括 | タスク分類→チェーン設計→自動実行 |
| **Sherpa** | 分解 | タスクを15分以内のAtomic Stepに分割 |
| **Rally** | 並列 | TeamCreate/Task APIで複数Claudeを管理 |
| **Architect** | 設計 | 新エージェントのSKILL.md設計 |

### 調査・実装

| Agent | Role | Description |
|-------|------|-------------|
| **Scout** | 調査 | バグ調査・根本原因分析（5-Why） |
| **Builder** | 実装 | 本番品質コード。型安全・TDD・DDD |
| **Forge** | 試作 | プロトタイプ。動くものを最速で |
| **Artisan** | UI | フロントエンド。React/Vue/Svelte |

### 品質・Git

| Agent | Role | Description |
|-------|------|-------------|
| **Radar** | テスト | テスト追加・カバレッジ向上 |
| **Sentinel** | セキュリティ | SAST・OWASP Top 10 |
| **Judge** | レビュー | コードレビュー（変更なし） |
| **Zen** | リファクタ | リファクタリング（動作不変） |
| **Guardian** | Git | コミット粒度最適化・PR戦略 |

## Execution Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| AUTORUN_FULL | Default | 全自動（ガードレール付き） |
| AUTORUN | `## NEXUS_AUTORUN` | SIMPLE自動、COMPLEX→Guided |
| GUIDED | `## NEXUS_GUIDED` | 判断ポイントで確認 |
| INTERACTIVE | `## NEXUS_INTERACTIVE` | 各ステップで確認 |

## Chain Templates

| Task | Chain |
|------|-------|
| バグ修正(簡単) | Scout → Builder → Radar |
| バグ修正(複雑) | Scout → Sherpa → Builder → Radar → Sentinel |
| 機能開発(小) | Builder → Radar |
| 機能開発(中) | Sherpa → Forge → Builder → Radar |
| 機能開発(大) | Sherpa → Rally(Builder + Artisan + Radar) |
| リファクタリング | Zen → Radar |
| セキュリティ監査 | Sentinel → Builder → Radar |
| PR準備 | Guardian → Judge |

## Customization

### エージェント追加

1. `agents/[name]/SKILL.md` を作成（`_templates/SKILL_TEMPLATE.md` 参照）
2. `install.sh` の `ALL_AGENTS` に追加
3. `install.sh` を実行して対象プロジェクトに反映

### プロジェクト固有設定

`CLAUDE.md` に追記:

```markdown
Project type: SaaS
```

### 共有知識

`.agents/PROJECT.md` にエージェント間の知識を蓄積:

- Architecture Decisions
- Domain Glossary
- Known Gotchas
- Activity Log（全エージェント必須）

## Origin

[simota/agent-skills](https://github.com/simota/agent-skills) (MIT License) の設計思想をベースに構築。

## License

MIT
