import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { requireAdmin } from "../_shared/admin_auth.ts";

/**
 * regulations-check-v6 Edge Function
 * 
 * Complete + Consistent:
 * - Processes ALL 150 extractable sources with proper timeout handling
 * - OpenAI normalization with strict JSON schema
 * - Portal-first: users always have links even if extraction fails
 * - Never creates pending for landing pages
 */

const EXTRACTION_VERSION = "v6.0.0";
const AUTO_APPROVE_THRESHOLD = 0.85;
const BATCH_SIZE = 3; // Smaller batches for reliability
const FETCH_TIMEOUT = 15000; // 15s per fetch
const SOURCE_TIMEOUT = 25000; // 25s total per source (fetch + processing)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function iso(v: unknown): string | null {
  if (!v) return null;
  if (v instanceof Date) return isNaN(v.getTime()) ? null : v.toISOString();
  if (typeof v === 'string') {
    const d = new Date(v);
    return isNaN(d.getTime()) ? v : d.toISOString();
  }
  return null;
}

async function hashContent(content: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(content);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

function getSeasonYearLabel(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  return month >= 7 ? `${year}-${year + 1}` : `${year - 1}-${year}`;
}

function getYearStart(): number {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  return month >= 7 ? year : year - 1;
}

function normalizeHtml(html: string): string {
  let content = html;
  content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  content = content.replace(/<[^>]+>/g, ' ');
  content = content.replace(/\s+/g, ' ').trim();
  return content;
}

function extractTextContent(html: string): string {
  let content = html;
  content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  content = content.replace(/<tr[^>]*>/gi, '\n[ROW]');
  content = content.replace(/<\/tr>/gi, '[/ROW]');
  content = content.replace(/<t[hd][^>]*>/gi, ' | ');
  content = content.replace(/<br\s*\/?>/gi, '\n');
  content = content.replace(/<\/p>/gi, '\n');
  content = content.replace(/<[^>]+>/g, ' ');
  content = content.replace(/&nbsp;/gi, ' ');
  content = content.replace(/&amp;/gi, '&');
  content = content.replace(/\s+/g, ' ').trim();
  return content.substring(0, 12000);
}

interface PageClassification {
  hasTable: boolean;
  hasDatePattern: boolean;
  hasSeasonKeywords: boolean;
  isPdf: boolean;
  isExtractable: boolean;
  skipReason: string | null;
}

function classifyPage(content: string, contentType: string): PageClassification {
  const lower = content.toLowerCase();
  const isPdf = contentType.includes('pdf');
  
  const hasTable = lower.includes('<table') || lower.includes('[row]') || /\|[^|]+\|[^|]+\|/.test(content);
  const hasDatePattern = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}/i.test(content) ||
                         /\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}/.test(content);
  const hasSeasonKeywords = /\b(season|archery|muzzleloader|rifle|firearm|youth|general|spring|fall)\s+(season|dates?|opens?|closes?)\b/i.test(content);
  
  const wordCount = content.split(/\s+/).length;
  const hasNoData = !hasDatePattern && wordCount < 300;
  const isLandingPage = hasNoData || (lower.includes('learn more') && lower.includes('get started') && !hasDatePattern);
  
  const isExtractable = !isLandingPage && (hasDatePattern || hasTable || isPdf);
  
  let skipReason: string | null = null;
  if (!isExtractable) {
    if (isLandingPage) skipReason = 'Landing page - use portal links';
    else skipReason = 'No regulation data found';
  }
  
  return { hasTable, hasDatePattern, hasSeasonKeywords, isPdf, isExtractable, skipReason };
}

interface NormalizedData {
  seasons: Array<{ name: string; start_date?: string; end_date?: string; notes?: string }>;
  bag_limits: Array<{ species: string; daily?: string; possession?: string; season?: string; notes?: string }>;
  legal_methods: Array<{ name: string; allowed: boolean; restrictions?: string }>;
  notes: string[];
}

// OpenAI normalization with strict JSON schema
async function normalizeWithOpenAI(content: string, category: string, stateCode: string): Promise<NormalizedData | null> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  if (!openaiKey) {
    console.log('OPENAI_API_KEY not set, skipping LLM normalization');
    return null;
  }
  
  const model = Deno.env.get('OPENAI_MODEL') || 'gpt-4o-mini';
  
  const schema = {
    type: 'object',
    properties: {
      seasons: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            name: { type: 'string' },
            start_date: { type: 'string' },
            end_date: { type: 'string' },
            notes: { type: 'string' }
          },
          required: ['name']
        }
      },
      bag_limits: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            species: { type: 'string' },
            daily: { type: 'string' },
            possession: { type: 'string' },
            season: { type: 'string' },
            notes: { type: 'string' }
          },
          required: ['species']
        }
      },
      legal_methods: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            name: { type: 'string' },
            allowed: { type: 'boolean' },
            restrictions: { type: 'string' }
          },
          required: ['name', 'allowed']
        }
      },
      notes: { type: 'array', items: { type: 'string' } }
    },
    required: ['seasons', 'bag_limits', 'legal_methods', 'notes']
  };
  
  const systemPrompt = `You are extracting ${category} hunting/fishing regulations from state wildlife agency content for ${stateCode}.\n\nRULES:\n1. Extract ONLY information that is explicitly stated\n2. DO NOT invent or guess any values\n3. Dates must be in format "Mon DD" (e.g. "Oct 15", "Jan 1")\n4. If a field is missing or unclear, omit it or use empty string\n5. Bag limits must be reasonable numbers (1-50)\n6. For dates without year, assume current hunting season\n\nOutput valid JSON matching the schema. Empty arrays are acceptable if no data found.`;
  
  const userPrompt = `Extract ${category} regulations:\n\n${content.substring(0, 10000)}`;
  
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.1,
        max_tokens: 1500,
        response_format: { type: 'json_schema', json_schema: { name: 'regulations', strict: true, schema } }
      }),
    });
    
    if (!response.ok) {
      console.error(`OpenAI API error: ${response.status}`);
      return null;
    }
    
    const result = await response.json();
    const content_text = result.choices?.[0]?.message?.content;
    if (!content_text) return null;
    
    const parsed = JSON.parse(content_text);
    return {
      seasons: parsed.seasons || [],
      bag_limits: parsed.bag_limits || [],
      legal_methods: parsed.legal_methods || [],
      notes: parsed.notes || []
    };
  } catch (e) {
    console.error('OpenAI normalization error:', e);
    return null;
  }
}

interface ValidationResult {
  valid: boolean;
  warnings: string[];
  confidence: number;
}

function validateNormalizedData(data: NormalizedData, category: string, classification: PageClassification): ValidationResult {
  const warnings: string[] = [];
  let confidence = 0.5;
  
  // Classification bonuses
  if (classification.hasTable) confidence += 0.15;
  if (classification.hasDatePattern) confidence += 0.15;
  if (classification.hasSeasonKeywords) confidence += 0.1;
  if (classification.isPdf) confidence -= 0.1;
  
  // Data bonuses
  if (data.seasons.length >= 1) confidence += 0.2;
  if (data.seasons.length >= 3) confidence += 0.1;
  if (data.bag_limits.length >= 1) confidence += 0.05;
  
  // For deer/turkey, must have seasons
  if ((category === 'deer' || category === 'turkey') && data.seasons.length === 0) {
    warnings.push('No seasons detected for hunting category');
    confidence -= 0.3;
  }
  
  // Validate season dates
  const monthNames = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  for (const season of data.seasons) {
    if (season.start_date) {
      const monthMatch = season.start_date.toLowerCase().match(/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/);
      if (!monthMatch) warnings.push(`Invalid start date: ${season.start_date}`);
    }
    if (season.end_date) {
      const monthMatch = season.end_date.toLowerCase().match(/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/);
      if (!monthMatch) warnings.push(`Invalid end date: ${season.end_date}`);
    }
  }
  
  // Validate bag limits
  for (const limit of data.bag_limits) {
    const checkLimit = (val: string | undefined, max: number) => {
      if (!val) return;
      const num = parseInt(val);
      if (isNaN(num) || num < 1 || num > max) {
        warnings.push(`Suspicious bag limit: ${val}`);
      }
    };
    checkLimit(limit.daily, 25);
    checkLimit(limit.possession, 50);
    checkLimit(limit.season, 50);
  }
  
  confidence = Math.max(0, Math.min(1, confidence));
  const valid = data.seasons.length > 0 || data.bag_limits.length > 0;
  
  return { valid, warnings, confidence };
}

function toSummaryJson(data: NormalizedData): object | null {
  if (data.seasons.length === 0 && data.bag_limits.length === 0) return null;
  return {
    seasons: data.seasons,
    bag_limits: data.bag_limits,
    weapons: data.legal_methods,
    notes: data.notes
  };
}

async function processSourceWithTimeout(
  source: any,
  supabase: any,
  seasonYearLabel: string,
  yearStart: number,
  now: string
): Promise<{ checked: number; autoApproved: number; pending: number; skipped: number; failed: number; result: any }> {
  const timeoutPromise = new Promise<never>((_, reject) => 
    setTimeout(() => reject(new Error('Source timeout')), SOURCE_TIMEOUT)
  );
  
  try {
    return await Promise.race([
      processSource(source, supabase, seasonYearLabel, yearStart, now),
      timeoutPromise
    ]);
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return {
      checked: 0, autoApproved: 0, pending: 0, skipped: 0, failed: 1,
      result: { state: source.state_code, category: source.category, status: 'timeout', error: errorMsg }
    };
  }
}

async function processSource(
  source: any,
  supabase: any,
  seasonYearLabel: string,
  yearStart: number,
  now: string
): Promise<{ checked: number; autoApproved: number; pending: number; skipped: number; failed: number; result: any }> {
  const regionKey = source.region_key || 'STATEWIDE';
  const regionLabel = source.region_label || 'Statewide';
  
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
    
    const response = await fetch(source.source_url, {
      headers: { "User-Agent": "TheSkinning Shed/6.0", "Accept": "text/html,application/pdf,*/*" },
      signal: controller.signal
    });
    clearTimeout(timeout);
    
    if (!response.ok) {
      return { checked: 0, autoApproved: 0, pending: 0, skipped: 0, failed: 1, result: { state: source.state_code, category: source.category, status: 'http_error', error: `HTTP ${response.status}` } };
    }
    
    const contentType = response.headers.get('content-type') || '';
    const rawContent = await response.text();
    const normalizedContent = normalizeHtml(rawContent);
    const newHash = await hashContent(normalizedContent);
    
    await supabase.from('state_regulations_sources').update({ last_checked_at: now }).eq('id', source.id);
    
    const previousHash = source.content_hash;
    const hasChanged = previousHash && previousHash !== newHash;
    const isNew = !previousHash;
    
    if (!hasChanged && !isNew) {
      await supabase.from('state_regulations_sources').update({ content_hash: newHash, updated_at: now }).eq('id', source.id);
      return { checked: 1, autoApproved: 0, pending: 0, skipped: 0, failed: 0, result: { state: source.state_code, category: source.category, status: 'unchanged' } };
    }
    
    // Classify page
    const textContent = extractTextContent(rawContent);
    const classification = classifyPage(textContent, contentType);
    
    // If not extractable, skip
    if (!classification.isExtractable) {
      await supabase.from('state_regulations_sources').update({ 
        content_hash: newHash, 
        source_type: 'portal_only',
        updated_at: now 
      }).eq('id', source.id);
      
      return { checked: 1, autoApproved: 0, pending: 0, skipped: 1, failed: 0, result: { state: source.state_code, category: source.category, status: 'skipped', reason: classification.skipReason } };
    }
    
    // Normalize with OpenAI
    const normalizedData = await normalizeWithOpenAI(textContent, source.category, source.state_code);
    
    if (!normalizedData) {
      return { checked: 1, autoApproved: 0, pending: 0, skipped: 1, failed: 0, result: { state: source.state_code, category: source.category, status: 'extraction_failed', reason: 'OpenAI unavailable or error' } };
    }
    
    const validation = validateNormalizedData(normalizedData, source.category, classification);
    const summaryJson = toSummaryJson(normalizedData);
    
    if (!summaryJson) {
      await supabase.from('state_regulations_sources').update({ content_hash: newHash, updated_at: now }).eq('id', source.id);
      return { checked: 1, autoApproved: 0, pending: 0, skipped: 1, failed: 0, result: { state: source.state_code, category: source.category, status: 'no_data' } };
    }
    
    const diffSummary = `v6 normalized: ${normalizedData.seasons.length} seasons, ${normalizedData.bag_limits.length} limits`;
    let approvalMode: string;
    let approvedRowId: string | null = null;
    
    // Auto-approve if high confidence AND valid
    if (validation.confidence >= AUTO_APPROVE_THRESHOLD && validation.valid) {
      const { data: approvedRow, error: approveError } = await supabase
        .from('state_regulations_approved')
        .upsert({
          state_code: source.state_code,
          category: source.category,
          region_key: regionKey,
          region_label: regionLabel,
          region_scope: 'statewide',
          season_year_label: seasonYearLabel,
          year_start: yearStart,
          year_end: yearStart + 1,
          summary: summaryJson,
          source_url: source.source_url,
          confidence_score: validation.confidence,
          approval_mode: 'auto',
          approved_by: 'AUTO_V6',
          extraction_version: EXTRACTION_VERSION,
          approved_at: now,
          updated_at: now,
        }, { onConflict: 'state_code,category,season_year_label,region_key' })
        .select('id').single();
      
      if (!approveError) {
        approvalMode = 'auto';
        approvedRowId = approvedRow?.id || null;
        await supabase.from('state_regulations_sources').update({ content_hash: newHash, last_approved_hash: newHash, updated_at: now }).eq('id', source.id);
      } else {
        approvalMode = 'pending';
      }
    } else {
      approvalMode = 'pending';
    }
    
    if (approvalMode === 'pending') {
      const pendingReason = validation.confidence < 0.5 ? 'Low confidence' : validation.warnings.length > 0 ? validation.warnings[0] : 'Requires review';
      await supabase.from('state_regulations_pending').upsert({
        state_code: source.state_code,
        category: source.category,
        region_key: regionKey,
        region_label: regionLabel,
        region_scope: 'statewide',
        season_year_label: seasonYearLabel,
        year_start: yearStart,
        year_end: yearStart + 1,
        proposed_summary: summaryJson,
        source_url: source.source_url,
        source_hash: newHash,
        diff_summary: diffSummary,
        confidence_score: validation.confidence,
        extraction_warnings: validation.warnings,
        pending_reason: pendingReason,
        status: 'pending',
        created_at: now,
        updated_at: now,
      }, { onConflict: 'state_code,category,season_year_label,region_key' });
      await supabase.from('state_regulations_sources').update({ content_hash: newHash, updated_at: now }).eq('id', source.id);
    }
    
    await supabase.from('state_regulations_audit_log').insert({
      state_code: source.state_code,
      category: source.category,
      region_key: regionKey,
      detected_at: now,
      previous_hash: previousHash,
      new_hash: newHash,
      confidence_score: validation.confidence,
      approval_mode: approvalMode,
      diff_summary: diffSummary,
      extraction_warnings: validation.warnings,
      approved_row_id: approvedRowId,
    });
    
    return {
      checked: 1,
      autoApproved: approvalMode === 'auto' ? 1 : 0,
      pending: approvalMode === 'pending' ? 1 : 0,
      skipped: 0,
      failed: 0,
      result: { state: source.state_code, category: source.category, status: approvalMode, confidence: Math.round(validation.confidence * 100) / 100, seasons: normalizedData.seasons.length, warnings: validation.warnings.length }
    };
    
  } catch (fetchError) {
    return { checked: 0, autoApproved: 0, pending: 0, skipped: 0, failed: 1, result: { state: source.state_code, category: source.category, status: 'error', error: (fetchError as Error).message?.substring(0, 100) } };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  
  try {
    const auth = await requireAdmin(req);
    if (!auth.ok) {
      return new Response(JSON.stringify(auth), {
        status: auth.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    const supabase = auth.admin!;
    
    // Only fetch extractable sources
    const { data: sources, error: sourcesError } = await supabase
      .from('state_regulations_sources')
      .select('*')
      .eq('source_type', 'extractable')
      .order('priority', { ascending: false })
      .order('state_code').order('category');
    
    if (sourcesError) throw new Error(`Failed to fetch sources: ${sourcesError.message}`);
    if (!sources || sources.length === 0) {
      return new Response(JSON.stringify({ message: 'No extractable sources', checked: 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    
    const seasonYearLabel = getSeasonYearLabel();
    const yearStart = getYearStart();
    const now = iso(new Date())!;
    
    let totalChecked = 0, totalAutoApproved = 0, totalPending = 0, totalSkipped = 0, totalFailed = 0;
    const allResults: any[] = [];
    
    console.log(`Processing ${sources.length} extractable sources in batches of ${BATCH_SIZE}...`);
    
    // Process in smaller batches with timeout per source
    for (let i = 0; i < sources.length; i += BATCH_SIZE) {
      const batch = sources.slice(i, i + BATCH_SIZE);
      console.log(`Batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(sources.length / BATCH_SIZE)}: processing ${batch.length} sources`);
      
      const results = await Promise.all(batch.map(s => processSourceWithTimeout(s, supabase, seasonYearLabel, yearStart, now)));
      
      for (const r of results) {
        totalChecked += r.checked;
        totalAutoApproved += r.autoApproved;
        totalPending += r.pending;
        totalSkipped += r.skipped;
        totalFailed += r.failed;
        allResults.push(r.result);
      }
    }
    
    const byCategory: Record<string, any> = {};
    for (const r of allResults) {
      if (!byCategory[r.category]) byCategory[r.category] = { checked: 0, auto: 0, pending: 0, skipped: 0, failed: 0 };
      if (['unchanged', 'auto', 'pending'].includes(r.status)) byCategory[r.category].checked++;
      if (r.status === 'auto') byCategory[r.category].auto++;
      if (r.status === 'pending') byCategory[r.category].pending++;
      if (['skipped', 'no_data', 'extraction_failed'].includes(r.status)) byCategory[r.category].skipped++;
      if (['error', 'timeout', 'http_error'].includes(r.status)) byCategory[r.category].failed++;
    }
    
    return new Response(JSON.stringify({
      message: 'Check complete (v6 OpenAI normalized)',
      checked: totalChecked,
      auto_approved: totalAutoApproved,
      pending: totalPending,
      skipped: totalSkipped,
      failed: totalFailed,
      total_sources: sources.length,
      season: seasonYearLabel,
      extraction_version: EXTRACTION_VERSION,
      by_category: byCategory,
      results: allResults
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    
  } catch (error) {
    console.error('regulations-check-v6 error:', error);
    return new Response(JSON.stringify({ error: (error as Error).message, stack: (error as Error).stack }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
