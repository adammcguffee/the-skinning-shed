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
