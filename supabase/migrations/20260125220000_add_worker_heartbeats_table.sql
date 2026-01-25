-- ============================================================
-- WORKER HEARTBEATS TABLE
-- Stores worker health status for UI visibility
-- ============================================================

CREATE TABLE IF NOT EXISTS regs_worker_heartbeats (
  worker_id TEXT PRIMARY KEY,
  active_jobs INT DEFAULT 0,
  total_claimed INT DEFAULT 0,
  total_completed INT DEFAULT 0,
  last_heartbeat TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick lookup of stale workers
CREATE INDEX IF NOT EXISTS idx_worker_heartbeats_last 
ON regs_worker_heartbeats(last_heartbeat DESC);

-- Allow public read for UI, but only service role can write
ALTER TABLE regs_worker_heartbeats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read worker heartbeats" ON regs_worker_heartbeats
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage heartbeats" ON regs_worker_heartbeats
  FOR ALL USING (true) WITH CHECK (true);

-- Function to get worker health status
CREATE OR REPLACE FUNCTION regs_get_worker_health()
RETURNS TABLE (
  worker_id TEXT,
  active_jobs INT,
  total_claimed INT,
  total_completed INT,
  last_heartbeat TIMESTAMPTZ,
  seconds_since_heartbeat INT,
  is_healthy BOOLEAN
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
    EXTRACT(EPOCH FROM (NOW() - h.last_heartbeat))::INT as seconds_since_heartbeat,
    (NOW() - h.last_heartbeat) < INTERVAL '60 seconds' as is_healthy
  FROM regs_worker_heartbeats h
  ORDER BY h.last_heartbeat DESC;
$$;
