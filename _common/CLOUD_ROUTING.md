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
| `orch run <name> <cmd>` | クラウドでジョブ起動（tmux detach） |
| `orch logs <name> [-f]` | ログ表示（-f でフォロー） |
| `orch attach <name>` | tmuxセッションにアタッチ |
| `orch stop <name>` | ジョブ停止（tmux kill-session） |
| `orch status` | 稼働中ジョブ一覧 |
| `orch list` | 全ジョブ履歴（ログディレクトリ） |

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

## Quick Reference

```yaml
# Nexus decision template
CLOUD_ROUTING:
  default: cloud
  force_cloud:
    - runtime_estimate > 10min
    - heavy_log_output
    - llm_or_embedding
    - parallel_execution >= 2
    - memory_estimate > 8GB
    - memory_unknown
  allow_local:
    - runtime_estimate <= 3min AND ui_centric AND lightweight_check
```
