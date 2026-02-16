# Cloud Routing Protocol

Cloud-first 実行基盤によるタスクルーティングプロトコル。

---

## Overview

ローカル環境（48GB Mac）のメモリ制約を回避するため、重い処理をAWS EC2に自動ルーティングする。Nexus/Rally がタスクを受けた時、実行先を判断するルールを定義する。

---

## Routing Decision

### クラウド実行（デフォルト）

以下の **いずれか** に該当すればクラウドで実行：

| Condition | Examples |
|-----------|----------|
| 実行見込み10分超 | ビルド、バックフィル、モデル学習 |
| 大量ログ出力 | watch, tail -f, dev server, build logs |
| 重処理 | LLM/embedding/ベクトルDB/スクレイピング/集計 |
| 並列実行 | 同時2本以上のジョブ |
| メモリ集約 | 推定8GB超、または不明 |

### ローカル実行（例外）

以下の **全て** を満たす場合のみローカル：

| Condition | Examples |
|-----------|----------|
| 短時間（3分以内） | 小さなスクリプト、設定変更、テスト |
| UI操作中心 | ブラウザ/IDE操作 |
| 軽量確認 | git status, ls, 1回限りのコマンド |

### 判断に迷った場合

**クラウドに送る。** ローカルでフリーズするコストの方が、クラウドで実行するコストより遥かに高い。

---

## Execution Flow

```
User Request
     |
     v
  [Nexus] ── タスク分類
     |
     +── SIMPLE? ──→ 実行見込み3分以内？ ──→ YES → ローカル実行
     |                                   └→ NO  → クラウド実行
     |
     +── COMPLEX? ──→ デフォルトでクラウド実行
     |
     v
  Cloud Execution:
     |
     +── SSH to EC2
     +── tmux new-session -d -s <job-name>
     +── コマンド実行 + ログ記録
     +── 完了通知（Slack or stdout）
```

---

## Cloud Job Lifecycle

| State | Description |
|-------|-------------|
| QUEUED | 投入待ち |
| STARTING | EC2でtmuxセッション起動中 |
| RUNNING | 実行中 |
| DONE | 正常完了 |
| FAILED | 失敗（ログ参照） |
| STOPPED | 手動停止 |

---

## Job Naming Convention

Format: `<project>-<task>-<YYYYMMDD-HHMM>`

Examples:
- `lros-backfill-20260216-1430`
- `vma-scrape-20260216-0900`
- `coupon-aggregate-20260216-1100`

短縮名も許容（`my-job`, `test-run` など）。ただしtmuxセッション名として有効な文字列であること。

---

## Log Management

| Item | Value |
|------|-------|
| Path | `~/logs/<job-name>/run.log` |
| Format | stdout + stderr を tee でファイルに記録 |
| Retention | 30日（cron で自動削除） |
| CloudWatch | オプション（重要ジョブのみ） |
| Exit code | ログ末尾に `[EXIT: N]` を記録 |

---

## CLI Commands

| Command | Description |
|---------|-------------|
| `orch up` | EC2インスタンスを起動（SSH可能まで待機） |
| `orch down` | EC2インスタンスを停止（稼働ジョブなし時のみ） |
| `orch run <name> <cmd>` | クラウドでジョブ起動（tmux detach） |
| `orch logs <name> [-f]` | ログ表示（-f でフォロー） |
| `orch attach <name>` | tmuxセッションにアタッチ |
| `orch stop <name>` | ジョブ停止（tmux kill-session） |
| `orch status` | 稼働中ジョブ一覧 |
| `orch list` | 全ジョブ履歴（ログディレクトリ） |
| `orch ssh` | EC2にSSH接続 |

Configuration: `scripts/cloud/.env`

---

## Integration with Existing Protocols

### AUTORUN

AUTORUN_FULL モードでは、Nexus がタスク分類時にルーティング判断を自動で行う。ユーザーへの確認なしにクラウドへ送る。

### GUARDRAIL

クラウドジョブにもガードレール L1-L4 が適用される：
- L1: ログ監視（CloudWatch or orch logs）
- L2: 自動リトライ（ジョブ再実行）
- L3: ロールバック（git reset on EC2）
- L4: 即時停止（orch stop + 通知）

### PARALLEL

Rally による並列実行では、複数ジョブをクラウド上の個別tmuxセッションとして管理する。File ownership はローカルと同じルールが適用される。

---

## Agent Affinity

| Default Execution | Agents |
|-------------------|--------|
| **Cloud** | Builder, Artisan, Forge, Anvil（ビルド伴う場合） |
| **Cloud** | Analyst, Schema, Tuner（データ処理） |
| **Cloud** | Scout, Sentinel, Probe（スキャン処理） |
| **Cloud** | Radar, Voyager（テスト実行） |
| **Cloud** | Stream, Bolt（パイプライン/最適化） |
| **Local** | Lens, Judge, Cipher（読み取り専用） |
| **Local** | CEO, Magi, Bridge（判断のみ） |
| **Local** | Canvas, Scribe, Quill（ドキュメント生成） |
| **Depends** | Rally（並列数による）, Nexus（判断後に委任） |

---

## Auto-Routing Decision Protocol

Nexus/Rally がタスクを受けた時、以下のアルゴリズムで実行先を自動判定する。

### Step 1: Agent Affinity Check

タスクを担当するエージェントのデフォルト実行先を確認する。

```
agent_affinity = lookup(agent_name, AFFINITY_TABLE)
if agent_affinity == "local":
    return LOCAL  # 判断系・読み取り系は常にローカル
```

### Step 2: Task Signal Scoring

以下のシグナルを評価し、スコアを加算する。**スコア >= 2 ならクラウド実行。**

| Signal | Score | Detection Method |
|--------|-------|------------------|
| コマンドに `build`, `install`, `compile` を含む | +2 | keyword match |
| コマンドに `train`, `backfill`, `migrate`, `scrape` を含む | +2 | keyword match |
| コマンドに `pytest`, `test`, `vitest`, `jest` を含む | +1 | keyword match |
| コマンドに `docker`, `npm run`, `uv sync` を含む | +1 | keyword match |
| `watch`, `dev`, `serve` を含む（長時間プロセス） | +2 | keyword match |
| 並列ジョブ数が現在 >= 1（追加実行） | +2 | `orch status` check |
| 処理対象のデータ量が不明 or 大 | +1 | context estimation |
| ユーザーが明示的に `cloud:` プレフィックスを付けた | +3 | prefix check |
| ユーザーが明示的に `local:` プレフィックスを付けた | -10 | prefix check |

### Step 3: Execution

```
if score >= 2:
    # Cloud execution
    job_name = generate_job_name(project, task)
    execute: orch run <job_name> "<command>"
    monitor: orch logs <job_name> -f
else:
    # Local execution
    execute locally as normal
```

### Decision Examples

| Task | Signals | Score | Result |
|------|---------|-------|--------|
| `cd lros/backend && uv run pytest` | pytest(+1), uv(+1) | 2 | **Cloud** |
| `npm run build` | build(+2), npm(+1) | 3 | **Cloud** |
| `git status` | (none) | 0 | **Local** |
| `python train.py --epochs 100` | train(+2) | 2 | **Cloud** |
| CEO判断タスク | agent=CEO(local) | - | **Local** |
| `cloud: ruff check .` | cloud prefix(+3) | 3 | **Cloud** |
| `local: npm run build` | local prefix(-10), build(+2) | -8 | **Local** |

### Nexus Implementation

Nexus がタスクを受けた時のルーティング判定テンプレート:

```
## ルーティング判定

タスク: [タスク内容]
担当エージェント: [agent_name]

### Agent Affinity: [cloud/local/depends]
### Signal Score:
- [signal1]: +N
- [signal2]: +N
- Total: N

### 判定: [CLOUD/LOCAL]
### 実行: [orch run ... / ローカル実行]
```

---

## Quick Reference

```yaml
# Nexus decision template
CLOUD_ROUTING:
  default: cloud
  score_threshold: 2
  force_cloud:
    - runtime_estimate > 10min
    - heavy_log_output
    - llm_or_embedding
    - parallel_execution >= 2
    - memory_estimate > 8GB
    - memory_unknown
  allow_local:
    - runtime_estimate <= 3min AND ui_centric AND lightweight_check
    - agent_affinity == local
  keywords_cloud:
    - build, install, compile, train, backfill, migrate, scrape
    - watch, dev, serve, docker, pytest, test
  user_override:
    - "cloud:" prefix → force cloud
    - "local:" prefix → force local
```
