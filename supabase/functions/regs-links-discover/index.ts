import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * regs-links-discover Edge Function
 * 
 * Auto-discovers official state wildlife agency URLs weekly.
 * Uses search API to find authoritative sources.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const FETCH_TIMEOUT = 10000;

interface StateAgencyInfo {
  stateCode: string;
  stateName: string;
  agencyName?: string;
}

const STATE_AGENCIES: Record<string, StateAgencyInfo> = {
  'AL': { stateCode: 'AL', stateName: 'Alabama', agencyName: 'Alabama DCNR' },
  'AK': { stateCode: 'AK', stateName: 'Alaska', agencyName: 'Alaska DFG' },
  'AZ': { stateCode: 'AZ', stateName: 'Arizona', agencyName: 'Arizona Game & Fish' },
  'AR': { stateCode: 'AR', stateName: 'Arkansas', agencyName: 'Arkansas GFC' },
  'CA': { stateCode: 'CA', stateName: 'California', agencyName: 'California DFW' },
  'CO': { stateCode: 'CO', stateName: 'Colorado', agencyName: 'Colorado Parks & Wildlife' },
  'CT': { stateCode: 'CT', stateName: 'Connecticut', agencyName: 'Connecticut DEEP' },
  'DE': { stateCode: 'DE', stateName: 'Delaware', agencyName: 'Delaware DFW' },
  'FL': { stateCode: 'FL', stateName: 'Florida', agencyName: 'Florida FWC' },
  'GA': { stateCode: 'GA', stateName: 'Georgia', agencyName: 'Georgia DNR' },
  'HI': { stateCode: 'HI', stateName: 'Hawaii', agencyName: 'Hawaii DLNR' },
  'ID': { stateCode: 'ID', stateName: 'Idaho', agencyName: 'Idaho Fish & Game' },
  'IL': { stateCode: 'IL', stateName: 'Illinois', agencyName: 'Illinois DNR' },
  'IN': { stateCode: 'IN', stateName: 'Indiana', agencyName: 'Indiana DNR' },
  'IA': { stateCode: 'IA', stateName: 'Iowa', agencyName: 'Iowa DNR' },
  'KS': { stateCode: 'KS', stateName: 'Kansas', agencyName: 'Kansas Wildlife' },
  'KY': { stateCode: 'KY', stateName: 'Kentucky', agencyName: 'Kentucky DFW' },
  'LA': { stateCode: 'LA', stateName: 'Louisiana', agencyName: 'Louisiana WLF' },
  'ME': { stateCode: 'ME', stateName: 'Maine', agencyName: 'Maine IFW' },
  'MD': { stateCode: 'MD', stateName: 'Maryland', agencyName: 'Maryland DNR' },
  'MA': { stateCode: 'MA', stateName: 'Massachusetts', agencyName: 'Massachusetts DFW' },
  'MI': { stateCode: 'MI', stateName: 'Michigan', agencyName: 'Michigan DNR' },
  'MN': { stateCode: 'MN', stateName: 'Minnesota', agencyName: 'Minnesota DNR' },
  'MS': { stateCode: 'MS', stateName: 'Mississippi', agencyName: 'Mississippi DWFP' },
  'MO': { stateCode: 'MO', stateName: 'Missouri', agencyName: 'Missouri MDC' },
  'MT': { stateCode: 'MT', stateName: 'Montana', agencyName: 'Montana FWP' },
  'NE': { stateCode: 'NE', stateName: 'Nebraska', agencyName: 'Nebraska Game & Parks' },
  'NV': { stateCode: 'NV', stateName: 'Nevada', agencyName: 'Nevada DOW' },
  'NH': { stateCode: 'NH', stateName: 'New Hampshire', agencyName: 'New Hampshire FG' },
  'NJ': { stateCode: 'NJ', stateName: 'New Jersey', agencyName: 'New Jersey DFW' },
  'NM': { stateCode: 'NM', stateName: 'New Mexico', agencyName: 'New Mexico DGF' },
  'NY': { stateCode: 'NY', stateName: 'New York', agencyName: 'New York DEC' },
  'NC': { stateCode: 'NC', stateName: 'North Carolina', agencyName: 'North Carolina WRC' },
  'ND': { stateCode: 'ND', stateName: 'North Dakota', agencyName: 'North Dakota GF' },
  'OH': { stateCode: 'OH', stateName: 'Ohio', agencyName: 'Ohio DNR' },
  'OK': { stateCode: 'OK', stateName: 'Oklahoma', agencyName: 'Oklahoma DWC' },
  'OR': { stateCode: 'OR', stateName: 'Oregon', agencyName: 'Oregon DFW' },
  'PA': { stateCode: 'PA', stateName: 'Pennsylvania', agencyName: 'Pennsylvania GC' },
  'RI': { stateCode: 'RI', stateName: 'Rhode Island', agencyName: 'Rhode Island DEM' },
  'SC': { stateCode: 'SC', stateName: 'South Carolina', agencyName: 'South Carolina DNR' },
  'SD': { stateCode: 'SD', stateName: 'South Dakota', agencyName: 'South Dakota GFP' },
  'TN': { stateCode: 'TN', stateName: 'Tennessee', agencyName: 'Tennessee TWRA' },
  'TX': { stateCode: 'TX', stateName: 'Texas', agencyName: 'Texas Parks & Wildlife' },
  'UT': { stateCode: 'UT', stateName: 'Utah', agencyName: 'Utah DWR' },
  'VT': { stateCode: 'VT', stateName: 'Vermont', agencyName: 'Vermont FW' },
  'VA': { stateCode: 'VA', stateName: 'Virginia', agencyName: 'Virginia DWR' },
  'WA': { stateCode: 'WA', stateName: 'Washington', agencyName: 'Washington DFW' },
  'WV': { stateCode: 'WV', stateName: 'West Virginia', agencyName: 'West Virginia DNR' },
  'WI': { stateCode: 'WI', stateName: 'Wisconsin', agencyName: 'Wisconsin DNR' },
  'WY': { stateCode: 'WY', stateName: 'Wyoming', agencyName: 'Wyoming Game & Fish' },
};

async function searchForLink(query: string, apiKey: string): Promise<string | null> {
  try {
    // Use Brave Search API (free tier available)
    const response = await fetch(
      `https://api.search.brave.com/res/v1/web/search?q=${encodeURIComponent(query)}&count=5`,
      {
        headers: {
          'Accept': 'application/json',
          'X-Subscription-Token': apiKey
        }
      }
    );
    
    if (!response.ok) {
      console.error(`Search API error: ${response.status}`);
      return null;
    }
    
    const data = await response.json();
    const results = data.web?.results || [];
    
    // Filter for official government sites
    for (const result of results) {
      const url = result.url as string;
      const domain = new URL(url).hostname.toLowerCase();
      
      // Prefer .gov domains or known official wildlife sites
      if (domain.endsWith('.gov') || 
          domain.includes('wildlife') || 
          domain.includes('outdoors') ||
          domain.includes('parks')) {
        return url;
      }
    }
    
    // Fallback to first result if no .gov found
    return results[0]?.url || null;
  } catch (error) {
    console.error('Search error:', error);
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  
  try {
    const searchApiKey = Deno.env.get('BRAVE_SEARCH_API_KEY');
    if (!searchApiKey) {
      return new Response(JSON.stringify({ 
        error: 'BRAVE_SEARCH_API_KEY not configured',
        message: 'Auto-discovery requires search API key. Set as Supabase secret.'
      }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, { auth: { persistSession: false } });
    
    const now = new Date().toISOString();
    let updated = 0;
    let unchanged = 0;
    let failed = 0;
    const failedStates: string[] = [];
    
    // Process a subset per run to avoid timeouts
    const { data: requestBody } = await req.json().catch(() => ({ data: {} }));
    const limit = requestBody?.limit || 10; // Process 10 states per run
    const offset = requestBody?.offset || 0;
    
    const stateCodes = Object.keys(STATE_AGENCIES).slice(offset, offset + limit);
    
    for (const stateCode of stateCodes) {
      const info = STATE_AGENCIES[stateCode];
      
      try {
        // Discover URLs for this state
        const huntingSeasonsUrl = await searchForLink(`${info.stateName} hunting season dates official`, searchApiKey);
        const huntingRegsUrl = await searchForLink(`${info.stateName} hunting regulations digest`, searchApiKey);
        const fishingRegsUrl = await searchForLink(`${info.stateName} fishing regulations`, searchApiKey);
        const licensingUrl = await searchForLink(`${info.stateName} hunting fishing license`, searchApiKey);
        const buyLicenseUrl = await searchForLink(`${info.stateName} buy hunting license online`, searchApiKey);
        
        if (!huntingSeasonsUrl && !huntingRegsUrl) {
          failed++;
          failedStates.push(stateCode);
          continue;
        }
        
        // Upsert discovered links
        await supabase.from('state_portal_links').upsert({
          state_code: stateCode,
          state_name: info.stateName,
          agency_name: info.agencyName,
          hunting_seasons_url: huntingSeasonsUrl,
          hunting_regs_url: huntingRegsUrl,
          fishing_regs_url: fishingRegsUrl,
          licensing_url: licensingUrl,
          buy_license_url: buyLicenseUrl,
          last_discovery_at: now,
          updated_at: now,
        }, { onConflict: 'state_code' });
        
        updated++;
      } catch (error) {
        console.error(`Failed to discover links for ${stateCode}:`, error);
        failed++;
        failedStates.push(stateCode);
      }
    }
    
    return new Response(JSON.stringify({
      message: 'Link discovery complete',
      processed: stateCodes.length,
      updated,
      unchanged,
      failed,
      failed_states: failedStates,
      discovered_at: now
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    
  } catch (error) {
    console.error('regs-links-discover error:', error);
    return new Response(JSON.stringify({ error: (error as Error).message }), 
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
