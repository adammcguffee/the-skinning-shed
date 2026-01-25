# Regulations Worker

Background worker service for processing regulations discovery and extraction jobs on a DigitalOcean droplet.

## Quick Start

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Run (requires .env with credentials)
npm start
```

## Development

```bash
# Run with ts-node (no build step)
npm run dev

# Watch mode (rebuild on changes)
npm run watch
```

## File Structure

```
src/
  index.ts      - Main entry point, worker loop
  config.ts     - Environment config, model router
  supabase.ts   - Supabase client, DB helpers
  job_claim.ts  - Atomic job claiming via RPC
  openai.ts     - OpenAI wrapper with retry/backoff
  limiter.ts    - Promise pool for concurrency
  crawler.ts    - Web crawler for official domains
  pdf.ts        - PDF download/parse (streaming to temp file)
  discover.ts   - Discovery job processor
  extract.ts    - Extraction job processor
```

## Configuration

Copy `env.example.txt` to `.env` and fill in:

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxx
OPENAI_API_KEY=sk-xxx
```

See `docs/REGS_WORKER_DEPLOY.md` for full deployment guide.

## Architecture

The worker:
1. Polls `regs_jobs` table for queued jobs
2. Claims jobs atomically using `regs_claim_job()` RPC
3. Processes discovery or extraction
4. Writes results back via `regs_complete_job()` RPC
5. Respects stop: if `regs_admin_runs.status='stopping'`, cancels remaining jobs

## Job Types

- **discover_state** - Crawl official site, find portal links via GPT
- **extract_state_species** - Parse HTML/PDF, extract season data via GPT

## Concurrency

- `WORKER_CONCURRENCY` (default 2) - Parallel job processing
- `OPENAI_MAX_CONCURRENCY` (default 1) - Parallel OpenAI API calls

## PDF Safety

PDFs are handled safely:
- Stream download to temp file (not in memory)
- Enforce `REGS_PDF_MAX_BYTES` (default 40MB)
- Parse from file, cleanup after
