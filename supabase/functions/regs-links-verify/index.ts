import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * regs-links-verify Edge Function
 * 
 * Verifies all portal links weekly to catch broken URLs.
 * Updates status codes for each link field.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const VERIFY_TIMEOUT = 10000;

interface VerifyResult {
  url: string;
  field: string;
  status: number | null;
  error?: string;
}

async function verifyUrl(url: string | null | undefined, field: string): Promise<VerifyResult> {
  if (!url || url.trim() === '') {
    return { url: '', field, status: null };
  }
  
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), VERIFY_TIMEOUT);
    
    // Use HEAD request first (faster)
    const response = await fetch(url, {
      method: 'HEAD',
      headers: { "User-Agent": "TheSkinning Shed Link Verifier/1.0" },
      signal: controller.signal,
      redirect: 'follow'
    });
    clearTimeout(timeout);
    
    return { url, field, status: response.status };
  } catch (error) {
    // Fallback to GET if HEAD fails
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), VERIFY_TIMEOUT);
      
      const response = await fetch(url, {
        method: 'GET',
        headers: { "User-Agent": "TheSkinning Shed Link Verifier/1.0" },
        signal: controller.signal,
        redirect: 'follow'
      });
      clearTimeout(timeout);
      
      return { url, field, status: response.status };
    } catch (getError) {
      const errorMsg = getError instanceof Error ? getError.message : String(getError);
      return { url, field, status: null, error: errorMsg.substring(0, 100) };
    }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, { auth: { persistSession: false } });
    
    const { data: states, error: statesError } = await supabase
      .from('state_portal_links')
      .select('*')
      .order('state_code');
    
    if (statesError) throw new Error(`Failed to fetch states: ${statesError.message}`);
    if (!states || states.length === 0) {
      return new Response(JSON.stringify({ message: 'No portal links to verify' }), 
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    
    const now = new Date().toISOString();
    let totalChecked = 0;
    let totalOk = 0;
    let totalBroken = 0;
    const brokenLinks: any[] = [];
    
    for (const state of states) {
      const results = await Promise.all([
        verifyUrl(state.hunting_seasons_url, 'hunting_seasons'),
        verifyUrl(state.hunting_regs_url, 'hunting_regs'),
        verifyUrl(state.fishing_regs_url, 'fishing_regs'),
        verifyUrl(state.licensing_url, 'licensing'),
        verifyUrl(state.buy_license_url, 'buy_license'),
        verifyUrl(state.records_url, 'records'),
      ]);
      
      const updates: any = { last_verified_at: now };
      
      for (const result of results) {
        if (result.url === '') continue; // Skip empty URLs
        
        totalChecked++;
        const statusField = `${result.field}_status`;
        updates[statusField] = result.status;
        
        if (result.status === 200) {
          totalOk++;
        } else {
          totalBroken++;
          brokenLinks.push({
            state: state.state_code,
            state_name: state.state_name,
            field: result.field,
            url: result.url,
            status: result.status,
            error: result.error
          });
        }
      }
      
      await supabase.from('state_portal_links')
        .update(updates)
        .eq('state_code', state.state_code);
    }
    
    return new Response(JSON.stringify({
      message: 'Link verification complete',
      states_checked: states.length,
      total_links_checked: totalChecked,
      ok: totalOk,
      broken: totalBroken,
      broken_links: brokenLinks,
      verified_at: now
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    
  } catch (error) {
    console.error('regs-links-verify error:', error);
    return new Response(JSON.stringify({ error: (error as Error).message }), 
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
