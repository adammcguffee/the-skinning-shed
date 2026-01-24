import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * regs-discovery-start Edge Function
 * 
 * Starts a new discovery run for all 50 states.
 * Creates a reg_discovery_runs record and returns the run_id.
 * The actual discovery is done by regs-discovery-continue in batches.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    
    // Verify admin auth
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Not authenticated',
        error_code: 'NO_AUTH',
        hint: 'Please log in to access admin functions.',
      }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    const supabaseAuth = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false }
    });
    
    const { data: { user }, error: userError } = await supabaseAuth.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid or expired session',
        error_code: 'INVALID_SESSION',
        hint: 'Your session has expired. Please log out and log back in.',
      }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    const { data: profile, error: profileError } = await supabaseAuth
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();
    
    if (profileError || !profile?.is_admin) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Admin access required',
        error_code: 'NOT_ADMIN',
        hint: 'This function is restricted to administrators.',
      }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    // Use service role for operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    });

    // Check for existing running discovery
    const { data: existingRun } = await supabase
      .from('reg_discovery_runs')
      .select('id, status, processed, total')
      .eq('status', 'running')
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (existingRun) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Discovery already in progress',
        error_code: 'ALREADY_RUNNING',
        hint: 'Wait for the current discovery to complete or cancel it.',
        run_id: existingRun.id,
        processed: existingRun.processed,
        total: existingRun.total,
      }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Get total state count
    const { count: stateCount } = await supabase
      .from('state_official_roots')
      .select('*', { count: 'exact', head: true });

    const total = stateCount || 50;

    // Parse optional batch_size from request
    let batchSize = 5;
    try {
      const body = await req.json();
      if (body.batch_size && body.batch_size >= 1 && body.batch_size <= 10) {
        batchSize = body.batch_size;
      }
    } catch {
      // No body or invalid JSON, use defaults
    }

    // Create new discovery run
    const { data: run, error: runError } = await supabase
      .from('reg_discovery_runs')
      .insert({
        status: 'running',
        total,
        processed: 0,
        batch_size: batchSize,
        cursor_pos: 0,
        created_by: user.id,
        stats_ok: 0,
        stats_skipped: 0,
        stats_error: 0,
      })
      .select()
      .single();

    if (runError || !run) {
      throw new Error(`Failed to create discovery run: ${runError?.message}`);
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Discovery run started',
      run_id: run.id,
      status: run.status,
      total: run.total,
      batch_size: run.batch_size,
      started_at: run.started_at,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('regs-discovery-start error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: (error as Error).message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
