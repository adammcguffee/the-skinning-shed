import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * regulations-check-v4 Edge Function
 * 
 * Features:
 * - Source type classification (season_schedule, reg_summary, landing)
 * - LLM-assisted extraction with strict JSON schema
 * - Hard validation of dates, bag limits
 * - Pending reasons for UX
 * - Parallel batch processing
 */

const EXTRACTION_VERSION = "v4.0.0";
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
  if (typeof v === 'number') {
    const d = new Date(v);
    return isNaN(d.getTime()) ? null : d.toISOString();
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
  content = content.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '');
  content = content.replace(/<!--[\s\S]*?-->/g, '');
  content = content.replace(/<[^>]+>/g, ' ');
  content = content.replace(/\s+/g, ' ').trim();
  return content;
}

// Extract just text content, preserving some structure
function extractTextContent(html: string): string {
  let content = html;
  content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  content = content.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '');
  content = content.replace(/<!--[\s\S]*?-->/g, '');
  // Keep table structure hints
  content = content.replace(/<tr[^>]*>/gi, '\n[ROW]');
  content = content.replace(/<\/tr>/gi, '[/ROW]');
  content = content.replace(/<t[hd][^>]*>/gi, ' | ');
  content = content.replace(/<\/t[hd]>/gi, '');
  content = content.replace(/<br\s*\/?>/gi, '\n');
  content = content.replace(/<\/p>/gi, '\n');
  content = content.replace(/<\/div>/gi, '\n');
  content = content.replace(/<\/li>/gi, '\n');
  content = content.replace(/<[^>]+>/g, ' ');
  content = content.replace(/&nbsp;/gi, ' ');
  content = content.replace(/&amp;/gi, '&');
  content = content.replace(/\s+/g, ' ').trim();
  // Limit to 12000 chars for LLM
  return content.substring(0, 12000);
}

interface PageClassification {
  hasTable: boolean;
  hasDatePattern: boolean;
  hasSeasonKeywords: boolean;
  hasBagLimitKeywords: boolean;
  isPdf: boolean;
  isLanding: boolean;
  confidence: number;
}

function classifyPage(content: string, isPdf: boolean): PageClassification {
  const lower = content.toLowerCase();
  
  const hasTable = lower.includes('<table') || lower.includes('[row]');
  const hasDatePattern = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}/i.test(content) ||
                         /\d{1,2}\/\d{1,2}(\/\d{2,4})?/.test(content);
  const hasSeasonKeywords = /\b(season|archery|muzzleloader|rifle|firearm|youth|general)\s+(season|dates|opens|closes)\b/i.test(content);
  const hasBagLimitKeywords = /\b(bag\s*limit|daily\s*limit|possession\s*limit|per\s*day|antler)\b/i.test(content);
  
  // Landing page heuristics: short content, no dates, mostly navigation
  const wordCount = content.split(/\s+/).length;
  const isLanding = (!hasDatePattern && !hasSeasonKeywords && wordCount < 500) || 
                    (lower.includes('learn more') && lower.includes('get started') && !hasDatePattern);
  
  let confidence = 0.5;
  if (hasTable && hasDatePattern) confidence += 0.3;
  if (hasSeasonKeywords) confidence += 0.15;
  if (hasBagLimitKeywords) confidence += 0.1;
  if (isPdf) confidence -= 0.2;
  if (isLanding) confidence = 0.1;
  
  return {
    hasTable,
    hasDatePattern,
    hasSeasonKeywords,
    hasBagLimitKeywords,
    isPdf,
    isLanding,
    confidence: Math.max(0, Math.min(1, confidence)),
  };
}

interface ExtractedSeason {
  name: string;
  start_date?: string;
  end_date?: string;
  weapons?: string[];
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

// Simple regex-based extraction (fast, cheap)
function extractWithRegex(content: string, category: string): ExtractedData {
  const data: ExtractedData = {
    seasons: [],
    bag_limits: [],
    legal_methods: [],
    notes: []
  };
  
  // Season patterns
  const seasonPatterns = [
    { name: 'Archery', regex: /archery[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Muzzleloader', regex: /muzzleloader[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Rifle', regex: /rifle[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Firearm', regex: /firearm[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'General', regex: /general\s+season[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Spring', regex: /spring\s+(?:turkey\s+)?season[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
    { name: 'Fall', regex: /fall\s+(?:turkey\s+)?season[^:]*:?[^\d]*(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi },
  ];
  
  for (const { name, regex } of seasonPatterns) {
    const matches = content.matchAll(regex);
    for (const match of matches) {
      if (match[1] && match[2]) {
        data.seasons.push({
          name: `${name} Season`,
          start_date: match[1].trim(),
          end_date: match[2].trim()
        });
      }
    }
  }
  
  // Bag limits
  const bagPatterns = [
    /daily\s*(?:bag)?\s*limit[:\s]*(\d+)/gi,
    /bag\s*limit[:\s]*(\d+)/gi,
    /(\d+)\s*(?:deer|turkey|fish)?\s*per\s*day/gi,
  ];
  
  for (const pattern of bagPatterns) {
    const matches = content.matchAll(pattern);
    for (const match of matches) {
      const val = parseInt(match[1]);
      if (val >= 1 && val <= 25) {
        if (!data.bag_limits.some(b => b.value === match[1])) {
          data.bag_limits.push({ label: 'Daily', value: match[1] });
        }
      }
    }
  }
  
  // Legal methods
  const methods = ['rifle', 'shotgun', 'muzzleloader', 'bow', 'crossbow', 'archery', 'handgun'];
  for (const method of methods) {
    if (content.toLowerCase().includes(method)) {
      data.legal_methods.push(method);
    }
  }
  
  return data;
}

// LLM extraction using OpenAI
async function extractWithLLM(content: string, category: string, stateCode: string): Promise<ExtractedData | null> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  if (!openaiKey) {
    console.log('OPENAI_API_KEY not set, skipping LLM extraction');
    return null;
  }
  
  const model = Deno.env.get('OPENAI_MODEL') || 'gpt-4o-mini';
  
  const systemPrompt = `You are extracting hunting/fishing regulation data from state wildlife agency pages.
Extract ONLY information that is explicitly stated. DO NOT invent or guess any values.
If information is missing, leave the field empty or omit it.

Output strict JSON matching this schema:
{
  "seasons": [{"name": "string", "start_date": "Mon DD", "end_date": "Mon DD", "notes": "optional"}],
  "bag_limits": [{"label": "Daily|Season", "value": "number as string", "notes": "optional"}],
  "legal_methods": ["rifle", "bow", etc],
  "notes": ["any important restrictions or rules"]
}

Rules:
- Dates should be in "Mon DD" format (e.g., "Oct 15", "Jan 1")
- Bag limits must be reasonable numbers (1-50)
- Only include seasons for the current category (${category})
- If you cannot find clear dates, return empty seasons array
- Never make up information`;

  const userPrompt = `Extract ${category} hunting regulations for ${stateCode} from this content:\n\n${content}`;
  
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
        max_tokens: 1000,
        response_format: { type: 'json_object' }
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
    console.error('LLM extraction error:', e);
    return null;
  }
}

interface ValidationResult {
  valid: boolean;
  warnings: string[];
  pendingReason: string;
}

function validateExtraction(data: ExtractedData, category: string, classification: PageClassification): ValidationResult {
  const warnings: string[] = [];
  let pendingReason = '';
  
  // Landing page -> always pending with reason
  if (classification.isLanding) {
    return {
      valid: false,
      warnings: ['Landing page detected'],
      pendingReason: 'Landing page: no regulation details found'
    };
  }
  
  // PDF with no extraction
  if (classification.isPdf && data.seasons.length === 0) {
    return {
      valid: false,
      warnings: ['PDF content, no seasons extracted'],
      pendingReason: 'PDF: requires manual review'
    };
  }
  
  // No seasons for deer/turkey is suspicious
  if ((category === 'deer' || category === 'turkey') && data.seasons.length === 0) {
    warnings.push('No seasons detected for hunting category');
    pendingReason = 'No season dates found';
  }
  
  // Validate season dates
  const monthNames = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  for (const season of data.seasons) {
    if (season.start_date) {
      const monthMatch = season.start_date.toLowerCase().match(/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/);
      if (!monthMatch) {
        warnings.push(`Invalid start date format: ${season.start_date}`);
      }
    }
    if (season.end_date) {
      const monthMatch = season.end_date.toLowerCase().match(/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/);
      if (!monthMatch) {
        warnings.push(`Invalid end date format: ${season.end_date}`);
      }
    }
  }
  
  // Validate bag limits
  for (const limit of data.bag_limits) {
    const val = parseInt(limit.value);
    if (isNaN(val) || val < 1 || val > 50) {
      warnings.push(`Suspicious bag limit: ${limit.value}`);
    }
  }
  
  const hasValidSeasons = data.seasons.length > 0 && warnings.filter(w => w.includes('Invalid')).length === 0;
  const valid = hasValidSeasons || (category === 'fishing' && data.bag_limits.length > 0);
  
  if (!valid && !pendingReason) {
    pendingReason = warnings.length > 0 ? warnings[0] : 'Extraction incomplete';
  }
  
  return { valid, warnings, pendingReason };
}

function computeConfidence(
  data: ExtractedData,
  classification: PageClassification,
  validation: ValidationResult,
  usedLlm: boolean
): number {
  let score = classification.confidence;
  
  if (classification.isLanding) return 0;
  if (!validation.valid) score -= 0.3;
  if (validation.warnings.length > 0) score -= 0.1 * validation.warnings.length;
  
  // Bonus for good extraction
  if (data.seasons.length >= 2) score += 0.15;
  if (data.bag_limits.length >= 1) score += 0.05;
  if (data.legal_methods.length >= 2) score += 0.05;
  
  // LLM extraction bonus if successful
  if (usedLlm && data.seasons.length > 0) score += 0.1;
  
  return Math.max(0, Math.min(1, score));
}

function toSummaryJson(data: ExtractedData): object | null {
  if (data.seasons.length === 0 && data.bag_limits.length === 0 && data.notes.length === 0) {
    return null;
  }
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
): Promise<{ checked: number; autoApproved: number; pending: number; result: any }> {
  const regionKey = source.region_key || 'STATEWIDE';
  const regionLabel = source.region_label || 'Statewide';
  const sourceType = source.source_type || 'season_schedule';
  
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
    
    const response = await fetch(source.source_url, {
      headers: {
        "User-Agent": "TheSkinning Shed Regulations Checker/4.0",
        "Accept": "text/html,application/xhtml+xml,application/pdf,*/*"
      },
      signal: controller.signal
    });
    clearTimeout(timeout);
    
    if (!response.ok) {
      return {
        checked: 0, autoApproved: 0, pending: 0,
        result: { state: source.state_code, category: source.category, region: regionKey, status: 'http_error', error: `HTTP ${response.status}` }
      };
    }
    
    const contentType = response.headers.get('content-type') || '';
    const isPdf = contentType.includes('pdf');
    
    const rawContent = await response.text();
    const normalizedContent = normalizeHtml(rawContent);
    const newHash = await hashContent(normalizedContent);
    
    // Update last checked
    await supabase.from('state_regulations_sources').update({ last_checked_at: now }).eq('id', source.id);
    
    const previousHash = source.content_hash;
    const hasChanged = previousHash && previousHash !== newHash;
    const isNew = !previousHash;
    
    if (!hasChanged && !isNew) {
      await supabase.from('state_regulations_sources').update({ content_hash: newHash, updated_at: now }).eq('id', source.id);
      return {
        checked: 1, autoApproved: 0, pending: 0,
        result: { state: source.state_code, category: source.category, region: regionKey, status: 'unchanged' }
      };
    }
    
    // Classify page
    const textContent = extractTextContent(rawContent);
    const classification = classifyPage(textContent, isPdf);
    
    // Skip landing pages entirely - they have portal links
    if (sourceType === 'landing' || classification.isLanding) {
      await supabase.from('state_regulations_sources').update({ 
        content_hash: newHash, 
        source_type: 'landing',
        updated_at: now 
      }).eq('id', source.id);
      
      return {
        checked: 1, autoApproved: 0, pending: 0,
        result: { 
          state: source.state_code, category: source.category, region: regionKey, 
          status: 'landing_page', 
          note: 'Portal links available, no extraction needed' 
        }
      };
    }
    
    // Extract data
    let extractedData = extractWithRegex(textContent, source.category);
    let usedLlm = false;
    
    // If regex extraction insufficient, try LLM
    if (extractedData.seasons.length === 0 && !isPdf) {
      const llmData = await extractWithLLM(textContent, source.category, source.state_code);
      if (llmData && llmData.seasons.length > 0) {
        extractedData = llmData;
        usedLlm = true;
      }
    }
    
    const validation = validateExtraction(extractedData, source.category, classification);
    const confidence = computeConfidence(extractedData, classification, validation, usedLlm);
    const summaryJson = toSummaryJson(extractedData);
    
    const diffSummary = isNew 
      ? `Initial extraction. Seasons: ${extractedData.seasons.length}, Limits: ${extractedData.bag_limits.length}${usedLlm ? ' (LLM)' : ''}`
      : `Content changed. Confidence: ${(confidence * 100).toFixed(0)}%`;
    
    let approvalMode: string;
    let approvedRowId: string | null = null;
    let pendingRowId: string | null = null;
    
    // Auto-approve only if valid AND high confidence AND we have data
    if (confidence >= AUTO_APPROVE_THRESHOLD && validation.valid && summaryJson !== null) {
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
          approved_by: 'AUTO_V4',
          extraction_version: EXTRACTION_VERSION,
          approved_at: now,
          updated_at: now,
        }, { onConflict: 'state_code,category,season_year_label,region_key' })
        .select('id').single();
      
      if (!approveError) {
        approvalMode = 'auto';
        approvedRowId = approvedRow?.id || null;
        await supabase.from('state_regulations_sources').update({ 
          content_hash: newHash, 
          last_approved_hash: newHash,
          updated_at: now 
        }).eq('id', source.id);
      } else {
        approvalMode = 'pending';
      }
    } else {
      approvalMode = 'pending';
    }
    
    if (approvalMode === 'pending' && (summaryJson !== null || isNew)) {
      const { data: pendingRow } = await supabase
        .from('state_regulations_pending')
        .upsert({
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
          extraction_warnings: validation.warnings,
          pending_reason: validation.pendingReason || 'Requires review',
          status: 'pending',
          created_at: now,
          updated_at: now,
        }, { onConflict: 'state_code,category,season_year_label,region_key' })
        .select('id').single();
      
      pendingRowId = pendingRow?.id || null;
      await supabase.from('state_regulations_sources').update({ content_hash: newHash, updated_at: now }).eq('id', source.id);
    }
    
    // Audit log
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
      extraction_warnings: validation.warnings,
      approved_row_id: approvedRowId,
      pending_row_id: pendingRowId,
    });
    
    return {
      checked: 1,
      autoApproved: approvalMode === 'auto' ? 1 : 0,
      pending: approvalMode === 'pending' ? 1 : 0,
      result: {
        state: source.state_code,
        category: source.category,
        region: regionKey,
        status: approvalMode === 'auto' ? 'auto_approved' : 'pending',
        confidence: Math.round(confidence * 100) / 100,
        seasons: extractedData.seasons.length,
        usedLlm,
        pendingReason: approvalMode === 'pending' ? validation.pendingReason : undefined,
        warnings: validation.warnings.length > 0 ? validation.warnings : undefined
      }
    };
    
  } catch (fetchError) {
    const errorMsg = fetchError instanceof Error ? fetchError.message : String(fetchError);
    return {
      checked: 0, autoApproved: 0, pending: 0,
      result: { state: source.state_code, category: source.category, region: regionKey, status: 'fetch_error', error: errorMsg.substring(0, 100) }
    };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, { auth: { persistSession: false } });
    
    const { data: sources, error: sourcesError } = await supabase
      .from('state_regulations_sources')
      .select('*')
      .order('state_code').order('category');
    
    if (sourcesError) throw new Error(`Failed to fetch sources: ${sourcesError.message}`);
    if (!sources || sources.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No sources to check', checked: 0, auto_approved: 0, pending: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    const seasonYearLabel = getSeasonYearLabel();
    const yearStart = getYearStart();
    const now = iso(new Date())!;
    
    let totalChecked = 0, totalAutoApproved = 0, totalPending = 0;
    const allResults: any[] = [];
    
    // Process in batches
    for (let i = 0; i < sources.length; i += BATCH_SIZE) {
      const batch = sources.slice(i, i + BATCH_SIZE);
      const results = await Promise.all(
        batch.map(s => processSource(s, supabase, seasonYearLabel, yearStart, now))
      );
      for (const r of results) {
        totalChecked += r.checked;
        totalAutoApproved += r.autoApproved;
        totalPending += r.pending;
        allResults.push(r.result);
      }
    }
    
    // Summary by category
    const byCategory: Record<string, any> = {};
    for (const r of allResults) {
      if (!byCategory[r.category]) byCategory[r.category] = { checked: 0, auto: 0, pending: 0, landing: 0, errors: 0 };
      if (['unchanged', 'auto_approved', 'pending'].includes(r.status)) byCategory[r.category].checked++;
      if (r.status === 'auto_approved') byCategory[r.category].auto++;
      if (r.status === 'pending') byCategory[r.category].pending++;
      if (r.status === 'landing_page') byCategory[r.category].landing++;
      if (['fetch_error', 'http_error'].includes(r.status)) byCategory[r.category].errors++;
    }
    
    return new Response(
      JSON.stringify({
        message: 'Check complete',
        checked: totalChecked,
        auto_approved: totalAutoApproved,
        pending: totalPending,
        total_sources: sources.length,
        season: seasonYearLabel,
        extraction_version: EXTRACTION_VERSION,
        by_category: byCategory,
        results: allResults
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : undefined;
    console.error('regulations-check-v4 error:', errorMsg);
    return new Response(
      JSON.stringify({ error: errorMsg, stack: errorStack, timestamp: iso(new Date()) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
