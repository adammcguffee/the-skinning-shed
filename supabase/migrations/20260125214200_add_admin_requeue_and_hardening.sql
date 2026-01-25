-- ============================================================
-- ADMIN REQUEUE RPC + HARDENING
-- Allows unsticking jobs and ensures self-healing
-- ============================================================

-- Admin RPC: Requeue stuck jobs in a run
-- Resets jobs that have been running for too long (stuck)
-- Clears stale locks from done jobs
CREATE OR REPLACE FUNCTION regs_admin_requeue_run(
  p_run_id UUID,
  p_stuck_minutes INT DEFAULT 15
)
RETURNS TABLE (
  requeued_stuck INT,
  locks_cleared INT,
  run_status_set TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requeued INT := 0;
  v_cleared INT := 0;
BEGIN
  -- 1) Requeue jobs stuck in 'running' status for too long
  WITH stuck AS (
    UPDATE regs_jobs
    SET 
      status = 'queued',
      locked_at = NULL,
      locked_by = NULL,
      started_at = NULL,
      updated_at = NOW()
    WHERE run_id = p_run_id
      AND status = 'running'
      AND locked_at < NOW() - (p_stuck_minutes || ' minutes')::INTERVAL
    RETURNING id
  )
  SELECT COUNT(*) INTO v_requeued FROM stuck;

  -- 2) Clear stale locks from terminal jobs (done/failed/skipped/canceled)
  WITH cleared AS (
    UPDATE regs_jobs
    SET 
      locked_at = NULL,
      locked_by = NULL,
      updated_at = NOW()
    WHERE run_id = p_run_id
      AND status IN ('done', 'failed', 'skipped', 'canceled')
      AND (locked_at IS NOT NULL OR locked_by IS NOT NULL)
    RETURNING id
  )
  SELECT COUNT(*) INTO v_cleared FROM cleared;

  -- 3) Ensure run status is 'running' if there are queued jobs
  UPDATE regs_admin_runs
  SET 
    status = 'running',
    updated_at = NOW()
  WHERE id = p_run_id
    AND status NOT IN ('completed', 'failed')
    AND EXISTS (
      SELECT 1 FROM regs_jobs 
      WHERE run_id = p_run_id AND status = 'queued'
    );

  RETURN QUERY SELECT v_requeued, v_cleared, 'running'::TEXT;
END;
$$;

-- Admin RPC: Force restart a run by requeuing all non-terminal jobs
CREATE OR REPLACE FUNCTION regs_admin_force_restart_run(p_run_id UUID)
RETURNS TABLE (
  jobs_requeued INT,
  run_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requeued INT := 0;
BEGIN
  -- Reset all non-terminal jobs to queued
  WITH reset AS (
    UPDATE regs_jobs
    SET 
      status = 'queued',
      locked_at = NULL,
      locked_by = NULL,
      started_at = NULL,
      finished_at = NULL,
      error_message = NULL,
      skip_reason = NULL,
      result_json = NULL,
      attempts = 0,
      updated_at = NOW()
    WHERE run_id = p_run_id
      AND status NOT IN ('done', 'skipped')  -- Keep successful completions
    RETURNING id
  )
  SELECT COUNT(*) INTO v_requeued FROM reset;

  -- Set run to running
  UPDATE regs_admin_runs
  SET 
    status = 'running',
    stopped_at = NULL,
    error_message = NULL,
    updated_at = NOW()
  WHERE id = p_run_id;

  RETURN QUERY SELECT v_requeued, 'running'::TEXT;
END;
$$;

-- Update claim_job to be more robust
CREATE OR REPLACE FUNCTION regs_claim_job(p_worker_id TEXT)
RETURNS SETOF regs_jobs
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job regs_jobs;
BEGIN
  -- Auto-clear stale locks (jobs stuck running > 15 min)
  UPDATE regs_jobs
  SET 
    status = 'queued',
    locked_at = NULL,
    locked_by = NULL,
    started_at = NULL,
    updated_at = NOW()
  WHERE status = 'running'
    AND locked_at < NOW() - INTERVAL '15 minutes';

  -- Auto-resume any stalled discovery runs (not running but have queued jobs)
  UPDATE regs_admin_runs r
  SET status = 'running', updated_at = NOW()
  WHERE r.type = 'discover'
    AND r.status NOT IN ('running', 'completed', 'failed', 'stopping')
    AND EXISTS (
      SELECT 1 FROM regs_jobs j 
      WHERE j.run_id = r.id 
      AND j.status = 'queued'
    );

  -- Find and claim one queued job atomically
  UPDATE regs_jobs
  SET 
    status = 'running',
    locked_at = NOW(),
    locked_by = p_worker_id,
    started_at = COALESCE(started_at, NOW()),
    attempts = COALESCE(attempts, 0) + 1,
    updated_at = NOW()
  WHERE id = (
    SELECT j.id 
    FROM regs_jobs j
    JOIN regs_admin_runs r ON r.id = j.run_id
    WHERE j.status = 'queued'
      AND j.attempts < j.max_attempts
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

-- Ensure complete_job clears locks properly
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
  -- Update the job and ALWAYS clear locks
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
      ELSE status
    END,
    updated_at = NOW()
  WHERE id = v_run_id;
END;
$$;
