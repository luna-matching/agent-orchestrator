# MCP Integration Protocol

エージェントフレームワークにおけるMCPサーバー連携の共通プロトコル。

---

## Supported MCP Servers

| MCP Server | Purpose | Agent Affinity | Scope |
|------------|---------|---------------|-------|
| **Context7** | ライブラリ最新ドキュメント注入 | Builder, Artisan, Forge, Anvil | Global (user) |
| **Sentry** | エラー監視・スタックトレース分析 | Scout, Triage, Sentinel | Global (user) |
| **Memory** | ナレッジグラフベースの永続メモリ | Nexus, 全コーディネーター | Global (user) |
| **PostgreSQL** | 自然言語→SQL変換、データ分析 | Analyst, Schema, Tuner | Project-specific |

---

## Setup

### Global MCPs（全プロジェクト共通）

```bash
# Context7 - ライブラリドキュメント
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest

# Sentry - エラー監視
claude mcp add --scope user --transport http sentry https://mcp.sentry.dev/mcp

# Memory - 永続メモリ
claude mcp add --scope user memory -- npx -y @modelcontextprotocol/server-memory --memory-path ~/.claude/memory
```

### Project-specific MCPs

```bash
# PostgreSQL（READ ONLY推奨）
claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres "postgresql://readonly_user:password@host:5432/dbname"
```

---

## Usage Rules

### Context7

- 実装エージェント（Builder, Artisan, Forge, Anvil）が外部ライブラリのAPIを使う際に `use context7` で最新ドキュメントを取得
- ドキュメントが古い可能性があるフレームワーク（React, Next.js, etc.）の使用時に積極的に活用

### Sentry

- Scout: バグ調査時にSentryのエラー情報を取得して根本原因分析に活用
- Triage: インシデント対応時にSentryのエラースパイク・スタックトレースを確認
- Sentinel: セキュリティ関連のエラーパターンを検出

### Memory

- コーディネーター層（Nexus等）がセッション間の知識を永続化
- 既存の `_common/MEMORY.md` プロトコルを補完（ファイルベースのメモリと共存）
- エンティティ・リレーション・観察の3層構造でナレッジグラフを構築

### PostgreSQL

- **READ ONLYアクセスのみ**（Luna DBルール遵守）
- Analyst: Redash経由に加え、直接SQLクエリでデータ分析
- Schema: 既存スキーマの調査・ER図生成
- Tuner: EXPLAIN ANALYZEによるクエリ最適化
- 接続文字列はプロジェクトの `.env` から取得し、コードに埋め込まない

---

## Security Rules

1. PostgreSQL MCPは必ず **READ ONLYユーザー** で接続する
2. 接続文字列をコミットしない（`.env` またはシークレット管理）
3. Sentry MCPはOAuth認証（トークン不要）
4. Memory MCPのデータは `~/.claude/memory/` にローカル保存（外部送信なし）

---

## MCP Status Check

セッション内で `/mcp` コマンドを実行してMCPサーバーの接続状態を確認する。
