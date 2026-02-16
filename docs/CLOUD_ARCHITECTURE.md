# Cloud-first Execution Architecture

## Background

- Local: Mac Apple M4 Pro / Unified Memory 48GB
- Problem: 2-3 heavy processes in parallel cause memory pressure and OS freeze
- Goal: Heavy processing runs on cloud, local stays light (IDE/Browser/Slack only)

---

## EC2 vs ECS/Fargate

| Criteria | EC2 | ECS/Fargate |
|----------|-----|-------------|
| tmux support | Native | Not available (ephemeral containers) |
| SSH access | Full | Limited (ECS Exec) |
| Interactive debug | Easy | Difficult |
| Persistent state | Yes (EBS) | No (stateless) |
| Setup complexity | Low | High |
| Multi-process per instance | Yes | One task per container |
| Cost (always-on) | Lower | Higher |
| Existing workflow fit | SSH-based ops | Requires new workflow |
| Auto-scaling | Manual | Built-in |

### Conclusion: EC2

EC2 is the clear choice for this use case:

1. **tmux is a hard requirement** - ECS/Fargate containers are ephemeral and don't support persistent terminal sessions
2. **SSH access** - Interactive debugging and job attachment need direct SSH
3. **Simplicity** - Same-day operational start; no container orchestration overhead
4. **Cost** - Single instance handles 3+ concurrent jobs efficiently
5. **Existing workflow** - Team already uses SSH for EC2 deployments

---

## Recommended Configuration

| Component | Spec |
|-----------|------|
| Instance | t3.2xlarge (8 vCPU, 32GB RAM) |
| AMI | Amazon Linux 2023 |
| Storage | 100GB gp3 EBS |
| Region | ap-northeast-1 (Tokyo) |
| Access | SSM Session Manager + SSH |
| Key management | SSM Parameter Store |

### Why t3.2xlarge

- 32GB RAM handles 3 concurrent jobs (each ~4-10GB)
- 8 vCPU provides sufficient CPU for parallel execution
- Burstable (t3) is cost-effective for intermittent heavy workloads
- Upgrade path: m7g.2xlarge (Graviton, 32GB) for sustained CPU workloads

---

## Cost Estimate

| Plan | Hourly | Monthly (12hr/day, 22days) |
|------|--------|---------------------------|
| On-demand | ~$0.33 | ~$87 |
| Reserved 1yr | ~$0.21 | ~$55 |
| Spot | ~$0.10 | ~$26 (interruptible) |
| Stop when idle | varies | ~$40-60 (estimated) |

Recommendation: On-demand + stop when not in use. Consider Reserved after usage patterns stabilize.

---

## Architecture

```
┌─────────────────────────┐            ┌──────────────────────────────┐
│  Local Mac (48GB)       │            │  AWS EC2 (t3.2xlarge)        │
│                         │   SSH/SSM  │  32GB RAM / 8 vCPU           │
│  Claude Code (CLI)      │──────────→ │                              │
│  IDE / Browser          │            │  tmux session: job-a (6GB)   │
│  Slack                  │            │  tmux session: job-b (4GB)   │
│                         │ ←──────────│  tmux session: job-c (8GB)   │
│  Memory: ~8GB used      │  Results   │                              │
│  CPU: Light             │            │  ~/logs/ → CloudWatch        │
└─────────────────────────┘            │  ~/work/ → GitHub repos      │
                                       └──────────────────────────────┘
```

---

## Three-Job Parallel Operation Example

### Job A: video-marketing-ai Trend Scraping + Embedding

```bash
orch run vma-scrape "cd ~/work/video-marketing-ai && python scripts/trend_scrape.py && python scripts/generate_embeddings.py"
```

- Duration: ~3 hours
- Memory: ~6GB (embedding model + data)
- Log: ~/logs/vma-scrape/run.log

### Job B: coupon-optimization-engine Backfill

```bash
orch run coupon-backfill "cd ~/work/coupon-optimization-engine && npm run backfill:all"
```

- Duration: ~1 hour
- Memory: ~4GB (DB queries + aggregation)
- Log: ~/logs/coupon-backfill/run.log

### Job C: LROS Prediction Model Training

```bash
orch run lros-train "cd ~/work/lros && python train.py --config prod.yaml && python generate_report.py"
```

- Duration: ~2 hours
- Memory: ~8GB (model training + report)
- Log: ~/logs/lros-train/run.log

### Monitoring All Three

```bash
orch status
# NAME             STATE    STARTED              MEMORY
# vma-scrape       RUNNING  2026-02-16 14:30:00  5.8GB
# coupon-backfill  RUNNING  2026-02-16 14:35:00  3.2GB
# lros-train       RUNNING  2026-02-16 14:40:00  7.1GB

orch logs vma-scrape --follow    # Stream logs
orch attach coupon-backfill      # Interactive tmux
```

Local Mac stays at ~8GB usage (IDE + browser + Slack). No memory pressure.

---

## Security

| Concern | Mitigation |
|---------|------------|
| SSH keys | Store in SSM Parameter Store, not local files |
| API tokens | AWS Secrets Manager or SSM SecureString |
| Network | Security Group: restrict SSH to known IPs |
| Repo access | Deploy key per repo, not personal PAT |
| Instance access | IAM role with minimum permissions |

---

## Directory Structure (on EC2)

```
~/
├── work/                    # Git repos (cloned here)
│   ├── video-marketing-ai/
│   ├── coupon-optimization-engine/
│   ├── lros/
│   └── has/
├── logs/                    # Job logs (30-day retention)
│   ├── vma-scrape/
│   │   └── run.log
│   ├── coupon-backfill/
│   │   └── run.log
│   └── lros-train/
│       └── run.log
└── bin/                     # Custom scripts
```
