import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * regs-discover-official Edge Function
 * 
 * Crawls ONLY official state agency domains to discover best portal link candidates.
 * Only accepts URLs from state_official_roots domains (or subdomains).
 * 
 * Algorithm:
 * 1. For each state, fetch its official_root_url from state_official_roots
 * 2. Crawl the root page and extract links (same-domain only)
 * 3. Score links by keywords for each portal slot:
 *    - hunting_seasons: "season", "dates", "schedule", "when to hunt"
 *    - hunting_regs: "regulations", "rules", "digest", "handbook"
 *    - fishing_regs: "fishing", "fish regulations", "angling"
 *    - licensing: "license", "licensing", "permit"
 *    - buy_license: "buy", "purchase", "online license"
 *    - records: "record", "trophy", "big game"
 * 4. Store best candidates in state_portal_links
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const FETCH_TIMEOUT = 15000;
const MAX_PAGES_PER_STATE = 30;

// Keywords for scoring portal slots
const SLOT_KEYWORDS: Record<string, string[]> = {
  hunting_seasons: ['season', 'dates', 'schedule', 'when to hunt', 'hunting season', 'season dates'],
  hunting_regs: ['regulation', 'rules', 'digest', 'handbook', 'hunting regulation', 'hunting rules'],
  fishing_regs: ['fishing', 'fish regulation', 'angling', 'fishing rules', 'fisheries'],
  licensing: ['license', 'licensing', 'permit', 'licensing information'],
  buy_license: ['buy', 'purchase', 'online', 'buy license', 'purchase license', 'get license'],
  records: ['record', 'trophy', 'big game record', 'record book', 'state record'],
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

interface DiscoveryResult {
  state_code: string;
  hunting_seasons_url?: string;
  hunting_regs_url?: string;
  fishing_regs_url?: string;
  licensing_url?: string;
  buy_license_url?: string;
  records_url?: string;
  links_found: number;
  pages_crawled: number;
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
 * Fetch a page and extract all links.
 */
async function fetchLinks(url: string, officialDomain: string): Promise<Array<{url: string, text: string}>> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        "User-Agent": "TheSkinningSheed OfficialLinkDiscovery/1.0",
        "Accept": "text/html",
      },
      signal: controller.signal,
      redirect: 'follow',
    });
    clearTimeout(timeout);
    
    if (response.status !== 200) return [];
    
    const contentType = response.headers.get('content-type') || '';
    if (!contentType.includes('text/html')) return [];
    
    const html = await response.text();
    
    // Extract links using regex (simple parsing)
    const linkRegex = /<a\s+[^>]*href=["']([^"']+)["'][^>]*>([^<]*)<\/a>/gi;
    const links: Array<{url: string, text: string}> = [];
    let match;
    
    while ((match = linkRegex.exec(html)) !== null) {
      let href = match[1];
      const text = match[2].trim();
      
      // Skip empty, anchors, javascript, mailto
      if (!href || href.startsWith('#') || href.startsWith('javascript:') || href.startsWith('mailto:')) {
        continue;
      }
      
      // Resolve relative URLs
      try {
        const absoluteUrl = new URL(href, url).href;
        
        // Only include same-domain links
        if (isUrlAllowed(absoluteUrl, officialDomain)) {
          links.push({ url: absoluteUrl, text });
        }
      } catch {
        // Invalid URL, skip
      }
    }
    
    return links;
  } catch (error) {
    console.error(`Error fetching ${url}:`, error);
    return [];
  }
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
  if (slot === 'hunting_regs' && lowerUrl.includes('/regulation')) score += 8;
  if (slot === 'fishing_regs' && lowerUrl.includes('/fish')) score += 8;
  if (slot === 'licensing' && lowerUrl.includes('/licens')) score += 8;
  if (slot === 'buy_license' && (lowerUrl.includes('/buy') || lowerUrl.includes('/purchase'))) score += 8;
  if (slot === 'records' && lowerUrl.includes('/record')) score += 8;
  
  return score;
}

/**
 * Discover best portal links for a state by crawling its official domain.
 */
async function discoverStateLinks(root: OfficialRoot): Promise<DiscoveryResult> {
  const result: DiscoveryResult = {
    state_code: root.state_code,
    links_found: 0,
    pages_crawled: 0,
  };
  
  const visited = new Set<string>();
  const toVisit = [root.official_root_url];
  const allLinks: Array<{url: string, text: string}> = [];
  
  // BFS crawl
  while (toVisit.length > 0 && result.pages_crawled < MAX_PAGES_PER_STATE) {
    const url = toVisit.shift()!;
    
    // Normalize URL for deduplication
    const normalizedUrl = url.split('?')[0].split('#')[0].toLowerCase();
    if (visited.has(normalizedUrl)) continue;
    visited.add(normalizedUrl);
    
    const links = await fetchLinks(url, root.official_domain);
    result.pages_crawled++;
    
    for (const link of links) {
      allLinks.push(link);
      
      // Add to crawl queue if not visited (limit depth)
      const normalizedLink = link.url.split('?')[0].split('#')[0].toLowerCase();
      if (!visited.has(normalizedLink) && toVisit.length < MAX_PAGES_PER_STATE * 2) {
        toVisit.push(link.url);
      }
    }
  }
  
  result.links_found = allLinks.length;
  
  // Score all links for each slot
  const slots = ['hunting_seasons', 'hunting_regs', 'fishing_regs', 'licensing', 'buy_license', 'records'];
  
  for (const slot of slots) {
    const candidates: LinkCandidate[] = allLinks.map(link => ({
      url: link.url,
      text: link.text,
      score: scoreLink(link.text, link.url, slot),
    })).filter(c => c.score > 0);
    
    // Sort by score descending
    candidates.sort((a, b) => b.score - a.score);
    
    // Take best candidate with minimum score threshold
    if (candidates.length > 0 && candidates[0].score >= 10) {
      const key = slot + '_url' as keyof DiscoveryResult;
      (result as any)[key] = candidates[0].url;
    }
  }
  
  return result;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    
    // Create client with user's JWT to verify auth
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
    
    // Use anon key + user JWT to verify the user
    const supabaseAuth = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false }
    });
    
    // Verify user is authenticated
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
    
    // Check if user is admin
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
    
    // Use service role for actual operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    });

    // Parse request body for optional limit/offset
    let limit = 5; // Process 5 states per run
    let offset = 0;
    try {
      const body = await req.json();
      if (body.limit) limit = Math.min(body.limit, 10);
      if (body.offset) offset = body.offset;
    } catch {
      // No body or invalid JSON, use defaults
    }

    // Fetch official roots
    const { data: roots, error: rootsError } = await supabase
      .from('state_official_roots')
      .select('*')
      .order('state_code')
      .range(offset, offset + limit - 1);

    if (rootsError) {
      throw new Error(`Failed to fetch official roots: ${rootsError.message}`);
    }

    if (!roots || roots.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: 'No official roots to process',
        states_processed: 0,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const now = new Date().toISOString();
    const results: DiscoveryResult[] = [];
    let statesUpdated = 0;
    let linksDiscovered = 0;

    // Process each state
    for (const root of roots as OfficialRoot[]) {
      try {
        const discovery = await discoverStateLinks(root);
        results.push(discovery);
        
        // Count discovered links
        const discoveredSlots = [
          discovery.hunting_seasons_url,
          discovery.hunting_regs_url,
          discovery.fishing_regs_url,
          discovery.licensing_url,
          discovery.buy_license_url,
          discovery.records_url,
        ].filter(Boolean).length;
        
        linksDiscovered += discoveredSlots;

        // Update state_portal_links with discovered URLs
        if (discoveredSlots > 0) {
          const updates: Record<string, unknown> = {
            state_code: root.state_code,
            state_name: root.state_name,
            agency_name: root.agency_name,
            updated_at: now,
            discovered_by: 'AUTO',
          };
          
          if (discovery.hunting_seasons_url) {
            updates.hunting_seasons_url = discovery.hunting_seasons_url;
            updates.verified_hunting_seasons_ok = false; // Needs verification
          }
          if (discovery.hunting_regs_url) {
            updates.hunting_regs_url = discovery.hunting_regs_url;
            updates.verified_hunting_regs_ok = false;
          }
          if (discovery.fishing_regs_url) {
            updates.fishing_regs_url = discovery.fishing_regs_url;
            updates.verified_fishing_regs_ok = false;
          }
          if (discovery.licensing_url) {
            updates.licensing_url = discovery.licensing_url;
            updates.verified_licensing_ok = false;
          }
          if (discovery.buy_license_url) {
            updates.buy_license_url = discovery.buy_license_url;
            updates.verified_buy_license_ok = false;
          }
          if (discovery.records_url) {
            updates.records_url = discovery.records_url;
            updates.verified_records_ok = false;
          }

          await supabase.from('state_portal_links')
            .upsert(updates, { onConflict: 'state_code' });
          
          statesUpdated++;
        }
        
        // Update official root verification
        await supabase.from('state_official_roots')
          .update({
            verified_ok: true,
            last_verified_at: now,
            verify_error: null,
          })
          .eq('state_code', root.state_code);
          
      } catch (error) {
        console.error(`Error processing ${root.state_code}:`, error);
        
        // Mark as failed
        await supabase.from('state_official_roots')
          .update({
            verified_ok: false,
            last_verified_at: now,
            verify_error: (error as Error).message.substring(0, 200),
          })
          .eq('state_code', root.state_code);
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Official link discovery complete',
      states_processed: roots.length,
      states_updated: statesUpdated,
      links_discovered: linksDiscovered,
      offset,
      limit,
      results,
      discovered_at: now,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('regs-discover-official error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: (error as Error).message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
