# Agent Orchestrator Framework

## Overview

エージェントチーム構築のための中央レジストリリポジトリ。

各プロジェクトに `install.sh` でエージェント定義を配布する。このリポジトリ自体はレジストリであり、直接 clone して使うものではない。

**Origin**: [simota/agent-skills](https://github.com/simota/agent-skills) の設計思想をベースに構築。

## Repository Structure

```
agent-orchestrator/
├── agents/              # エージェント定義（SKILL.md）
│   ├── ceo/             # 意思決定（最上流）
│   ├── nexus/           # 統括オーケストレーター
│   ├── rally/           # 並列オーケストレーター
│   ├── sherpa/          # タスク分解
│   ├── builder/         # 本番実装
│   ├── scout/           # バグ調査
│   ├── radar/           # テスト
│   ├── sentinel/        # セキュリティ
│   ├── guardian/        # Git/PR
│   ├── judge/           # コードレビュー
│   ├── zen/             # リファクタリング
│   ├── forge/           # プロトタイプ
│   ├── artisan/         # フロントエンド
│   ├── architect/       # メタデザイナー
│   └── analyst/         # データ分析
├── _common/             # 共通プロトコル
│   ├── INTERACTION.md
│   ├── GUARDRAIL.md
│   ├── GIT_GUIDELINES.md
│   ├── PARALLEL.md
│   ├── PROJECT_AFFINITY.md
│   └── REVERSE_FEEDBACK.md
├── _templates/          # プロジェクト配布テンプレート
│   ├── CLAUDE_PROJECT.md  → .claude/agents/_framework.md
│   ├── PROJECT.md         → .agents/PROJECT.md
│   ├── LUNA_CONTEXT.md    → .agents/LUNA_CONTEXT.md
│   └── SKILL_TEMPLATE.md  # 新エージェント作成用
├── scripts/
│   └── redash/          # Redash API ツール
│       ├── query.sh
│       └── .env.example
└── install.sh           # インストーラー
```

## Installation (per-project)

```bash
curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash
```

## Core Principles

1. **CEO-first for business decisions** - ビジネス判断は技術実装の前にCEOが方針を出す
2. **Hub-spoke** - 全通信はオーケストレーター経由
3. **Minimum viable chain** - 必要最小限のエージェント構成
4. **File ownership is law** - 並列実行時のファイルオーナーシップ厳守
5. **Fail fast, recover smart** - ガードレール L1-L4
6. **Context is precious** - `.agents/PROJECT.md` + `.agents/LUNA_CONTEXT.md` で知識共有

## Contributing

### エージェント追加

1. `agents/[name]/SKILL.md` を `_templates/SKILL_TEMPLATE.md` に従い作成
2. `install.sh` の `ALL_AGENTS` に名前を追加
3. `_common/PROJECT_AFFINITY.md` にアフィニティを追記
4. `README.md` / `CLAUDE.md` の Agents 一覧を更新
