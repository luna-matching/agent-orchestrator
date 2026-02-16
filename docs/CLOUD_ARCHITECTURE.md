# Cloud-first Execution Architecture

## Background

- Local: Mac Apple M4 Pro / Unified Memory 48GB
- Problem: 2-3 heavy processes in parallel cause memory pressure and OS freeze
- Goal: Heavy processing runs on cloud, local stays light (IDE/Browser/Slack only)

---

## EC2 vs GitHub Codespaces

| Criteria | EC2 | GitHub Codespaces |
|----------|-----|-------------------|
| インフラ管理 | 自分で構築・運用 | GitHub完全管理（ゼロ運用） |
| セットアップ | AMI, VPC, SG, SSH key等 | `gh codespace create` のみ |
| SSH接続 | SSH key管理が必要 | `gh codespace ssh`（認証不要） |
| 開発環境 | 手動構築 | devcontainer.json で自動 |
| リポジトリ連携 | deploy key / clone手動 | リポジトリ直結（自動clone） |
| コスト体系 | 時間課金（停止忘れリスク） | 使用時間課金（自動サスペンド） |
| スケール | インスタンスタイプ変更（停止必要） | マシンタイプ選択（即座） |
| CLI統合 | aws CLI + ssh | gh CLI（統一） |
| Secrets管理 | AWS Secrets Manager | GitHub Codespace Secrets |
| 自動停止 | 手動 or スクリプト | アイドルタイムアウト（デフォルト30分） |

### Conclusion: GitHub Codespaces

GitHub Codespaces を選択する理由：

1. **インフラ管理ゼロ** - VPC, Security Group, AMI, SSH key 等の管理が一切不要
2. **pay-per-use** - アイドル時に自動サスペンドされ、課金が止まる
3. **`gh` CLI統合** - 既存のGitHub CLIワークフローに自然に統合
4. **リポジトリ直結** - Codespace作成時にリポジトリが自動clone・セットアップ
5. **devcontainer.json** - 環境構成をコードとして管理、再現性100%

---

## Recommended Configuration

| Component | Spec |
|-----------|------|
| Machine (standard) | 4-core / 16GB RAM ($0.36/hr) |
| Machine (heavy) | 8-core / 32GB RAM ($0.72/hr) |
| Storage | 64GB（devcontainer.json で指定） |
| Idle timeout | 30分（自動サスペンド） |
| Retention | 停止後7日（設定可能） |
| Image | mcr.microsoft.com/devcontainers/universal:2 |

### マシンタイプ選択基準

| Workload | Machine | Reason |
|----------|---------|--------|
| テスト・lint・小規模ビルド | 4-core / 16GB | 十分な性能、低コスト |
| 並列ジョブ・モデル学習・大規模ビルド | 8-core / 32GB | メモリ余裕あり |
| 極端に重い処理（稀） | 16-core / 64GB | 必要な場合のみ |

---

## Cost Estimate

| Plan | Hourly | Monthly (3hr/day, 20days) |
|------|--------|---------------------------|
| 4-core / 16GB | $0.36 | ~$21 |
| 8-core / 32GB | $0.72 | ~$43 |
| 16-core / 64GB | $1.44 | ~$86 |
| Storage (64GB) | - | ~$4.48/月 |

EC2比較（参考）:
- EC2 t3.2xlarge on-demand: ~$87/月（12hr/day, 22days）
- EC2 + stop when idle: ~$40-60/月

**Codespaces 4-core: ~$21/月、8-core: ~$43/月。EC2より安価かつ運用コストゼロ。**

---

## Architecture

```
┌─────────────────────────┐            ┌──────────────────────────────┐
│  Local Mac (48GB)       │            │  GitHub Codespace            │
│                         │   gh CLI   │  4-core/16GB or 8-core/32GB  │
│  Claude Code (CLI)      │──────────→ │                              │
│  IDE / Browser          │            │  Job A: npm run build        │
│  Slack                  │            │  Job B: pytest               │
│                         │ ←──────────│  Job C: python train.py      │
│  Memory: ~8GB used      │  Results   │                              │
│  CPU: Light             │            │  Auto-suspend after 30min    │
└─────────────────────────┘            │  Storage: 64GB               │
                                       └──────────────────────────────┘
```

---

## Three-Job Parallel Operation Example

### Job A: video-marketing-ai Trend Scraping + Embedding

```bash
cs run "cd /workspaces/video-marketing-ai && python scripts/trend_scrape.py && python scripts/generate_embeddings.py"
```

- Duration: ~3 hours
- Memory: ~6GB (embedding model + data)

### Job B: coupon-optimization-engine Backfill

```bash
cs run "cd /workspaces/coupon-optimization-engine && npm run backfill:all"
```

- Duration: ~1 hour
- Memory: ~4GB (DB queries + aggregation)

### Job C: LROS Prediction Model Training

```bash
cs run "cd /workspaces/lros && python train.py --config prod.yaml && python generate_report.py"
```

- Duration: ~2 hours
- Memory: ~8GB (model training + report)

### Monitoring

```bash
cs status
# NAME                  STATE      MACHINE        IDLE
# video-marketing-ai    Available  4-core/16GB    2m
# coupon-engine         Available  4-core/16GB    5m
# lros                  Available  8-core/32GB    1m

cs ssh   # Codespace にSSH接続して直接確認
```

Local Mac stays at ~8GB usage (IDE + browser + Slack). No memory pressure.

---

## Security

| Concern | Mitigation |
|---------|------------|
| API keys | GitHub Codespace Secrets（暗号化保存、Codespace内のみ展開） |
| SSH keys | 不要（`gh codespace ssh` が認証処理） |
| Repo access | GitHub認証で自動（追加設定不要） |
| Network | GitHub管理（Security Group設定不要） |
| Data at rest | GitHub管理のストレージ暗号化 |

---

## Directory Structure (in Codespace)

```
/workspaces/
└── <repository-name>/     # リポジトリのルートが直接マウント
    ├── .devcontainer/
    │   └── devcontainer.json
    ├── CLAUDE.md
    ├── .claude/
    │   └── agents/
    └── (project files)
```

Codespacesでは `/workspaces/<repo>` がデフォルトの作業ディレクトリ。EC2のように `~/work/` にcloneする必要はない。
