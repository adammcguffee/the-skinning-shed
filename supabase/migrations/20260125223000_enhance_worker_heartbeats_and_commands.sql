-- ============================================================
-- ENHANCED WORKER HEARTBEATS + COMMAND SYSTEM
-- Enables stall detection and remote restart without SSH
-- ============================================================

-- Add new columns to heartbeats table
ALTER TABLE regs_worker_heartbeats 
ADD COLUMN IF NOT EXISTS last_claim_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_progress_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS hostname TEXT,
ADD COLUMN IF NOT EXISTS version TEXT,
ADD COLUMN IF NOT EXISTS loops_count INT DEFAULT 0;

-- Worker commands table for remote control
CREATE TABLE IF NOT EXISTS regs_worker_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  command TEXT NOT NULL CHECK (command IN ('restart', 'stop', 'pause')),
  target_worker_id TEXT, -- NULL means all workers
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  processed_by TEXT,
  result TEXT
);

-- Index for quick lookup of pending commands
CREATE INDEX IF NOT EXISTS idx_worker_commands_pending 
ON regs_worker_commands(created_at DESC) 
WHERE processed_at IS NULL;

-- RLS for commands
ALTER TABLE regs_worker_commands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read commands" ON regs_worker_commands;
CREATE POLICY "Anyone can read commands" ON regs_worker_commands
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Service role can manage commands" ON regs_worker_commands;
CREATE POLICY "Service role can manage commands" ON regs_worker_commands
  FOR ALL USING (true) WITH CHECK (true);

-- Function to issue a worker command
CREATE OR REPLACE FUNCTION regs_issue_worker_command(
  p_command TEXT,
  p_target_worker_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO regs_worker_commands (command, target_worker_id)
  VALUES (p_command, p_target_worker_id)
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$;

-- Function to get pending commands for a worker
CREATE OR REPLACE FUNCTION regs_get_pending_commands(p_worker_id TEXT)
RETURNS TABLE (
  id UUID,
  command TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id, command, created_at
  FROM regs_worker_commands
  WHERE processed_at IS NULL
    AND (target_worker_id IS NULL OR target_worker_id = p_worker_id)
    AND created_at > NOW() - INTERVAL '5 minutes'
  ORDER BY created_at ASC;
$$;

-- Function to acknowledge a command
CREATE OR REPLACE FUNCTION regs_ack_command(
  p_command_id UUID,
  p_worker_id TEXT,
  p_result TEXT DEFAULT 'acknowledged'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE regs_worker_commands
  SET 
    processed_at = NOW(),
    processed_by = p_worker_id,
    result = p_result
  WHERE id = p_command_id;
END;
$$;

-- Drop and recreate enhanced worker health function
DROP FUNCTION IF EXISTS regs_get_worker_health();

CREATE FUNCTION regs_get_worker_health()
RETURNS TABLE (
  worker_id TEXT,
  active_jobs INT,
  total_claimed INT,
  total_completed INT,
  last_heartbeat TIMESTAMPTZ,
  last_claim_at TIMESTAMPTZ,
  last_progress_at TIMESTAMPTZ,
  seconds_since_heartbeat INT,
  seconds_since_claim INT,
  seconds_since_progress INT,
  is_healthy BOOLEAN,
  is_stalled BOOLEAN,
  is_offline BOOLEAN,
  hostname TEXT,
  version TEXT,
  loops_count INT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    h.worker_id,
    h.active_jobs,
    h.total_claimed,
    h.total_completed,
    h.last_heartbeat,
    h.last_claim_at,
    h.last_progress_at,
    EXTRACT(EPOCH FROM (NOW() - h.last_heartbeat))::INT as seconds_since_heartbeat,
    COALESCE(EXTRACT(EPOCH FROM (NOW() - h.last_claim_at))::INT, 9999) as seconds_since_claim,
    COALESCE(EXTRACT(EPOCH FROM (NOW() - h.last_progress_at))::INT, 9999) as seconds_since_progress,
    -- Healthy: heartbeat within 60s
    (NOW() - h.last_heartbeat) < INTERVAL '60 seconds' as is_healthy,
    -- Stalled: heartbeat fresh but no progress for 180s
    (NOW() - h.last_heartbeat) < INTERVAL '60 seconds' 
      AND COALESCE((NOW() - h.last_progress_at), INTERVAL '0') > INTERVAL '180 seconds' as is_stalled,
    -- Offline: no heartbeat for 60s
    (NOW() - h.last_heartbeat) >= INTERVAL '60 seconds' as is_offline,
    h.hostname,
    h.version,
    h.loops_count
  FROM regs_worker_heartbeats h
  ORDER BY h.last_heartbeat DESC;
$$;
