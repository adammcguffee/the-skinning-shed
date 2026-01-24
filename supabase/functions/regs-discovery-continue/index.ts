import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

/**
 * regs-discovery-continue Edge Function
 * 
 * Continues a discovery run by processing the next batch of states.
 * Crawls official domains, scores candidates, verifies URLs, and updates portal links.
 * 
 * Features:
 * - Per-state timeouts to prevent stalls
 * - Strict domain allowlist enforcement
 * - Verification before writing links
 * - Detailed audit trail per state
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const FETCH_TIMEOUT = 10000; // 10 seconds
const MAX_PAGES_PER_STATE = 40;
const MAX_RETRIES = 2;

// Keywords for scoring portal slots
const SLOT_KEYWORDS: Record<string, string[]> = {
  hunting_seasons: ['season', 'dates', 'schedule', 'when to hunt', 'hunting season', 'season dates', 'hunting dates'],
  hunting_regs: ['regulation', 'rules', 'digest', 'handbook', 'hunting regulation', 'hunting rules', 'game laws'],
  fishing_regs: ['fishing', 'fish regulation', 'angling', 'fishing rules', 'fisheries', 'trout', 'bass'],
  licensing: ['license', 'licensing', 'permit', 'licensing information', 'hunter education'],
  buy_license: ['buy', 'purchase', 'online', 'buy license', 'purchase license', 'get license', 'go outdoors'],
  records: ['record', 'trophy', 'big game record', 'record book', 'state record', 'biggest'],
};

interface OfficialRoot {
  state_code: string;
  state_name: string;
  agency_name: string;
  official_root_url: string;
  official_domain: string;
}

interface LinkCandidate {
  url: string;
  text: string;
  score: number;
}

interface DiscoveredLinks {
  hunting_seasons_url?: string;
  hunting_regs_url?: string;
  fishing_regs_url?: string;
  licensing_url?: string;
  buy_license_url?: string;
  records_url?: string;
}

interface VerifiedLinks {
  hunting_seasons?: { ok: boolean; status?: number; error?: string };
  hunting_regs?: { ok: boolean; status?: number; error?: string };
  fishing_regs?: { ok: boolean; status?: number; error?: string };
  licensing?: { ok: boolean; status?: number; error?: string };
  buy_license?: { ok: boolean; status?: number; error?: string };
  records?: { ok: boolean; status?: number; error?: string };
}

interface StateResult {
  state_code: string;
  status: 'ok' | 'skipped' | 'error';
  message?: string;
  discovered: DiscoveredLinks;
  verified: VerifiedLinks;
  pages_crawled: number;
  links_found: number;
}

/**
 * Check if a URL is within the official domain (or subdomain).
 */
function isUrlAllowed(url: string, officialDomain: string): boolean {
  try {
    const uri = new URL(url);
    const host = uri.host.toLowerCase();
    const domain = officialDomain.toLowerCase();
    return host === domain || host.endsWith('.' + domain);
  } catch {
    return false;
  }
}

/**
 * Fetch with timeout and retry.
 */
async function fetchWithRetry(url: string, options: RequestInit = {}, retries = MAX_RETRIES): Promise<Response | null> {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
      
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
      });
      clearTimeout(timeout);
      return response;
    } catch (error) {
      if (attempt === retries) {
        console.error(`Failed to fetch ${url} after ${retries + 1} attempts:`, error);
        return null;
      }
      // Wait briefly before retry
      await new Promise(r => setTimeout(r, 500 * (attempt + 1)));
    }
  }
  return null;
}

/**
 * Fetch a page and extract all links.
 */
async function fetchLinks(url: string, officialDomain: string): Promise<Array<{url: string, text: string}>> {
  const response = await fetchWithRetry(url, {
    method: 'GET',
    headers: {
      "User-Agent": "TheSkinningSheed OfficialDiscovery/2.0",
      "Accept": "text/html",
    },
    redirect: 'follow',
  });
  
  if (!response || response.status !== 200) return [];
  
  const contentType = response.headers.get('content-type') || '';
  if (!contentType.includes('text/html')) return [];
  
  const html = await response.text();
  
  // Extract links using regex
  const linkRegex = /<a\s+[^>]*href=["']([^"']+)["'][^>]*>([^<]*)<\/a>/gi;
  const links: Array<{url: string, text: string}> = [];
  let match;
  
  while ((match = linkRegex.exec(html)) !== null) {
    const href = match[1];
    const text = match[2].trim();
    
    if (!href || href.startsWith('#') || href.startsWith('javascript:') || href.startsWith('mailto:')) {
      continue;
    }
    
    try {
      const absoluteUrl = new URL(href, url).href;
      
      // Only include same-domain links (STRICT ALLOWLIST)
      if (isUrlAllowed(absoluteUrl, officialDomain)) {
        links.push({ url: absoluteUrl, text });
      }
    } catch {
      // Invalid URL, skip
    }
  }
  
  return links;
}

/**
 * Score a link for a specific portal slot.
 */
function scoreLink(text: string, url: string, slot: string): number {
  const keywords = SLOT_KEYWORDS[slot] || [];
  const lowerText = (text || '').toLowerCase();
  const lowerUrl = url.toLowerCase();
  
  let score = 0;
  
  for (const keyword of keywords) {
    if (lowerText.includes(keyword)) score += 10;
    if (lowerUrl.includes(keyword.replace(/\s+/g, ''))) score += 5;
    if (lowerUrl.includes(keyword.replace(/\s+/g, '-'))) score += 5;
    if (lowerUrl.includes(keyword.replace(/\s+/g, '_'))) score += 5;
  }
  
  // Boost for being in a likely path
  if (slot === 'hunting_seasons' && (lowerUrl.includes('/hunt') || lowerUrl.includes('/season'))) score += 8;
  if (slot === 'hunting_regs' && (lowerUrl.includes('/regulation') || lowerUrl.includes('/rules'))) score += 8;
  if (slot === 'fishing_regs' && lowerUrl.includes('/fish')) score += 8;
  if (slot === 'licensing' && lowerUrl.includes('/licens')) score += 8;
  if (slot === 'buy_license' && (lowerUrl.includes('/buy') || lowerUrl.includes('/purchase') || lowerUrl.includes('gooutdoors'))) score += 8;
  if (slot === 'records' && lowerUrl.includes('/record')) score += 8;
  
  return score;
}

/**
 * Verify a URL returns 200 OK with valid content-type.
 */
async function verifyUrl(url: string): Promise<{ ok: boolean; status?: number; error?: string }> {
  if (!url) return { ok: false, error: 'No URL' };
  
  const response = await fetchWithRetry(url, {
    method: 'GET',
    headers: {
      "User-Agent": "TheSkinningSheed LinkVerifier/2.0",
      "Accept": "text/html,application/pdf,*/*",
    },
    redirect: 'follow',
  });
  
  if (!response) {
    return { ok: false, error: 'Network error' };
  }
  
  if (response.status !== 200) {
    return { ok: false, status: response.status, error: `HTTP ${response.status}` };
  }
  
  const contentType = response.headers.get('content-type') || '';
  const validTypes = ['text/html', 'application/pdf', 'application/xhtml'];
  const isValid = validTypes.some(t => contentType.toLowerCase().includes(t));
  
  if (!isValid) {
    return { ok: false, status: 200, error: `Invalid content-type: ${contentType}` };
  }
  
  return { ok: true, status: 200 };
}

/**
 * Discover and verify portal links for a single state.
 */
async function discoverStateLinks(root: OfficialRoot): Promise<StateResult> {
  const result: StateResult = {
    state_code: root.state_code,
    status: 'ok',
    discovered: {},
    verified: {},
    pages_crawled: 0,
    links_found: 0,
  };
  
  try {
    const visited = new Set<string>();
    const toVisit = [root.official_root_url];
    const allLinks: Array<{url: string, text: string}> = [];
    
    // BFS crawl with limits
    while (toVisit.length > 0 && result.pages_crawled < MAX_PAGES_PER_STATE) {
      const url = toVisit.shift()!;
      
      const normalizedUrl = url.split('?')[0].split('#')[0].toLowerCase();
      if (visited.has(normalizedUrl)) continue;
      visited.add(normalizedUrl);
      
      const links = await fetchLinks(url, root.official_domain);
      result.pages_crawled++;
      
      for (const link of links) {
        allLinks.push(link);
        
        const normalizedLink = link.url.split('?')[0].split('#')[0].toLowerCase();
        if (!visited.has(normalizedLink) && toVisit.length < MAX_PAGES_PER_STATE * 2) {
          toVisit.push(link.url);
        }
      }
    }
    
    result.links_found = allLinks.length;
    
    if (allLinks.length === 0) {
      result.status = 'skipped';
      result.message = 'No links found on official domain';
      return result;
    }
    
    // Score all links for each slot
    const slots = ['hunting_seasons', 'hunting_regs', 'fishing_regs', 'licensing', 'buy_license', 'records'] as const;
    
    for (const slot of slots) {
      const candidates: LinkCandidate[] = allLinks.map(link => ({
        url: link.url,
        text: link.text,
        score: scoreLink(link.text, link.url, slot),
      })).filter(c => c.score > 0);
      
      candidates.sort((a, b) => b.score - a.score);
      
      // Take best candidate with minimum score threshold
      if (candidates.length > 0 && candidates[0].score >= 10) {
        const urlKey = `${slot}_url` as keyof DiscoveredLinks;
        result.discovered[urlKey] = candidates[0].url;
      }
    }
    
    // Verify discovered URLs
    for (const slot of slots) {
      const urlKey = `${slot}_url` as keyof DiscoveredLinks;
      const url = result.discovered[urlKey];
      
      if (url) {
        const verification = await verifyUrl(url);
        result.verified[slot] = verification;
        
        // If verification fails, remove the URL (don't write bad links)
        if (!verification.ok) {
          delete result.discovered[urlKey];
        }
      }
    }
    
    // Check if we found anything useful
    const foundCount = Object.keys(result.discovered).length;
    if (foundCount === 0) {
      result.status = 'skipped';
      result.message = 'No verified links found';
    } else {
      result.message = `Found ${foundCount} verified link(s)`;
    }
    
  } catch (error) {
    result.status = 'error';
    result.message = (error as Error).message.substring(0, 200);
  }
  
  return result;
}

/**
 * Update state_portal_links with verified discovered URLs.
 */
async function updatePortalLinks(
  supabase: SupabaseClient,
  root: OfficialRoot,
  discovered: DiscoveredLinks
): Promise<void> {
  const updates: Record<string, unknown> = {
    state_code: root.state_code,
    state_name: root.state_name,
    agency_name: root.agency_name,
    updated_at: new Date().toISOString(),
    discovered_by: 'AUTO',
  };
  
  // Only update fields that have verified URLs
  if (discovered.hunting_seasons_url) {
    updates.hunting_seasons_url = discovered.hunting_seasons_url;
    updates.verified_hunting_seasons_ok = false; // Will be verified by separate verify function
  }
  if (discovered.hunting_regs_url) {
    updates.hunting_regs_url = discovered.hunting_regs_url;
    updates.verified_hunting_regs_ok = false;
  }
  if (discovered.fishing_regs_url) {
    updates.fishing_regs_url = discovered.fishing_regs_url;
    updates.verified_fishing_regs_ok = false;
  }
  if (discovered.licensing_url) {
    updates.licensing_url = discovered.licensing_url;
    updates.verified_licensing_ok = false;
  }
  if (discovered.buy_license_url) {
    updates.buy_license_url = discovered.buy_license_url;
    updates.verified_buy_license_ok = false;
  }
  if (discovered.records_url) {
    updates.records_url = discovered.records_url;
    updates.verified_records_ok = false;
  }
  
  await supabase.from('state_portal_links')
    .upsert(updates, { onConflict: 'state_code' });
}

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
        error: 'Invalid session',
        error_code: 'INVALID_SESSION',
      }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    const { data: profile } = await supabaseAuth
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();
    
    if (!profile?.is_admin) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Admin access required',
        error_code: 'NOT_ADMIN',
      }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    // Use service role for operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    });

    // Parse request body for run_id
    let runId: string | undefined;
    try {
      const body = await req.json();
      runId = body.run_id;
    } catch {
      // No body
    }

    if (!runId) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing run_id',
        error_code: 'MISSING_RUN_ID',
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Load the run
    const { data: run, error: runError } = await supabase
      .from('reg_discovery_runs')
      .select('*')
      .eq('id', runId)
      .single();

    if (runError || !run) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Run not found',
        error_code: 'RUN_NOT_FOUND',
      }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    if (run.status !== 'running') {
      return new Response(JSON.stringify({
        success: true,
        message: 'Run already completed or canceled',
        run_id: run.id,
        status: run.status,
        processed: run.processed,
        total: run.total,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Get next batch of states
    const { data: roots, error: rootsError } = await supabase
      .from('state_official_roots')
      .select('*')
      .order('state_code')
      .range(run.cursor_pos, run.cursor_pos + run.batch_size - 1);

    if (rootsError) {
      throw new Error(`Failed to fetch states: ${rootsError.message}`);
    }

    if (!roots || roots.length === 0) {
      // All done!
      await supabase.from('reg_discovery_runs')
        .update({
          status: 'done',
          finished_at: new Date().toISOString(),
        })
        .eq('id', runId);

      return new Response(JSON.stringify({
        success: true,
        message: 'Discovery complete',
        run_id: runId,
        status: 'done',
        processed: run.processed,
        total: run.total,
        stats: {
          ok: run.stats_ok,
          skipped: run.stats_skipped,
          error: run.stats_error,
        },
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Process each state in the batch
    const batchResults: StateResult[] = [];
    let statsOk = run.stats_ok;
    let statsSkipped = run.stats_skipped;
    let statsError = run.stats_error;
    let lastStateCode = run.last_state_code;

    for (const root of roots as OfficialRoot[]) {
      const result = await discoverStateLinks(root);
      batchResults.push(result);
      lastStateCode = root.state_code;

      // Update stats
      if (result.status === 'ok') statsOk++;
      else if (result.status === 'skipped') statsSkipped++;
      else statsError++;

      // Update portal links if we found something
      if (Object.keys(result.discovered).length > 0) {
        await updatePortalLinks(supabase, root, result.discovered);
      }

      // Write audit item
      await supabase.from('reg_discovery_run_items')
        .upsert({
          run_id: runId,
          state_code: root.state_code,
          status: result.status,
          message: result.message,
          discovered: result.discovered,
          verified: result.verified,
          pages_crawled: result.pages_crawled,
          links_found: result.links_found,
        }, { onConflict: 'run_id,state_code' });
    }

    // Update run progress
    const newProcessed = run.processed + roots.length;
    const newCursor = run.cursor_pos + roots.length;
    const isDone = newCursor >= run.total;

    await supabase.from('reg_discovery_runs')
      .update({
        processed: newProcessed,
        cursor_pos: newCursor,
        last_state_code: lastStateCode,
        status: isDone ? 'done' : 'running',
        finished_at: isDone ? new Date().toISOString() : null,
        stats_ok: statsOk,
        stats_skipped: statsSkipped,
        stats_error: statsError,
      })
      .eq('id', runId);

    return new Response(JSON.stringify({
      success: true,
      message: isDone ? 'Discovery complete' : 'Batch processed',
      run_id: runId,
      status: isDone ? 'done' : 'running',
      processed: newProcessed,
      total: run.total,
      last_state_code: lastStateCode,
      stats: {
        ok: statsOk,
        skipped: statsSkipped,
        error: statsError,
      },
      batch_results: batchResults.map(r => ({
        state_code: r.state_code,
        status: r.status,
        message: r.message,
        links_found: Object.keys(r.discovered).length,
      })),
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('regs-discovery-continue error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: (error as Error).message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
