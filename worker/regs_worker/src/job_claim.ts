/**
 * Job claiming and completion logic.
 * Uses PostgreSQL FOR UPDATE SKIP LOCKED for atomic job acquisition.
 */
import { getSupabaseClient, RegsJob } from './supabase';

/**
 * Atomically claim a queued job for processing.
 * Uses the regs_claim_job RPC which does:
 * - SELECT FOR UPDATE SKIP LOCKED on regs_jobs
 * - Marks job as 'running' with locked_at/locked_by
 * - Increments attempts counter
 * - Returns the claimed job or null if none available
 */
export async function claimJob(workerId: string): Promise<RegsJob | null> {
  const client = getSupabaseClient();
  
  const { data, error } = await client.rpc('regs_claim_job', {
    p_worker_id: workerId,
  });

  if (error) {
    console.error('[JobClaim] Error claiming job:', error.message);
    return null;
  }

  if (!data || data.length === 0) {
    return null;
  }

  return data[0] as RegsJob;
}

/**
 * Mark a job as completed (done/failed/skipped/canceled).
 * Also updates the parent run's progress counters.
 */
export async function completeJob(
  jobId: string,
  status: 'done' | 'failed' | 'skipped' | 'canceled',
  options: {
    skipReason?: string;
    errorMessage?: string;
    resultJson?: unknown;
  } = {}
): Promise<void> {
  const client = getSupabaseClient();

  const { error } = await client.rpc('regs_complete_job', {
    p_job_id: jobId,
    p_status: status,
    p_skip_reason: options.skipReason || null,
    p_error_message: options.errorMessage?.slice(0, 1000) || null,
    p_result_json: options.resultJson || null,
  });

  if (error) {
    console.error('[JobClaim] Error completing job:', error.message);
  }
}

/**
 * Check if we should continue processing jobs for a run.
 * Returns false if run status is 'stopping' or 'stopped'.
 */
export async function shouldContinueRun(runId: string): Promise<boolean> {
  const client = getSupabaseClient();

  const { data, error } = await client
    .from('regs_admin_runs')
    .select('status')
    .eq('id', runId)
    .single();

  if (error || !data) {
    return false;
  }

  return !['stopping', 'stopped', 'completed', 'failed'].includes(data.status);
}
