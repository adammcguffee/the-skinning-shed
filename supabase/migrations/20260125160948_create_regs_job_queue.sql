-- ============================================================
-- REGS JOB QUEUE TABLES
-- For running discovery/extraction on a worker service
-- ============================================================

-- Main runs table (admin-triggered runs)
CREATE TABLE IF NOT EXISTS regs_admin_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('discover', 'extract', 'verify', 'repair')),
  tier TEXT NOT NULL DEFAULT 'basic' CHECK (tier IN ('basic', 'pro')),
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'stopping', 'stopped', 'completed', 'failed')),
  progress_done INT NOT NULL DEFAULT 0,
  progress_total INT NOT NULL DEFAULT 0,
  last_message TEXT,
  last_state TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  stopped_at TIMESTAMPTZ
);

-- Individual jobs (one per state or state+species)
CREATE TABLE IF NOT EXISTS regs_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id UUID NOT NULL REFERENCES regs_admin_runs(id) ON DELETE CASCADE,
  job_type TEXT NOT NULL CHECK (job_type IN ('discover_state', 'extract_state_species')),
  state_code TEXT NOT NULL,
  species TEXT CHECK (species IS NULL OR species IN ('deer', 'turkey')),
  tier TEXT NOT NULL DEFAULT 'basic' CHECK (tier IN ('basic', 'pro')),
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'done', 'failed', 'skipped', 'canceled')),
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 2,
  locked_at TIMESTAMPTZ,
  locked_by TEXT,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  skip_reason TEXT,
  error_message TEXT,
  result_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Job event logs (for debugging)
CREATE TABLE IF NOT EXISTS regs_job_events (
  id BIGSERIAL PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES regs_jobs(id) ON DELETE CASCADE,
  level TEXT NOT NULL DEFAULT 'info' CHECK (level IN ('info', 'warn', 'error')),
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_regs_jobs_run_status ON regs_jobs(run_id, status);
CREATE INDEX IF NOT EXISTS idx_regs_jobs_status_locked ON regs_jobs(status, locked_at);
CREATE INDEX IF NOT EXISTS idx_regs_jobs_state_species ON regs_jobs(state_code, species);
CREATE INDEX IF NOT EXISTS idx_regs_admin_runs_status ON regs_admin_runs(status);
CREATE INDEX IF NOT EXISTS idx_regs_job_events_job ON regs_job_events(job_id);

-- RLS Policies
ALTER TABLE regs_admin_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE regs_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE regs_job_events ENABLE ROW LEVEL SECURITY;

-- Admin read access
CREATE POLICY "regs_admin_runs_select" ON regs_admin_runs
  FOR SELECT USING (true);

CREATE POLICY "regs_jobs_select" ON regs_jobs
  FOR SELECT USING (true);

CREATE POLICY "regs_job_events_select" ON regs_job_events
  FOR SELECT USING (true);

-- Service role write access (for edge functions and worker)
CREATE POLICY "regs_admin_runs_insert" ON regs_admin_runs
  FOR INSERT WITH CHECK (true);

CREATE POLICY "regs_admin_runs_update" ON regs_admin_runs
  FOR UPDATE USING (true);

CREATE POLICY "regs_jobs_insert" ON regs_jobs
  FOR INSERT WITH CHECK (true);

CREATE POLICY "regs_jobs_update" ON regs_jobs
  FOR UPDATE USING (true);

CREATE POLICY "regs_job_events_insert" ON regs_job_events
  FOR INSERT WITH CHECK (true);

-- ============================================================
-- RPC: Claim a job atomically (for worker)
-- ============================================================
CREATE OR REPLACE FUNCTION regs_claim_job(p_worker_id TEXT)
RETURNS SETOF regs_jobs
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job regs_jobs;
BEGIN
  -- Find and claim one queued job atomically
  UPDATE regs_jobs
  SET 
    status = 'running',
    locked_at = NOW(),
    locked_by = p_worker_id,
    started_at = NOW(),
    attempts = attempts + 1,
    updated_at = NOW()
  WHERE id = (
    SELECT j.id 
    FROM regs_jobs j
    JOIN regs_admin_runs r ON r.id = j.run_id
    WHERE j.status = 'queued'
      AND r.status IN ('running', 'queued')
    ORDER BY j.created_at
    FOR UPDATE OF j SKIP LOCKED
    LIMIT 1
  )
  RETURNING * INTO v_job;
  
  IF v_job.id IS NOT NULL THEN
    RETURN NEXT v_job;
  END IF;
  
  RETURN;
END;
$$;

-- ============================================================
-- RPC: Complete a job and update run progress
-- ============================================================
CREATE OR REPLACE FUNCTION regs_complete_job(
  p_job_id UUID,
  p_status TEXT,
  p_skip_reason TEXT DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL,
  p_result_json JSONB DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_run_id UUID;
  v_done_count INT;
  v_total_count INT;
  v_all_done BOOLEAN;
BEGIN
  -- Update the job
  UPDATE regs_jobs
  SET 
    status = p_status,
    finished_at = NOW(),
    skip_reason = p_skip_reason,
    error_message = p_error_message,
    result_json = p_result_json,
    updated_at = NOW()
  WHERE id = p_job_id
  RETURNING run_id INTO v_run_id;
  
  IF v_run_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Count completed jobs
  SELECT 
    COUNT(*) FILTER (WHERE status IN ('done', 'failed', 'skipped', 'canceled')),
    COUNT(*)
  INTO v_done_count, v_total_count
  FROM regs_jobs
  WHERE run_id = v_run_id;
  
  -- Check if all jobs are done
  v_all_done := NOT EXISTS (
    SELECT 1 FROM regs_jobs 
    WHERE run_id = v_run_id 
    AND status IN ('queued', 'running')
  );
  
  -- Update run progress
  UPDATE regs_admin_runs
  SET 
    progress_done = v_done_count,
    last_state = (SELECT state_code FROM regs_jobs WHERE id = p_job_id),
    last_message = CASE 
      WHEN p_status = 'done' THEN 'Completed'
      WHEN p_status = 'skipped' THEN COALESCE(p_skip_reason, 'Skipped')
      WHEN p_status = 'failed' THEN COALESCE(p_error_message, 'Failed')
      ELSE p_status
    END,
    status = CASE 
      WHEN v_all_done AND status = 'stopping' THEN 'stopped'
      WHEN v_all_done THEN 'completed'
      ELSE status
    END,
    updated_at = NOW()
  WHERE id = v_run_id;
END;
$$;
