import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * regulations-check-v3 Edge Function (v3.1.0)
 * 
 * Enhanced checker with:
 * - PARALLEL batch processing (5 concurrent) for speed
 * - Stricter extraction - no hallucinated data
 * - Confidence scoring with auto-approval threshold
 * - Audit logging for all changes
 */

const EXTRACTION_VERSION = "v3.1.0";
const AUTO_APPROVE_THRESHOLD = 0.85;
const BATCH_SIZE = 5; // Process 5 sources concurrently
const FETCH_TIMEOUT = 15000; // 15s timeout per fetch

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Known legal hunting methods for normalization
const KNOWN_METHODS = [
  'rifle', 'shotgun', 'muzzleloader', 'bow', 'crossbow', 
  'archery', 'handgun', 'primitive', 'any legal weapon'
];

/**
 * Safe ISO timestamp helper
 */
function iso(v: unknown): string | null {
  if (!v) return null;
  if (v instanceof Date) {
    return isNaN(v.getTime()) ? null : v.toISOString();
  }
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

// SHA-256 hash
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

// Normalize HTML content - strip scripts, styles, keep structure
function normalizeContent(html: string): string {
  let content = html;
  content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  content = content.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '');
  content = content.replace(/<!--[\s\S]*?-->/g, '');
  content = content.replace(/\s+/g, ' ').trim();
  return content;
}

/**
 * Check if page looks like a structured regulations page (has tables with dates)
 */
function isLikelyRegulationsPage(content: string): boolean {
  const lower = content.toLowerCase();
  
  // Must have table or list structure
  const hasTable = lower.includes('<table') || lower.includes('<ul') || lower.includes('<ol');
  
  // Must have date patterns
  const hasDatePattern = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}/i.test(content) ||
                         /\d{1,2}\/\d{1,2}\/\d{2,4}/.test(content);
  
  // Must have hunting/fishing keywords
  const hasKeywords = /\b(season|bag limit|daily limit|possession|legal|hunting|fishing)\b/i.test(content);
  
  return hasTable && hasDatePattern && hasKeywords;
}

// Extract structured data from content - STRICT, no hallucination
interface ExtractedData {
  seasons: Array<{ name: string; start?: string; end?: string; notes?: string }>;
  bag_limits: Array<{ label: string; value: string; notes?: string }>;
  legal_methods: string[];
  notes: string[];
}

function extractRegulationData(content: string, category: string): ExtractedData {
  const data: ExtractedData = {
    seasons: [],
    bag_limits: [],
    legal_methods: [],
    notes: []
  };
  
  // Only extract if page looks like actual regulations
  if (!isLikelyRegulationsPage(content)) {
    return data; // Return empty - don't hallucinate
  }
  
  // Look for season patterns with dates
  const seasonKeywords = [
    'general season', 'archery season', 'muzzleloader season', 
    'rifle season', 'firearm season', 'bow season', 'youth season',
    'spring season', 'fall season', 'early season', 'late season'
  ];
  
  for (const keyword of seasonKeywords) {
    const regex = new RegExp(`${keyword}[^<]{0,100}?([A-Z][a-z]+\\.?\\s+\\d{1,2})[^<]{0,30}?[-–][^<]{0,30}?([A-Z][a-z]+\\.?\\s+\\d{1,2})`, 'gi');
    const matches = content.matchAll(regex);
    for (const match of matches) {
      const start = match[1]?.trim();
      const end = match[2]?.trim();
      if (start && end && isValidDateString(start) && isValidDateString(end)) {
        data.seasons.push({
          name: keyword.charAt(0).toUpperCase() + keyword.slice(1),
          start,
          end
        });
      }
    }
  }
  
  // Extract bag limits ONLY if they look reasonable
  const bagPatterns = [
    { pattern: /daily\s*(?:bag)?\s*limit[:\s]*(\d+)/gi, label: 'Daily' },
    { pattern: /bag\s*limit[:\s]*(\d+)\s*(?:per\s*)?day/gi, label: 'Daily' },
    { pattern: /(\d+)\s*per\s*day/gi, label: 'Daily' },
    { pattern: /season\s*(?:bag)?\s*limit[:\s]*(\d+)/gi, label: 'Season' },
    { pattern: /annual\s*limit[:\s]*(\d+)/gi, label: 'Season' },
  ];
  
  for (const { pattern, label } of bagPatterns) {
    const matches = content.matchAll(pattern);
    for (const match of matches) {
      const val = parseInt(match[1]);
      // STRICT: Only include reasonable bag limits (1-25 for daily, 1-50 for season)
      const maxLimit = label === 'Daily' ? 25 : 50;
      if (!isNaN(val) && val >= 1 && val <= maxLimit) {
        // Avoid duplicates
        if (!data.bag_limits.some(b => b.label === label && b.value === match[1])) {
          data.bag_limits.push({ label, value: match[1] });
        }
      }
    }
  }
  
  // Extract legal methods (only if clearly in hunting context)
  const huntingContext = /\b(legal\s*(?:methods?|weapons?|firearms?)|(?:may|can)\s*use)\b/i.test(content);
  if (huntingContext) {
    for (const method of KNOWN_METHODS) {
      if (content.toLowerCase().includes(method)) {
        data.legal_methods.push(method);
      }
    }
  }
  
  // Extract antler restriction notes
  const restrictionPatterns = [
    /antler\s*restriction[^.]{10,80}\./gi,
    /must\s*have\s*(?:at\s*least)?\s*\d+\s*points?[^.]{0,50}\./gi,
  ];
  
  for (const pattern of restrictionPatterns) {
    const matches = content.matchAll(pattern);
    for (const match of matches) {
      const note = match[0].replace(/<[^>]*>/g, '').trim();
      if (note.length > 15 && note.length < 200) {
        data.notes.push(note);
      }
    }
  }
  
  return data;
}

function isValidDateString(dateStr: string): boolean {
  const patterns = [
    /^[A-Z][a-z]+\.?\s+\d{1,2}$/,
    /^\d{1,2}\/\d{1,2}$/
  ];
  return patterns.some(p => p.test(dateStr.trim()));
}

interface ValidationResult {
  valid: boolean;
  warnings: string[];
  isLinkOnly: boolean; // True if we couldn't extract structured data
}

function validateExtraction(data: ExtractedData, isStructuredPage: boolean): ValidationResult {
  const warnings: string[] = [];
  
  // If page doesn't look like regulations, mark as link-only
  if (!isStructuredPage) {
    return {
      valid: false,
      warnings: ['Page appears to be landing page, not regulation details'],
      isLinkOnly: true
    };
  }
  
  if (data.seasons.length === 0) {
    warnings.push('No seasons detected');
  }
  
  for (const season of data.seasons) {
    if (season.start && !isValidDateString(season.start)) {
      warnings.push(`Ambiguous start date: ${season.start}`);
    }
    if (season.end && !isValidDateString(season.end)) {
      warnings.push(`Ambiguous end date: ${season.end}`);
    }
  }
  
  if (data.legal_methods.length === 0 && data.seasons.length > 0) {
    warnings.push('No legal methods detected');
  }
  
  return {
    valid: data.seasons.length > 0 || data.bag_limits.length > 0,
    warnings,
    isLinkOnly: false
  };
}

function computeConfidence(
  content: string,
  data: ExtractedData,
  validation: ValidationResult,
  isPdf: boolean,
  isStructuredPage: boolean
): number {
  // Link-only pages get 0 confidence for auto-approve
  if (validation.isLinkOnly) return 0;
  
  let score = 1.0;
  
  // Major penalties
  if (isPdf) score -= 0.35;
  if (!isStructuredPage) score -= 0.40;
  if (data.seasons.length === 0) score -= 0.30;
  if (validation.warnings.some(w => w.includes('Ambiguous'))) score -= 0.25;
  
  // Bonuses for good extraction
  if (content.toLowerCase().includes('<table') && data.seasons.length > 0) {
    score += 0.15;
  }
  if (data.seasons.length >= 2 && data.bag_limits.length >= 1) {
    score += 0.10;
  }
  
  return Math.max(0, Math.min(1, score));
}

function toSummaryJson(data: ExtractedData, isLinkOnly: boolean): object | null {
  // Return null for link-only sources
  if (isLinkOnly || (data.seasons.length === 0 && data.bag_limits.length === 0 && data.notes.length === 0)) {
    return null;
  }
  
  return {
    seasons: data.seasons.map(s => ({
      name: s.name,
      start_date: s.start,
      end_date: s.end,
      notes: s.notes
    })),
    bag_limits: data.bag_limits.map(b => ({
      species: 'General',
      daily: b.label === 'Daily' ? b.value : null,
      season: b.label === 'Season' ? b.value : null,
      notes: b.notes
    })),
    weapons: data.legal_methods.map(m => ({
      name: m.charAt(0).toUpperCase() + m.slice(1),
      allowed: true
    })),
    notes: data.notes
  };
}

// Process a batch of sources concurrently
async function processBatch(
  sources: any[],
  supabase: any,
  seasonYearLabel: string,
  yearStart: number,
  now: string
): Promise<{
  checked: number;
  autoApproved: number;
  pending: number;
  results: any[];
}> {
  const results = await Promise.all(sources.map(async (source) => {
    const regionKey = source.region_key || 'STATEWIDE';
    const regionLabel = source.region_label || 'Statewide';
    
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);

      const response = await fetch(source.source_url, {
        headers: {
          "User-Agent": "TheSkinning Shed Regulations Checker/3.1",
          "Accept": "text/html,application/xhtml+xml,*/*"
        },
        signal: controller.signal
      });

      clearTimeout(timeout);

      if (!response.ok) {
        return {
          checked: 0,
          autoApproved: 0,
          pending: 0,
          result: {
            state: source.state_code,
            category: source.category,
            region: regionKey,
            status: "http_error",
            error: `HTTP ${response.status}`
          }
        };
      }

      const contentType = response.headers.get('content-type') || '';
      const isPdf = contentType.includes('pdf');
      
      const rawContent = await response.text();
      const normalizedContent = normalizeContent(rawContent);
      const newHash = await hashContent(normalizedContent);
      const isStructuredPage = isLikelyRegulationsPage(normalizedContent);
      
      // Update last checked
      await supabase
        .from("state_regulations_sources")
        .update({ last_checked_at: now })
        .eq("id", source.id);
      
      const previousHash = source.content_hash;
      const hasChanged = previousHash && previousHash !== newHash;
      const isNew = !previousHash;

      if (!hasChanged && !isNew) {
        await supabase
          .from("state_regulations_sources")
          .update({ content_hash: newHash, updated_at: now })
          .eq("id", source.id);
          
        return {
          checked: 1,
          autoApproved: 0,
          pending: 0,
          result: {
            state: source.state_code,
            category: source.category,
            region: regionKey,
            status: "unchanged"
          }
        };
      }

      // Extract and validate
      const extractedData = extractRegulationData(normalizedContent, source.category);
      const validation = validateExtraction(extractedData, isStructuredPage);
      const confidence = computeConfidence(
        normalizedContent,
        extractedData,
        validation,
        isPdf,
        isStructuredPage
      );
      
      const summaryJson = toSummaryJson(extractedData, validation.isLinkOnly);
      const diffSummary = isNew 
        ? (validation.isLinkOnly ? 'Link-only source (no structured data)' : 'Initial content extraction')
        : `Content changed. Confidence: ${(confidence * 100).toFixed(0)}%. Seasons: ${extractedData.seasons.length}, Limits: ${extractedData.bag_limits.length}`;

      let approvalMode: string;
      let approvedRowId: string | null = null;
      let pendingRowId: string | null = null;

      // Only auto-approve if we have good data AND high confidence
      if (confidence >= AUTO_APPROVE_THRESHOLD && validation.valid && summaryJson !== null) {
        const { data: approvedRow, error: approveError } = await supabase
          .from("state_regulations_approved")
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
            approved_by: 'AUTO',
            extraction_version: EXTRACTION_VERSION,
            approved_at: now,
            updated_at: now,
          }, {
            onConflict: "state_code,category,season_year_label,region_key"
          })
          .select('id')
          .single();

        if (approveError) {
          console.error(`Auto-approve error: ${approveError.message}`);
          approvalMode = 'pending';
        } else {
          approvalMode = 'auto';
          approvedRowId = approvedRow?.id || null;
          
          await supabase
            .from("state_regulations_sources")
            .update({ 
              content_hash: newHash, 
              last_approved_hash: newHash,
              updated_at: now 
            })
            .eq("id", source.id);
        }
      } else {
        approvalMode = 'pending';
      }

      if (approvalMode === 'pending') {
        // Only insert pending if we have some data or it's a new source
        if (summaryJson !== null || isNew) {
          const { data: pendingRow, error: pendingError } = await supabase
            .from("state_regulations_pending")
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
              status: 'pending',
              created_at: now,
              updated_at: now,
            }, {
              onConflict: "state_code,category,season_year_label,region_key"
            })
            .select('id')
            .single();

          if (!pendingError) {
            pendingRowId = pendingRow?.id || null;
          }
        }
        
        await supabase
          .from("state_regulations_sources")
          .update({ content_hash: newHash, updated_at: now })
          .eq("id", source.id);
      }

      // Write audit log
      await supabase.from("state_regulations_audit_log").insert({
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
        pending: (approvalMode === 'pending' && (summaryJson !== null || isNew)) ? 1 : 0,
        result: {
          state: source.state_code,
          category: source.category,
          region: regionKey,
          status: approvalMode === 'auto' ? 'auto_approved' : (validation.isLinkOnly ? 'link_only' : 'pending'),
          confidence: Math.round(confidence * 100) / 100,
          warnings: validation.warnings.length > 0 ? validation.warnings : undefined
        }
      };

    } catch (fetchError) {
      const errorMsg = fetchError instanceof Error ? fetchError.message : String(fetchError);
      return {
        checked: 0,
        autoApproved: 0,
        pending: 0,
        result: {
          state: source.state_code,
          category: source.category,
          region: regionKey,
          status: "fetch_error",
          error: errorMsg.substring(0, 100)
        }
      };
    }
  }));

  return {
    checked: results.reduce((sum, r) => sum + r.checked, 0),
    autoApproved: results.reduce((sum, r) => sum + r.autoApproved, 0),
    pending: results.reduce((sum, r) => sum + r.pending, 0),
    results: results.map(r => r.result)
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    });

    // Fetch ALL sources (no pagination needed for < 1000)
    const { data: sources, error: sourcesError } = await supabase
      .from("state_regulations_sources")
      .select("*")
      .order('state_code')
      .order('category');

    if (sourcesError) {
      throw new Error(`Failed to fetch sources: ${sourcesError.message}`);
    }

    if (!sources || sources.length === 0) {
      return new Response(
        JSON.stringify({ message: "No sources to check", checked: 0, auto_approved: 0, pending: 0, total_sources: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const seasonYearLabel = getSeasonYearLabel();
    const yearStart = getYearStart();
    const now = iso(new Date())!;
    
    let totalChecked = 0;
    let totalAutoApproved = 0;
    let totalPending = 0;
    const allResults: any[] = [];

    // Process in batches for parallelism
    for (let i = 0; i < sources.length; i += BATCH_SIZE) {
      const batch = sources.slice(i, i + BATCH_SIZE);
      const batchResult = await processBatch(batch, supabase, seasonYearLabel, yearStart, now);
      
      totalChecked += batchResult.checked;
      totalAutoApproved += batchResult.autoApproved;
      totalPending += batchResult.pending;
      allResults.push(...batchResult.results);
    }

    // Summarize by category
    const byCategory: Record<string, { checked: number; auto: number; pending: number; errors: number }> = {};
    for (const r of allResults) {
      if (!byCategory[r.category]) {
        byCategory[r.category] = { checked: 0, auto: 0, pending: 0, errors: 0 };
      }
      if (r.status === 'unchanged' || r.status === 'auto_approved' || r.status === 'pending' || r.status === 'link_only') {
        byCategory[r.category].checked++;
      }
      if (r.status === 'auto_approved') byCategory[r.category].auto++;
      if (r.status === 'pending') byCategory[r.category].pending++;
      if (r.status === 'fetch_error' || r.status === 'http_error') byCategory[r.category].errors++;
    }

    return new Response(
      JSON.stringify({
        message: "Check complete",
        checked: totalChecked,
        auto_approved: totalAutoApproved,
        pending: totalPending,
        total_sources: sources.length,
        season: seasonYearLabel,
        extraction_version: EXTRACTION_VERSION,
        auto_approve_threshold: AUTO_APPROVE_THRESHOLD,
        by_category: byCategory,
        results: allResults
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : undefined;
    console.error("regulations-check-v3 error:", errorMsg);
    if (errorStack) console.error("Stack:", errorStack);
    return new Response(
      JSON.stringify({ 
        error: errorMsg,
        stack: errorStack,
        timestamp: iso(new Date())
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
