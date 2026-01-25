/**
 * Supabase client and database helpers for the regulations worker.
 */
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { config } from './config';

let client: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (!client) {
    client = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });
  }
  return client;
}

export interface RegsJob {
  id: string;
  run_id: string;
  job_type: 'discover_state' | 'extract_state_species';
  state_code: string;
  species: 'deer' | 'turkey' | null;
  tier: 'basic' | 'pro';
  status: 'queued' | 'running' | 'done' | 'failed' | 'skipped' | 'canceled';
  attempts: number;
  max_attempts: number;
  locked_at: string | null;
  locked_by: string | null;
  started_at: string | null;
  finished_at: string | null;
  skip_reason: string | null;
  error_message: string | null;
  result_json: unknown;
  created_at: string;
  updated_at: string;
}

export interface RegsAdminRun {
  id: string;
  type: 'discover' | 'extract' | 'verify' | 'repair';
  tier: 'basic' | 'pro';
  status: 'queued' | 'running' | 'stopping' | 'stopped' | 'completed' | 'failed';
  progress_done: number;
  progress_total: number;
  last_message: string | null;
  last_state: string | null;
  error_message: string | null;
  created_at: string;
  updated_at: string;
  stopped_at: string | null;
}

export async function getRunStatus(runId: string): Promise<RegsAdminRun['status'] | null> {
  const client = getSupabaseClient();

  const { data, error } = await client
    .from('regs_admin_runs')
    .select('status')
    .eq('id', runId)
    .single();

  if (error || !data) {
    return null;
  }

  return data.status as RegsAdminRun['status'];
}

export async function logJobEvent(
  jobId: string,
  level: 'info' | 'warn' | 'error',
  message: string
): Promise<void> {
  const client = getSupabaseClient();

  await client.from('regs_job_events').insert({
    job_id: jobId,
    level,
    message: message.slice(0, 2000),
  });
}

export async function getStateOfficialRoot(stateCode: string): Promise<{
  official_root_url: string;
  official_domain: string;
  state_name: string;
} | null> {
  const client = getSupabaseClient();

  const { data, error } = await client
    .from('state_official_roots')
    .select('official_root_url, official_domain, state_name')
    .eq('state_code', stateCode)
    .single();

  if (error || !data) {
    return null;
  }

  return data;
}

export async function getPortalLinks(stateCode: string): Promise<Record<string, unknown> | null> {
  const client = getSupabaseClient();

  const { data, error } = await client
    .from('state_portal_links')
    .select('*')
    .eq('state_code', stateCode)
    .single();

  if (error || !data) {
    return null;
  }

  return data;
}

export async function updatePortalLinks(
  stateCode: string,
  updates: Record<string, unknown>
): Promise<void> {
  const client = getSupabaseClient();

  await client
    .from('state_portal_links')
    .update({
      ...updates,
      updated_at: new Date().toISOString(),
    })
    .eq('state_code', stateCode);
}

export async function upsertExtractedRegulations(data: {
  state_code: string;
  species_group: string;
  region_key: string;
  season_year_label: string;
  source_url: string;
  confidence_score: number;
  data: unknown;
  model_used: string;
  tier_used: string;
  citations: unknown;
  status: string;
}): Promise<void> {
  const client = getSupabaseClient();

  await client.from('state_regulations_extracted').upsert(data, {
    onConflict: 'state_code,species_group,region_key,season_year_label',
  });
}

/**
 * Record worker heartbeat to Supabase for UI visibility.
 * Uses upsert to regs_worker_heartbeats table.
 */
export async function recordWorkerHeartbeat(
  workerId: string,
  stats: {
    active_jobs: number;
    total_claimed: number;
    total_completed: number;
    last_claim_at: Date | null;
    last_progress_at: Date | null;
    hostname: string;
    version: string;
    loops_count: number;
  }
): Promise<void> {
  const client = getSupabaseClient();

  await client.from('regs_worker_heartbeats').upsert(
    {
      worker_id: workerId,
      active_jobs: stats.active_jobs,
      total_claimed: stats.total_claimed,
      total_completed: stats.total_completed,
      last_heartbeat: new Date().toISOString(),
      last_claim_at: stats.last_claim_at?.toISOString() || null,
      last_progress_at: stats.last_progress_at?.toISOString() || null,
      hostname: stats.hostname,
      version: stats.version,
      loops_count: stats.loops_count,
    },
    { onConflict: 'worker_id' }
  );
}

/**
 * Check for pending admin commands.
 */
export async function checkForCommands(workerId: string): Promise<Array<{
  id: string;
  command: string;
  created_at: string;
}>> {
  const client = getSupabaseClient();

  const { data, error } = await client.rpc('regs_get_pending_commands', {
    p_worker_id: workerId,
  });

  if (error || !data) {
    return [];
  }

  return data as Array<{ id: string; command: string; created_at: string }>;
}

/**
 * Acknowledge a command as processed.
 */
export async function ackCommand(
  commandId: string,
  workerId: string,
  result: string
): Promise<void> {
  const client = getSupabaseClient();

  await client.rpc('regs_ack_command', {
    p_command_id: commandId,
    p_worker_id: workerId,
    p_result: result,
  });
}
