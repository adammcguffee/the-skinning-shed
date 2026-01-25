-- ============================================================
-- AUTO-RESUME DISCOVERY MECHANISM
-- Ensures runs with queued jobs are always in 'running' state
-- ============================================================

-- RPC: Auto-resume any discovery run that has queued jobs but is not running
-- This can be called periodically or before claiming jobs
CREATE OR REPLACE FUNCTION regs_auto_resume_discovery()
RETURNS TABLE (
  run_id UUID,
  previous_status TEXT,
  jobs_queued INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH stalled_runs AS (
    SELECT 
      r.id,
      r.status as prev_status,
      COUNT(*) FILTER (WHERE j.status = 'queued') as queued_count
    FROM regs_admin_runs r
    JOIN regs_jobs j ON j.run_id = r.id
    WHERE r.type = 'discover'
      AND r.status NOT IN ('running', 'completed', 'failed')
      AND j.job_type = 'discover_state'
    GROUP BY r.id, r.status
    HAVING COUNT(*) FILTER (WHERE j.status = 'queued') > 0
  ),
  updated AS (
    UPDATE regs_admin_runs 
    SET status = 'running', updated_at = NOW()
    WHERE id IN (SELECT id FROM stalled_runs)
    RETURNING id
  )
  SELECT 
    s.id as run_id,
    s.prev_status as previous_status,
    s.queued_count::INTEGER as jobs_queued
  FROM stalled_runs s
  WHERE s.id IN (SELECT id FROM updated);
END;
$$;

-- Update regs_claim_job to auto-resume stalled runs before claiming
CREATE OR REPLACE FUNCTION regs_claim_job(p_worker_id TEXT)
RETURNS SETOF regs_jobs
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job regs_jobs;
BEGIN
  -- First, auto-resume any stalled discovery runs
  UPDATE regs_admin_runs r
  SET status = 'running', updated_at = NOW()
  WHERE r.type = 'discover'
    AND r.status NOT IN ('running', 'completed', 'failed', 'stopping')
    AND EXISTS (
      SELECT 1 FROM regs_jobs j 
      WHERE j.run_id = r.id 
      AND j.status = 'queued'
      AND j.job_type = 'discover_state'
    );

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

-- Update regs_enqueue_discovery_all_states to always set status='running'
CREATE OR REPLACE FUNCTION regs_enqueue_discovery_all_states(
  p_run_id UUID,
  p_tier TEXT DEFAULT 'pro'
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted_count INTEGER;
  v_states TEXT[] := ARRAY[
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];
BEGIN
  -- Ensure run exists
  IF NOT EXISTS (SELECT 1 FROM regs_admin_runs WHERE id = p_run_id) THEN
    RAISE EXCEPTION 'Run % does not exist', p_run_id;
  END IF;

  -- ALWAYS set run status to 'running' when enqueueing
  UPDATE regs_admin_runs
  SET 
    status = 'running',
    progress_total = 50,
    updated_at = NOW()
  WHERE id = p_run_id;

  -- Insert jobs for all 50 states, skipping duplicates
  INSERT INTO regs_jobs (run_id, job_type, state_code, tier, status, attempts, max_attempts)
  SELECT 
    p_run_id,
    'discover_state',
    unnest(v_states),
    p_tier,
    'queued',
    0,
    3
  ON CONFLICT (run_id, job_type, state_code) DO NOTHING;

  GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

  RETURN v_inserted_count;
END;
$$;

-- Also ensure completed status is only set when ALL jobs are terminal
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
  v_queued_count INT;
  v_running_count INT;
  v_all_terminal BOOLEAN;
BEGIN
  -- Update the job
  UPDATE regs_jobs
  SET 
    status = p_status,
    finished_at = NOW(),
    skip_reason = p_skip_reason,
    error_message = p_error_message,
    result_json = p_result_json,
    locked_at = NULL,
    locked_by = NULL,
    updated_at = NOW()
  WHERE id = p_job_id
  RETURNING run_id INTO v_run_id;
  
  IF v_run_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Count jobs by status
  SELECT 
    COUNT(*) FILTER (WHERE status IN ('done', 'failed', 'skipped', 'canceled')),
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'queued'),
    COUNT(*) FILTER (WHERE status = 'running')
  INTO v_done_count, v_total_count, v_queued_count, v_running_count
  FROM regs_jobs
  WHERE run_id = v_run_id;
  
  -- All terminal = no queued AND no running
  v_all_terminal := (v_queued_count = 0 AND v_running_count = 0);
  
  -- Update run progress
  UPDATE regs_admin_runs
  SET 
    progress_done = v_done_count,
    progress_total = GREATEST(progress_total, v_total_count, 50),
    last_state = (SELECT state_code FROM regs_jobs WHERE id = p_job_id),
    last_message = CASE 
      WHEN p_status = 'done' THEN 'Completed'
      WHEN p_status = 'skipped' THEN COALESCE(p_skip_reason, 'Skipped')
      WHEN p_status = 'failed' THEN COALESCE(p_error_message, 'Failed')
      ELSE p_status
    END,
    -- ONLY set completed/stopped when ALL jobs are terminal
    status = CASE 
      WHEN v_all_terminal AND status = 'stopping' THEN 'stopped'
      WHEN v_all_terminal AND status = 'running' THEN 'completed'
      ELSE status  -- Keep current status if jobs still pending
    END,
    updated_at = NOW()
  WHERE id = v_run_id;
END;
$$;
