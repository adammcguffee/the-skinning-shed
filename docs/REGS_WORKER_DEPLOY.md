# Regulations Worker Deployment Guide

> Last updated: January 23, 2026

This guide covers deploying the Regulations Worker service to a DigitalOcean droplet.

## Overview

The worker service processes regulations discovery and extraction jobs:
- **Discovery**: Crawls official state wildlife agency sites to find portal links (HTML + PDF)
- **Extraction**: Parses HTML/PDFs to extract structured season data using GPT

## Current Deployment

- **Droplet IP**: `165.245.131.150`
- **User**: `root`
- **Path**: `/opt/regs_worker`
- **Service**: `regs-worker.service`

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Supabase Edge   │────▶│  PostgreSQL     │
│  (Admin UI)     │     │  Functions       │     │  (Job Queue)    │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                              ┌────────────────┐          │
                              │  Worker        │◀─────────┘
                              │  (Droplet)     │
                              │                │────▶ OpenAI API
                              └────────────────┘
```

## Prerequisites

- DigitalOcean droplet with Ubuntu 22.04+
- Node.js 20 LTS
- Supabase project with service role key
- OpenAI API key

## Environment Variables

Create `.env` file with:

```bash
# Supabase connection
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# OpenAI
OPENAI_API_KEY=sk-your-openai-key
OPENAI_MODEL_BASIC=gpt-4.1-mini
OPENAI_MODEL_PRO=gpt-4.1

# Worker configuration
WORKER_ID=worker-1
WORKER_CONCURRENCY=4
OPENAI_MAX_CONCURRENCY=2
OPENAI_MAX_RETRIES=6

# PDF limits
REGS_PDF_MAX_BYTES=40000000
REGS_PDF_MAX_TEXT_CHARS=600000
REGS_PDF_MAX_CONTEXT_CHARS=60000

# Timeouts
REGS_FETCH_TIMEOUT_MS=30000
REGS_PDF_TIMEOUT_MS=60000

# Polling
JOB_POLL_INTERVAL_MS=2000
```

## Deployment Steps

### 1. SSH into droplet

```bash
ssh root@your-droplet-ip
```

### 2. Install Node.js LTS (if not installed)

```bash
# Check if Node.js is installed
node --version

# If not installed:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs
```

### 3. Clone/pull repository

```bash
# First time:
cd /opt
git clone https://github.com/your-org/the_skinning_shed.git regs_worker_repo

# Or update existing:
cd /opt/regs_worker_repo
git pull origin main
```

### 4. Set up worker

```bash
# Create worker directory
mkdir -p /opt/regs_worker
cd /opt/regs_worker

# Copy worker files
cp -r /opt/regs_worker_repo/worker/regs_worker/* .

# Install dependencies
npm ci

# Build TypeScript
npm run build
```

### 5. Configure environment

```bash
# Copy example and edit
cp env.example.txt .env
nano .env

# Fill in your actual values:
# - SUPABASE_URL
# - SUPABASE_SERVICE_ROLE_KEY
# - OPENAI_API_KEY
```

### 6. Install systemd service

```bash
# Copy service file
cp regs-worker.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable service to start on boot
systemctl enable regs-worker

# Start service
systemctl start regs-worker

# Check status
systemctl status regs-worker
```

### Service Configuration

The `regs-worker.service` file includes graceful shutdown settings:

```ini
TimeoutStopSec=180      # Wait 180s before SIGKILL
KillSignal=SIGTERM      # Send SIGTERM first
KillMode=mixed          # SIGTERM to main, SIGKILL to children if needed
Restart=always          # Auto-restart on failure
RestartSec=3            # 3s between restarts
```

The worker handles SIGTERM by:
1. Stopping new job claims immediately
2. Waiting up to 150s for active jobs to complete
3. Exiting cleanly

### 7. View logs

```bash
# Follow logs
journalctl -u regs-worker -f

# Last 100 lines
journalctl -u regs-worker -n 100

# Since last hour
journalctl -u regs-worker --since "1 hour ago"
```

## Managing the Worker

### Restart

```bash
systemctl restart regs-worker
```

### Stop

```bash
systemctl stop regs-worker
```

### Update deployment

```bash
cd /opt/regs_worker_repo
git pull origin main

cd /opt/regs_worker
cp -r /opt/regs_worker_repo/worker/regs_worker/* .
npm ci
npm run build

systemctl restart regs-worker
```

## Job Queue Tables

The worker uses these Supabase tables:

- `regs_admin_runs` - Parent run records (discovery/extraction)
- `regs_jobs` - Individual jobs (one per state or state+species)
- `regs_job_events` - Log entries for debugging

## Edge Functions

Control plane functions (lightweight, no heavy processing):

- `regs-run-start` - Create run and queue jobs
- `regs-run-stop` - Stop run and cancel queued jobs
- `regs-run-status` - Get run progress and job counts

## Concurrency Configuration

### Worker Concurrency

`WORKER_CONCURRENCY` controls how many jobs run in parallel on the worker.
Default: 4

- Increase for faster processing (if droplet has resources)
- Decrease if seeing memory issues

### OpenAI Concurrency

`OPENAI_MAX_CONCURRENCY` controls concurrent OpenAI API calls.
Default: 2

- Keep low to avoid rate limits
- Worker uses exponential backoff + retry automatically

## PDF Processing

The worker can handle large PDFs that would crash Edge Functions:

- Downloads PDFs to temp files (streaming, bounded)
- Extracts text with pdf-parse
- Filters to relevant content before GPT

Limits (configurable via env):
- `REGS_PDF_MAX_BYTES`: 40MB (vs 12MB on Edge)
- `REGS_PDF_MAX_TEXT_CHARS`: 600K
- `REGS_PDF_MAX_CONTEXT_CHARS`: 60K

## Monitoring

### Check for stuck jobs

```sql
-- Jobs running for more than 10 minutes
SELECT * FROM regs_jobs
WHERE status = 'running'
AND started_at < NOW() - INTERVAL '10 minutes';
```

### Check run progress

```sql
SELECT
  r.id,
  r.type,
  r.tier,
  r.status,
  r.progress_done,
  r.progress_total,
  r.last_state,
  COUNT(j.id) FILTER (WHERE j.status = 'done') AS done,
  COUNT(j.id) FILTER (WHERE j.status = 'failed') AS failed,
  COUNT(j.id) FILTER (WHERE j.status = 'skipped') AS skipped
FROM regs_admin_runs r
LEFT JOIN regs_jobs j ON j.run_id = r.id
WHERE r.created_at > NOW() - INTERVAL '1 day'
GROUP BY r.id
ORDER BY r.created_at DESC;
```

### View job events

```sql
SELECT
  j.state_code,
  j.species,
  e.level,
  e.message,
  e.created_at
FROM regs_job_events e
JOIN regs_jobs j ON j.id = e.job_id
ORDER BY e.created_at DESC
LIMIT 50;
```

## Troubleshooting

### Worker not claiming jobs

1. Check worker is running: `systemctl status regs-worker`
2. Check for queued jobs: `SELECT COUNT(*) FROM regs_jobs WHERE status = 'queued'`
3. Check run is active: `SELECT * FROM regs_admin_runs WHERE status IN ('queued', 'running')`
4. Check logs for errors: `journalctl -u regs-worker -n 50`

### Rate limit errors

1. Reduce `OPENAI_MAX_CONCURRENCY` (e.g., to 1)
2. Increase `OPENAI_MAX_RETRIES` (e.g., to 10)
3. Check OpenAI usage dashboard

### Memory issues

1. Reduce `WORKER_CONCURRENCY` (e.g., to 2)
2. Lower PDF limits if needed
3. Check droplet memory: `free -m`

### Jobs stuck in "running"

May happen if worker crashed mid-job. Reset stuck jobs:

```sql
UPDATE regs_jobs
SET status = 'queued', locked_at = NULL, locked_by = NULL
WHERE status = 'running'
AND started_at < NOW() - INTERVAL '15 minutes';
```

## Recent Changes (January 2026)

### v1.3 - Crawler Robustness & Graceful Shutdown

- **NO_PAGES_FOUND fallback**: When crawler finds no candidate pages, stores official root URL as misc_related (marks job as success, not skipped)
- **Improved link extraction**: Now captures data-href, data-url, onclick handlers
- **Sitemap.xml fallback**: If <3 candidates found, tries sitemap.xml for regs-related URLs
- **Graceful shutdown**: Proper SIGTERM handling with 150s timeout for active jobs
- **systemd improvements**: TimeoutStopSec=180, KillMode=mixed, RestartSec=3

### v1.2 - PDF Support & Fallback Selection

- **PDF URLs**: Stores hunting_regs_pdf_url and fishing_regs_pdf_url
- **misc_related_urls**: JSONB array for fallback links when HTML/PDF unsure
- **Fallback heuristics**: When GPT fails, uses keyword matching to select best candidates
- **Streaming PDF download**: Avoids memory issues with large PDFs

### v1.1 - Strict JSON & Rate Limiting

- **Strict DiscoveryOutput schema**: Required fields, evidence snippets, domain validation
- **Rate limit handling**: Exponential backoff with jitter, Retry-After parsing
- **PromisePool**: OpenAI concurrency limiting

## Worker Files

```
worker/regs_worker/
├── src/
│   ├── index.ts        # Main entry, job loop, shutdown handling
│   ├── config.ts       # Environment config
│   ├── supabase.ts     # DB operations
│   ├── job_claim.ts    # Atomic job claiming
│   ├── discover.ts     # Discovery job processor
│   ├── extract.ts      # Extraction job processor
│   ├── crawler.ts      # Web crawler with sitemap fallback
│   ├── openai.ts       # OpenAI wrapper with retry
│   ├── pdf.ts          # PDF download and parsing
│   └── limiter.ts      # PromisePool, sleep utilities
├── package.json
├── tsconfig.json
├── regs-worker.service # systemd unit file
└── env.example.txt
```

## Updating the Worker

To deploy a new version of the worker:

```bash
# SSH to droplet
ssh root@165.245.131.150

# Navigate to repo and pull latest
cd /opt/regs_worker_repo
git pull origin main

# Rebuild
cd worker/regs_worker
npm install
npm run build

# Copy to deploy location
cp -r dist/* /opt/regs_worker/dist/

# Update systemd service file if changed
cp regs-worker.service /etc/systemd/system/
systemctl daemon-reload

# Restart worker
systemctl restart regs-worker

# Verify running
systemctl status regs-worker
journalctl -u regs-worker -f
```

## Worker Hardening (v1.2)

### Heartbeat Logging

Worker logs heartbeat every 30 seconds:
```
[Worker] Heartbeat: slots=6 active=2 done=4 claimed_last_30s=3 total_claimed=15 total_completed=13 loops=45
```

This provides visibility without SSH. Heartbeats are also stored in `regs_worker_heartbeats` table for UI.

### Crash Protection

- `unhandledRejection` and `uncaughtException` handlers catch all errors
- Worker exits with code 1 for systemd restart
- No silent hangs - always logs before exit

### Slot Cleanup Fix

**Bug fixed**: Previous version used broken `Promise.race` logic that never cleaned up completed job slots. Worker would claim 6 jobs, complete them, then stop claiming more (slots array never shrank).

**Fix**: Explicit `done` flag on each slot, checked synchronously in cleanup loop.

### Systemd Settings

```ini
Restart=always
RestartSec=2
StartLimitIntervalSec=300
StartLimitBurst=10
```

Worker automatically restarts on any crash. Rate-limited to 10 restarts in 5 minutes to prevent thrashing.

### Health Check

Worker performs DB health check every 50 loops (~100 seconds):
```
[Worker] Health check OK: DB latency 45ms
```

If health check fails, it's logged but worker continues - avoids false positives from transient network issues.

### UI Health Indicator

Admin UI shows worker health status:
- **Green**: Healthy (heartbeat < 60s ago)
- **Yellow**: Stale (60-120s since heartbeat)
- **Red**: Offline (> 120s since heartbeat)

Click to refresh. Shows active job count when running.

## Database RPCs

### Job Queue Management

| RPC | Description |
|-----|-------------|
| `regs_claim_job(worker_id)` | Atomic job claim with auto-unstick and auto-resume |
| `regs_complete_job(...)` | Mark job done/failed/skipped, update run progress |
| `regs_admin_requeue_run(run_id)` | Unstick stuck jobs, clear stale locks |
| `regs_admin_force_restart_run(run_id)` | Requeue all non-terminal jobs |
| `regs_get_worker_health()` | Get worker heartbeat status for UI |

### Self-Healing Behavior

1. **Auto-unstick**: Jobs running > 15 min are requeued on next claim
2. **Auto-resume**: Stalled runs (queued/stopped with pending jobs) resume automatically
3. **Lock clearing**: Terminal jobs have locks cleared to prevent false positives
