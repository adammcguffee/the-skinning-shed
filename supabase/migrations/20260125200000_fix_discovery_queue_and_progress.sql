-- ============================================================
-- FIX DISCOVERY QUEUE AND PROGRESS
-- Ensures all 50 states are queued and progress is accurate
-- ============================================================

-- Add unique constraint to prevent duplicate jobs
-- This ensures we can safely enqueue all states without duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_regs_jobs_unique_run_type_state 
ON regs_jobs(run_id, job_type, state_code);

-- ============================================================
-- RPC: Enqueue discovery jobs for all 50 US states
-- ============================================================
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
  v_state_code TEXT;
  v_states TEXT[] := ARRAY[
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];
BEGIN
  -- Ensure run exists and is in a valid state
  IF NOT EXISTS (SELECT 1 FROM regs_admin_runs WHERE id = p_run_id) THEN
    RAISE EXCEPTION 'Run % does not exist', p_run_id;
  END IF;

  -- Insert jobs for all 50 states, skipping duplicates
  INSERT INTO regs_jobs (run_id, job_type, state_code, tier, status, attempts, max_attempts)
  SELECT 
    p_run_id,
    'discover_state',
    unnest(v_states),
    p_tier,
    'queued',
    0,
    3  -- Allow up to 3 attempts per job
  ON CONFLICT (run_id, job_type, state_code) DO NOTHING;

  GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

  -- Update run progress_total to 50 (expected states)
  UPDATE regs_admin_runs
  SET 
    progress_total = 50,
    updated_at = NOW()
  WHERE id = p_run_id;

  RETURN v_inserted_count;
END;
$$;

-- ============================================================
-- RPC: Get accurate discovery progress for a run
-- ============================================================
CREATE OR REPLACE FUNCTION regs_get_discovery_progress(p_run_id UUID)
RETURNS TABLE (
  total_expected INTEGER,
  done_count INTEGER,
  running_count INTEGER,
  queued_count INTEGER,
  failed_count INTEGER,
  skipped_count INTEGER,
  canceled_count INTEGER,
  last_update TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    50::INTEGER AS total_expected,  -- Always 50 states for discovery
    COUNT(*) FILTER (WHERE status = 'done')::INTEGER AS done_count,
    COUNT(*) FILTER (WHERE status = 'running')::INTEGER AS running_count,
    COUNT(*) FILTER (WHERE status = 'queued')::INTEGER AS queued_count,
    COUNT(*) FILTER (WHERE status = 'failed')::INTEGER AS failed_count,
    COUNT(*) FILTER (WHERE status = 'skipped')::INTEGER AS skipped_count,
    COUNT(*) FILTER (WHERE status = 'canceled')::INTEGER AS canceled_count,
    MAX(updated_at) AS last_update
  FROM regs_jobs
  WHERE run_id = p_run_id
    AND job_type = 'discover_state';
END;
$$;

-- ============================================================
-- Update regs_complete_job to also update progress_total
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
  
  -- Update run progress (ensure progress_total is at least 50 for discovery runs)
  UPDATE regs_admin_runs
  SET 
    progress_done = v_done_count,
    progress_total = GREATEST(progress_total, 50),  -- Ensure at least 50 for discovery
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
