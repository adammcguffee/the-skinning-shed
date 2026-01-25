# Regulations Worker Deployment Guide

This guide covers deploying the Regulations Worker service to a DigitalOcean droplet.

## Overview

The worker service processes regulations discovery and extraction jobs:
- **Discovery**: Crawls official state wildlife agency sites to find portal links
- **Extraction**: Parses HTML/PDFs to extract structured season data using GPT

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
