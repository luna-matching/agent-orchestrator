# Agent Orchestrator

Claude Code Agent Teams API に最適化されたエージェントチーム構築フレームワーク。

[simota/agent-skills](https://github.com/simota/agent-skills) の設計思想をベースに、Claude Code のネイティブツール（TeamCreate, Task, SendMessage, TaskCreate 等）との統合を前提に再設計。

## Features

- **Hub-Spoke アーキテクチャ** - Nexus/Rally を中心としたエージェント協調
- **ファイルオーナーシップ制御** - 並列実行時の競合防止プロトコル
- **4段階ガードレール** - L1(監視)〜L4(中断)の安全実行制御
- **AUTORUN モード** - エージェントチェーンの全自動実行
- **逆フィードバック** - 下流→上流の品質フィードバックループ
- **プロジェクト親和性マトリクス** - プロジェクト種別に応じたエージェント選定

## Quick Start

```bash
# インストール
git clone https://github.com/luna-matching/agent-orchestrator.git ~/.claude/skills

# 使用例
/Nexus ログイン機能を実装したい
/Scout このバグの原因を調査して
/Rally フロントエンドとバックエンドを並列実装して
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

### エージェント一覧

#### オーケストレーション
| Agent | 役割 |
|-------|------|
| **Nexus** | チーム統括。タスク分類→チェーン設計→自動実行 |
| **Sherpa** | タスク分解。15分以内のAtomic Stepに分割 |
| **Rally** | 並列実行。TeamCreate/Task APIで複数Claudeを管理 |
| **Architect** | メタデザイナー。新エージェントのSKILL.md設計 |

#### 調査
| Agent | 役割 |
|-------|------|
| **Scout** | バグ調査・根本原因分析（RCA） |

#### 実装
| Agent | 役割 |
|-------|------|
| **Builder** | 本番実装。型安全・TDD・DDD |
| **Forge** | プロトタイプ。動くものを最速で |
| **Artisan** | フロントエンド実装。React/Vue/Svelte |

#### 品質保証
| Agent | 役割 |
|-------|------|
| **Radar** | テスト追加・カバレッジ向上 |
| **Sentinel** | セキュリティ静的分析（SAST） |
| **Judge** | コードレビュー・バグ検出 |
| **Zen** | リファクタリング（動作不変） |

#### Git/PR
| Agent | 役割 |
|-------|------|
| **Guardian** | コミット粒度最適化・PR戦略 |

> 全エージェント定義は `agents/` ディレクトリを参照。
> 追加エージェントは [simota/agent-skills](https://github.com/simota/agent-skills) から必要に応じて取り込み可能。

## Execution Modes

| Mode | トリガー | 動作 |
|------|---------|------|
| **AUTORUN_FULL** | デフォルト | 全自動実行（ガードレール付き） |
| **AUTORUN** | `## NEXUS_AUTORUN` | SIMPLE自動、COMPLEX→Guided |
| **GUIDED** | `## NEXUS_GUIDED` | 判断ポイントで確認 |
| **INTERACTIVE** | `## NEXUS_INTERACTIVE` | 各ステップで確認 |

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

## Parallel Execution (Rally)

Rally は Claude Code Agent Teams API を直接使用して並列実行を実現:

```
Rally Assessment
     |
     v
File Ownership Declaration
     |
     v
TeamCreate → Task(teammate_a) + Task(teammate_b)
     |
     v
TaskCreate + TaskUpdate (dependency management)
     |
     v
Monitor via TaskList → SendMessage for coordination
     |
     v
Verify → shutdown_request → TeamDelete
```

### ファイルオーナーシップ

```yaml
ownership_map:
  teammate_frontend:
    exclusive_write: [src/components/**, src/pages/**]
    shared_read: [src/types/**]
  teammate_backend:
    exclusive_write: [src/api/**, src/services/**]
    shared_read: [src/types/**]
```

## Shared Knowledge

プロジェクト内の `.agents/PROJECT.md` にエージェント間の知識を蓄積:

- Architecture Decisions
- Domain Glossary
- Known Gotchas
- Activity Log（全エージェントが作業後に必須記録）

## Customization

### エージェント追加

1. `agents/[name]/SKILL.md` を作成
2. `_templates/SKILL_TEMPLATE.md` のフォーマットに従う
3. Boundaries / AUTORUN Support / Nexus Hub Mode を必ず含める

### プロジェクト固有設定

対象プロジェクトの CLAUDE.md に以下を追加:

```markdown
## Agent Framework
See ~/.claude/skills/agent-orchestrator/ for agent team definitions.
Project type: SaaS
```

## Origin

[simota/agent-skills](https://github.com/simota/agent-skills) (MIT License) の設計思想をベースに構築。
65エージェントの完全版が必要な場合は元リポジトリを参照。

## License

MIT
