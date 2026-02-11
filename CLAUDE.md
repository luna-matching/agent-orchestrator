# Agent Orchestrator Framework

## Overview

エージェントチーム構築のための中央レジストリリポジトリ。

各プロジェクトに `install.sh` でエージェント定義を配布する。このリポジトリ自体はレジストリであり、直接 clone して使うものではない。

**Origin**: [simota/agent-skills](https://github.com/simota/agent-skills) の設計思想をベースに構築。

## Repository Structure

```
agent-orchestrator/
├── agents/              # エージェント定義（SKILL.md）
│   ├── nexus/
│   ├── rally/
│   ├── sherpa/
│   ├── builder/
│   ├── scout/
│   ├── radar/
│   ├── sentinel/
│   ├── guardian/
│   ├── judge/
│   ├── zen/
│   ├── forge/
│   ├── artisan/
│   └── architect/
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
│   └── SKILL_TEMPLATE.md  # 新エージェント作成用
└── install.sh           # インストーラー
```

## Installation (per-project)

```bash
curl -sL https://raw.githubusercontent.com/luna-matching/agent-orchestrator/main/install.sh | bash
```

## Core Principles

1. **Hub-spoke** - 全通信はオーケストレーター経由
2. **Minimum viable chain** - 必要最小限のエージェント構成
3. **File ownership is law** - 並列実行時のファイルオーナーシップ厳守
4. **Fail fast, recover smart** - ガードレール L1-L4
5. **Context is precious** - `.agents/PROJECT.md` で知識共有

## Contributing

### エージェント追加

1. `agents/[name]/SKILL.md` を `_templates/SKILL_TEMPLATE.md` に従い作成
2. `install.sh` の `ALL_AGENTS` に名前を追加
3. `_common/PROJECT_AFFINITY.md` にアフィニティを追記
