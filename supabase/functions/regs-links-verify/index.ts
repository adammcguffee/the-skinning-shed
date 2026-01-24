import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { requireAdmin } from "../_shared/admin_auth.ts";

/**
 * regs-links-verify Edge Function v2
 * 
 * Verifies all portal links weekly to catch broken URLs.
 * Updates boolean verified_*_ok columns - THE GATEKEEPER for UI display.
 * 
 * Verification requirements:
 * - URL must respond with HTTP 200
 * - Content-Type must be text/html or application/pdf
 * - Follow redirects (max 3)
 * - Store detailed log per field in last_verify_log
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const VERIFY_TIMEOUT = 15000; // 15 seconds
const MAX_REDIRECTS = 3;

// Valid content types for verified links
const VALID_CONTENT_TYPES = [
  'text/html',
  'application/pdf',
  'application/xhtml+xml',
];

interface VerifyResult {
  url: string;
  field: string;
  status: number | null;
  contentType: string | null;
  ok: boolean;
  error?: string;
  redirectCount?: number;
  finalUrl?: string;
}

interface VerifyLog {
  status: number | null;
  content_type: string | null;
  ok: boolean;
  error?: string;
  final_url?: string;
  redirect_count?: number;
  verified_at: string;
}

/**
 * Check if content type is valid for verified links.
 */
function isValidContentType(contentType: string | null): boolean {
  if (!contentType) return false;
  const lower = contentType.toLowerCase();
  return VALID_CONTENT_TYPES.some(valid => lower.includes(valid));
}

/**
 * Verify a single URL with redirect following and content-type validation.
 */
async function verifyUrl(url: string | null | undefined, field: string): Promise<VerifyResult> {
  const baseResult: VerifyResult = {
    url: url || '',
    field,
    status: null,
    contentType: null,
    ok: false,
  };

  // Empty URL = not verified
  if (!url || url.trim() === '') {
    return baseResult;
  }

  let redirectCount = 0;
  let currentUrl = url;

  try {
    // Manual redirect following to count redirects
    while (redirectCount <= MAX_REDIRECTS) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), VERIFY_TIMEOUT);

      try {
        const response = await fetch(currentUrl, {
          method: 'GET',
          headers: {
            "User-Agent": "TheSkinningSheed LinkVerifier/2.0 (official-links-check)",
            "Accept": "text/html,application/xhtml+xml,application/pdf,*/*",
          },
          signal: controller.signal,
          redirect: 'manual', // Handle redirects manually
        });
        clearTimeout(timeout);

        // Check for redirect
        if (response.status >= 300 && response.status < 400) {
          const location = response.headers.get('location');
          if (location && redirectCount < MAX_REDIRECTS) {
            // Resolve relative URLs
            currentUrl = new URL(location, currentUrl).href;
            redirectCount++;
            continue;
          }
          // Too many redirects or no location header
          return {
            ...baseResult,
            status: response.status,
            ok: false,
            error: `Too many redirects or missing location header`,
            redirectCount,
          };
        }

        const contentType = response.headers.get('content-type');
        const isOk = response.status === 200 && isValidContentType(contentType);

        return {
          url,
          field,
          status: response.status,
          contentType,
          ok: isOk,
          redirectCount,
          finalUrl: currentUrl !== url ? currentUrl : undefined,
          error: response.status !== 200 
            ? `HTTP ${response.status}` 
            : (!isValidContentType(contentType) ? `Invalid content-type: ${contentType}` : undefined),
        };
      } catch (fetchError) {
        clearTimeout(timeout);
        throw fetchError;
      }
    }

    return {
      ...baseResult,
      ok: false,
      error: 'Max redirects exceeded',
      redirectCount,
    };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return {
      ...baseResult,
      ok: false,
      error: errorMsg.substring(0, 150),
    };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const auth = await requireAdmin(req);
    if (!auth.ok) {
      return new Response(JSON.stringify(auth), {
        status: auth.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    const supabase = auth.admin!;

    // Fetch all portal links
    const { data: states, error: statesError } = await supabase
      .from('state_portal_links')
      .select('*')
      .order('state_code');

    if (statesError) {
      throw new Error(`Failed to fetch states: ${statesError.message}`);
    }

    if (!states || states.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: 'No portal links to verify',
        states_checked: 0,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const now = new Date().toISOString();
    let totalChecked = 0;
    let totalVerified = 0;
    let totalFailed = 0;
    const brokenLinks: Array<{
      state: string;
      state_name: string;
      field: string;
      url: string;
      status: number | null;
      error?: string;
    }> = [];

    // Verify each state's links
    for (const state of states) {
      // Verify all URL fields in parallel
      const results = await Promise.all([
        verifyUrl(state.hunting_seasons_url, 'hunting_seasons'),
        verifyUrl(state.hunting_regs_url, 'hunting_regs'),
        verifyUrl(state.fishing_regs_url, 'fishing_regs'),
        verifyUrl(state.licensing_url, 'licensing'),
        verifyUrl(state.buy_license_url, 'buy_license'),
        verifyUrl(state.records_url, 'records'),
      ]);

      // Build update object
      const updates: Record<string, unknown> = {
        last_verified_at: now,
      };

      // Build verify log
      const verifyLog: Record<string, VerifyLog> = {};

      for (const result of results) {
        if (result.url === '') continue; // Skip empty URLs

        totalChecked++;

        // Set the boolean OK field
        const okField = `verified_${result.field}_ok`;
        updates[okField] = result.ok;

        // Set the status field (legacy, keep for backwards compat)
        const statusField = `${result.field}_status`;
        updates[statusField] = result.status;

        // Build log entry for this field
        verifyLog[result.field] = {
          status: result.status,
          content_type: result.contentType,
          ok: result.ok,
          error: result.error,
          final_url: result.finalUrl,
          redirect_count: result.redirectCount,
          verified_at: now,
        };

        if (result.ok) {
          totalVerified++;
        } else {
          totalFailed++;
          brokenLinks.push({
            state: state.state_code,
            state_name: state.state_name,
            field: result.field,
            url: result.url,
            status: result.status,
            error: result.error,
          });
        }
      }

      // Add verify log to updates
      updates.last_verify_log = verifyLog;

      // Update state
      await supabase.from('state_portal_links')
        .update(updates)
        .eq('state_code', state.state_code);
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Link verification complete',
      states_checked: states.length,
      links_checked: totalChecked,
      verified_ok: totalVerified,
      failed: totalFailed,
      broken_links: brokenLinks,
      verified_at: now,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('regs-links-verify error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: (error as Error).message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
