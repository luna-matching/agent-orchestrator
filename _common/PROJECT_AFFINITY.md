# Project Affinity Matrix

プロジェクト種別ごとのエージェント親和性。Nexus がルーティングに使用。

---

## Project Types

| Type | Description |
|------|-------------|
| SaaS | Webアプリ、サブスクリプション |
| E-commerce | EC、カート、決済 |
| Dashboard | 管理画面、CRUD |
| CLI | コマンドラインツール |
| Library | npm パッケージ、SDK |
| API | バックエンドAPI |
| Mobile | モバイルアプリ |

---

## Affinity (H=必須, M=場面次第, —=不要)

### Universal Agents (全プロジェクト共通)

Nexus, Builder, Radar, Judge, Zen, Guardian, Sherpa, Scout, Rally

### By Project Type

| Agent | SaaS | E-com | Dash | CLI | Lib | API |
|-------|------|-------|------|-----|-----|-----|
| Artisan | H | H | H | — | — | — |
| Forge | H | H | H | M | — | M |
| Sentinel | H | H | M | — | M | H |
| Architect | M | M | M | M | M | M |

---

## Usage

```yaml
Project_Type: SaaS
Task: "Add OAuth2"

Must-include (H):
  - Builder, Sentinel, Radar

Consider (M):
  - Forge, Architect

Skip (—):
  - (none for SaaS)
```
