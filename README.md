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
│       ├── ceo.md            # 意思決定（最上流）
│       ├── nexus.md          # オーケストレーター
│       ├── analyst.md        # データ分析
│       ├── rally.md          # 並列オーケストレーター
│       ├── builder.md        # 実装
│       ├── ...               # 他のエージェント
│       └── architect.md      # メタデザイナー
├── .agents/
│   ├── PROJECT.md            # 共有知識ファイル
│   └── LUNA_CONTEXT.md       # ビジネス文脈（CEO参照）
└── CLAUDE.md                 # フレームワーク参照を追記
```

## Usage

```
/ceo この機能の優先度を判断して
/nexus ログイン機能を実装したい
/analyst ユーザー離脱率を分析して
/scout このバグの原因を調査して
/rally フロントエンドとバックエンドを並列実装して
/builder ユーザー認証APIを実装して
```

## Architecture

```
User Request
     |
     v
  [Nexus] ---- Phase 0: EXECUTIVE_REVIEW
     |
     +---> CEO判断が必要？ → [CEO] → 方針・制約を付与
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

### 意思決定・分析

| Agent | Role | Description |
|-------|------|-------------|
| **CEO** | 意思決定 | 経営者視点の優先順位・Go-NoGo・リスク評価 |
| **Analyst** | 分析 | Redash APIでデータ取得→指標定義→示唆出し |

### オーケストレーション

| Agent | Role | Description |
|-------|------|-------------|
| **Nexus** | 統括 | タスク分類→CEO判定→チェーン設計→自動実行 |
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
| **ビジネス/戦略** | **CEO → Sherpa → Forge/Builder → Radar** |
| **データ分析** | **Analyst → CEO（意思決定要時）→ Nexus（施策化）** |

## Redash Integration

Analyst エージェントが Redash API を使用してデータを取得・分析する。

### セットアップ

```bash
# 環境変数を設定
export REDASH_BASE_URL=https://your-redash.example.com
export REDASH_API_KEY=your_api_key_here
```

### 使用例

```bash
# クエリ結果を取得（JSON）
scripts/redash/query.sh 42

# パラメータ付き実行
scripts/redash/query.sh 42 '{"p_start_date":"2025-01-01","p_end_date":"2025-01-31"}'

# CSV出力
scripts/redash/query.sh 42 '' csv
```

結果は `artifacts/redash/` に保存される（gitignore対象）。

env設定のテンプレートは `scripts/redash/.env.example` を参照。

## Customization

### エージェント追加

1. `agents/[name]/SKILL.md` を作成（`_templates/SKILL_TEMPLATE.md` 参照）
2. `install.sh` の `ALL_AGENTS` に追加
3. `install.sh` を実行して対象プロジェクトに反映

### ビジネス文脈

`.agents/LUNA_CONTEXT.md` をプロジェクトに合わせてカスタマイズ:

- Mission（目的）
- Target Users（ターゲット）
- Business Constraints（制約）
- Decision Framework（判断基準の優先順位）

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
