import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { requireAdmin } from "../_shared/admin_auth.ts";

/**
 * regulations-check-v5 Edge Function
 * 
 * Portal-first approach:
 * - Only processes sources with source_type='extractable'
 * - Does NOT create pending for landing/hub pages
 * - Strict validation prevents junk pending
 */

const EXTRACTION_VERSION = "v5.0.0";
const AUTO_APPROVE_THRESHOLD = 0.85;
const BATCH_SIZE = 5;
const FETCH_TIMEOUT = 20000;

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
  hasBagLimitKeywords: boolean;
  isPdf: boolean;
  isExtractable: boolean;
  reason: string;
}

function classifyPage(content: string, contentType: string): PageClassification {
  const lower = content.toLowerCase();
  const isPdf = contentType.includes('pdf');
  
  const hasTable = lower.includes('<table') || lower.includes('[row]') || /\|[^|]+\|[^|]+\|/.test(content);
  const hasDatePattern = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}/i.test(content) ||
                         /\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}/.test(content);
  const hasSeasonKeywords = /\b(season|archery|muzzleloader|rifle|firearm|youth|general|spring|fall)\s+(season|dates?|opens?|closes?)\b/i.test(content);
  const hasBagLimitKeywords = /\b(bag\s*limit|daily\s*limit|possession\s*limit|per\s*day|antler)\b/i.test(content);
  
  // Determine if extractable
  const wordCount = content.split(/\s+/).length;
  const hasNoData = !hasDatePattern && !hasBagLimitKeywords && wordCount < 300;
  const isLandingPage = hasNoData || (lower.includes('learn more') && lower.includes('get started') && !hasDatePattern);
  
  // Must have at least dates OR bag limits AND some structure
  const isExtractable = !isLandingPage && (hasDatePattern || (hasBagLimitKeywords && hasTable) || isPdf);
  
  let reason = '';
  if (!isExtractable) {
    if (isLandingPage) reason = 'Landing/hub page (use portal links)';
    else if (!hasDatePattern && !hasBagLimitKeywords) reason = 'No regulation data found';
    else reason = 'Insufficient structure for extraction';
  }
  
  return {
    hasTable,
    hasDatePattern,
    hasSeasonKeywords,
    hasBagLimitKeywords,
    isPdf,
    isExtractable,
    reason
  };
}

interface ExtractedSeason {
  name: string;
  start_date?: string;
  end_date?: string;
  notes?: string;
}

interface ExtractedBagLimit {
  label: string;
  value: string;
  notes?: string;
}

interface ExtractedData {
  seasons: ExtractedSeason[];
  bag_limits: ExtractedBagLimit[];
  legal_methods: string[];
  notes: string[];
}

function extractWithRegex(content: string): ExtractedData {
  const data: ExtractedData = { seasons: [], bag_limits: [], legal_methods: [], notes: [] };
  
  const seasonPatterns = [
    { name: 'Archery', regex: /archery[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Muzzleloader', regex: /muzzleloader[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Rifle', regex: /rifle[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Firearm', regex: /firearm[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'General', regex: /general\s+season[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Spring Turkey', regex: /spring\s+(?:turkey\s+)?season[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Fall Turkey', regex: /fall\s+(?:turkey\s+)?season[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
  ];
  
  for (const { name, regex } of seasonPatterns) {
    const matches = content.matchAll(regex);
    for (const match of matches) {
      if (match[1] && match[2]) {
        data.seasons.push({ name: `${name} Season`, start_date: match[1].trim(), end_date: match[2].trim() });
      }
    }
  }
  
  // Bag limits with strict validation
  const bagPatterns = [/daily\s*(?:bag)?\s*limit[:\s]*(\d+)/gi, /bag\s*limit[:\s]*(\d+)/gi];
  for (const pattern of bagPatterns) {
    const matches = content.matchAll(pattern);
    for (const match of matches) {
      const val = parseInt(match[1]);
      if (val >= 1 && val <= 25 && !data.bag_limits.some(b => b.value === match[1])) {
        data.bag_limits.push({ label: 'Daily', value: match[1] });
      }
    }
  }
  
  const methods = ['rifle', 'shotgun', 'muzzleloader', 'bow', 'crossbow', 'archery', 'handgun'];
  for (const method of methods) {
    if (content.toLowerCase().includes(method)) data.legal_methods.push(method);
  }
  
  return data;
}

async function extractWithLLM(content: string, category: string, stateCode: string): Promise<ExtractedData | null> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  if (!openaiKey) return null;
  
  const model = Deno.env.get('OPENAI_MODEL') || 'gpt-4o-mini';
  
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${openaiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: `Extract ${category} hunting regulations. Output JSON: {"seasons":[{"name":"","start_date":"Mon DD","end_date":"Mon DD"}],"bag_limits":[{"label":"Daily","value":""}],"legal_methods":[],"notes":[]}. NO guessing - only extract what's explicitly stated.` },
          { role: 'user', content: `Extract ${category} regs for ${stateCode}:\n${content.substring(0, 8000)}` }
        ],
        temperature: 0.1,
        max_tokens: 800,
        response_format: { type: 'json_object' }
      }),
    });
    
    if (!response.ok) return null;
    const result = await response.json();
    const parsed = JSON.parse(result.choices?.[0]?.message?.content || '{}');
    return { seasons: parsed.seasons || [], bag_limits: parsed.bag_limits || [], legal_methods: parsed.legal_methods || [], notes: parsed.notes || [] };
  } catch { return null; }
}

function computeConfidence(data: ExtractedData, classification: PageClassification): number {
  if (!classification.isExtractable) return 0;
  
  let score = 0.5;
  if (classification.hasTable && classification.hasDatePattern) score += 0.3;
  if (data.seasons.length >= 2) score += 0.15;
  if (data.bag_limits.length >= 1) score += 0.05;
  if (classification.isPdf) score -= 0.15;
  
  return Math.max(0, Math.min(1, score));
}

function toSummaryJson(data: ExtractedData): object | null {
  if (data.seasons.length === 0 && data.bag_limits.length === 0) return null;
  return {
    seasons: data.seasons,
    bag_limits: data.bag_limits.map(b => ({ species: 'General', daily: b.value, notes: b.notes })),
    weapons: data.legal_methods.map(m => ({ name: m.charAt(0).toUpperCase() + m.slice(1), allowed: true })),
    notes: data.notes
  };
}

async function processSource(
  source: any,
  supabase: any,
  seasonYearLabel: string,
  yearStart: number,
  now: string
): Promise<{ checked: number; autoApproved: number; pending: number; skipped: number; result: any }> {
  const regionKey = source.region_key || 'STATEWIDE';
  const regionLabel = source.region_label || 'Statewide';
  
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
    
    const response = await fetch(source.source_url, {
      headers: { "User-Agent": "TheSkinning Shed/5.0", "Accept": "text/html,application/pdf,*/*" },
      signal: controller.signal
    });
    clearTimeout(timeout);
    
    if (!response.ok) {
      return { checked: 0, autoApproved: 0, pending: 0, skipped: 1, result: { state: source.state_code, category: source.category, status: 'http_error', error: `HTTP ${response.status}` } };
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
      return { checked: 1, autoApproved: 0, pending: 0, skipped: 0, result: { state: source.state_code, category: source.category, status: 'unchanged' } };
    }
    
    // Classify page
    const textContent = extractTextContent(rawContent);
    const classification = classifyPage(textContent, contentType);
    
    // If not extractable, mark source and skip - DO NOT create pending
    if (!classification.isExtractable) {
      await supabase.from('state_regulations_sources').update({ 
        content_hash: newHash, 
        source_type: 'portal_only',
        updated_at: now 
      }).eq('id', source.id);
      
      // Log to audit but no pending
      await supabase.from('state_regulations_audit_log').insert({
        state_code: source.state_code,
        category: source.category,
        region_key: regionKey,
        detected_at: now,
        approval_mode: 'skipped',
        diff_summary: classification.reason,
        extraction_warnings: [classification.reason],
      });
      
      return { checked: 1, autoApproved: 0, pending: 0, skipped: 1, result: { state: source.state_code, category: source.category, status: 'not_extractable', reason: classification.reason } };
    }
    
    // Extract data
    let extractedData = extractWithRegex(textContent);
    let usedLlm = false;
    
    if (extractedData.seasons.length === 0 && !classification.isPdf) {
      const llmData = await extractWithLLM(textContent, source.category, source.state_code);
      if (llmData && llmData.seasons.length > 0) {
        extractedData = llmData;
        usedLlm = true;
      }
    }
    
    const confidence = computeConfidence(extractedData, classification);
    const summaryJson = toSummaryJson(extractedData);
    
    // If no meaningful data extracted, skip pending
    if (!summaryJson) {
      await supabase.from('state_regulations_sources').update({ content_hash: newHash, updated_at: now }).eq('id', source.id);
      return { checked: 1, autoApproved: 0, pending: 0, skipped: 1, result: { state: source.state_code, category: source.category, status: 'no_data_extracted' } };
    }
    
    const diffSummary = `Seasons: ${extractedData.seasons.length}, Limits: ${extractedData.bag_limits.length}${usedLlm ? ' (LLM)' : ''}`;
    let approvalMode: string;
    let approvedRowId: string | null = null;
    
    // Auto-approve if high confidence
    if (confidence >= AUTO_APPROVE_THRESHOLD) {
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
          confidence_score: confidence,
          approval_mode: 'auto',
          approved_by: 'AUTO_V5',
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
      const pendingReason = confidence < 0.5 ? 'Low confidence extraction' : 'Requires manual review';
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
        confidence_score: confidence,
        extraction_warnings: [],
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
      confidence_score: confidence,
      approval_mode: approvalMode,
      diff_summary: diffSummary,
      approved_row_id: approvedRowId,
    });
    
    return {
      checked: 1,
      autoApproved: approvalMode === 'auto' ? 1 : 0,
      pending: approvalMode === 'pending' ? 1 : 0,
      skipped: 0,
      result: { state: source.state_code, category: source.category, status: approvalMode, confidence: Math.round(confidence * 100) / 100, seasons: extractedData.seasons.length, usedLlm }
    };
    
  } catch (fetchError) {
    return { checked: 0, autoApproved: 0, pending: 0, skipped: 1, result: { state: source.state_code, category: source.category, status: 'fetch_error', error: (fetchError as Error).message?.substring(0, 100) } };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  
  try {
    const auth = await requireAdmin(req);
    if (!auth.ok) {
      return new Response(JSON.stringify(auth), {
        status: auth.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    const supabase = auth.admin!;
    
    // Only fetch extractable sources
    const { data: sources, error: sourcesError } = await supabase
      .from('state_regulations_sources')
      .select('*')
      .in('source_type', ['extractable', 'season_schedule', 'reg_summary'])
      .order('priority', { ascending: false })
      .order('state_code').order('category');
    
    if (sourcesError) throw new Error(`Failed to fetch sources: ${sourcesError.message}`);
    if (!sources || sources.length === 0) {
      return new Response(JSON.stringify({ message: 'No extractable sources', checked: 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    
    const seasonYearLabel = getSeasonYearLabel();
    const yearStart = getYearStart();
    const now = iso(new Date())!;
    
    let totalChecked = 0, totalAutoApproved = 0, totalPending = 0, totalSkipped = 0;
    const allResults: any[] = [];
    
    for (let i = 0; i < sources.length; i += BATCH_SIZE) {
      const batch = sources.slice(i, i + BATCH_SIZE);
      const results = await Promise.all(batch.map(s => processSource(s, supabase, seasonYearLabel, yearStart, now)));
      for (const r of results) {
        totalChecked += r.checked;
        totalAutoApproved += r.autoApproved;
        totalPending += r.pending;
        totalSkipped += r.skipped;
        allResults.push(r.result);
      }
    }
    
    const byCategory: Record<string, any> = {};
    for (const r of allResults) {
      if (!byCategory[r.category]) byCategory[r.category] = { checked: 0, auto: 0, pending: 0, skipped: 0 };
      if (r.status === 'unchanged' || r.status === 'auto' || r.status === 'pending') byCategory[r.category].checked++;
      if (r.status === 'auto') byCategory[r.category].auto++;
      if (r.status === 'pending') byCategory[r.category].pending++;
      if (['not_extractable', 'no_data_extracted', 'fetch_error', 'http_error'].includes(r.status)) byCategory[r.category].skipped++;
    }
    
    return new Response(JSON.stringify({
      message: 'Check complete (v5 portal-first)',
      checked: totalChecked,
      auto_approved: totalAutoApproved,
      pending: totalPending,
      skipped: totalSkipped,
      total_sources: sources.length,
      season: seasonYearLabel,
      extraction_version: EXTRACTION_VERSION,
      by_category: byCategory,
      results: allResults
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    
  } catch (error) {
    console.error('regulations-check-v5 error:', error);
    return new Response(JSON.stringify({ error: (error as Error).message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
