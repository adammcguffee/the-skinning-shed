import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * regulations-check-v3 Edge Function
 * 
 * Enhanced checker with:
 * - Content extraction and normalization
 * - Structured data validation
 * - Confidence scoring
 * - Auto-approval for high-confidence changes (>=0.85)
 * - Audit logging for all changes
 * 
 * Flow per source:
 * 1. Fetch source URL
 * 2. Normalize content (strip scripts/styles)
 * 3. Compute hash, compare to previous
 * 4. If changed: extract, validate, compute confidence
 * 5. If confidence >= 0.85: auto-approve
 * 6. Else: create pending for admin review
 * 7. Log all changes to audit table
 */

const EXTRACTION_VERSION = "v3.0.1";
const AUTO_APPROVE_THRESHOLD = 0.85;

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
 * Converts various input types to ISO 8601 string or null
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

// Get current season year label
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
  
  // Remove script and style tags
  content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  content = content.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '');
  
  // Remove HTML comments
  content = content.replace(/<!--[\s\S]*?-->/g, '');
  
  // Normalize whitespace
  content = content.replace(/\s+/g, ' ').trim();
  
  return content;
}

// Extract structured data from content
interface ExtractedData {
  seasons: Array<{ name: string; start?: string; end?: string; weapons?: string[]; notes?: string }>;
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
  
  // Extract date patterns (various formats)
  const datePatterns = [
    /(\w+\.?\s+\d{1,2})\s*[-–]\s*(\w+\.?\s+\d{1,2})/gi,  // Oct. 1 - Jan. 15
    /(\d{1,2}\/\d{1,2})\s*[-–]\s*(\d{1,2}\/\d{1,2})/gi,   // 10/1 - 1/15
  ];
  
  // Look for season patterns
  const seasonKeywords = [
    'general season', 'archery season', 'muzzleloader season', 
    'rifle season', 'firearm season', 'bow season', 'youth season',
    'spring season', 'fall season', 'early season', 'late season'
  ];
  
  for (const keyword of seasonKeywords) {
    const regex = new RegExp(`${keyword}[^<]*?([A-Z][a-z]+\\.?\\s+\\d{1,2})[^<]*?[-–][^<]*?([A-Z][a-z]+\\.?\\s+\\d{1,2})`, 'gi');
    const matches = content.matchAll(regex);
    for (const match of matches) {
      data.seasons.push({
        name: keyword.charAt(0).toUpperCase() + keyword.slice(1),
        start: match[1],
        end: match[2]
      });
    }
  }
  
  // Extract bag limits
  const bagPatterns = [
    /(\d+)\s*(?:per\s+)?(?:day|daily)/gi,
    /(\d+)\s*(?:per\s+)?(?:season|annual)/gi,
    /bag\s*limit[:\s]*(\d+)/gi,
    /daily\s*limit[:\s]*(\d+)/gi
  ];
  
  for (const pattern of bagPatterns) {
    const matches = content.matchAll(pattern);
    for (const match of matches) {
      const context = content.substring(Math.max(0, match.index! - 50), match.index! + 50);
      data.bag_limits.push({
        label: match[0].includes('season') || match[0].includes('annual') ? 'Season' : 'Daily',
        value: match[1],
        notes: context.replace(/<[^>]*>/g, '').trim().substring(0, 100)
      });
    }
  }
  
  // Extract legal methods
  for (const method of KNOWN_METHODS) {
    if (content.toLowerCase().includes(method)) {
      data.legal_methods.push(method);
    }
  }
  
  // Extract any antler/size restrictions as notes
  const restrictionPatterns = [
    /antler\s*restriction[^.]*\./gi,
    /must\s*have[^.]*point[^.]*\./gi,
    /minimum[^.]*inch[^.]*\./gi
  ];
  
  for (const pattern of restrictionPatterns) {
    const matches = content.matchAll(pattern);
    for (const match of matches) {
      data.notes.push(match[0].replace(/<[^>]*>/g, '').trim());
    }
  }
  
  return data;
}

// Validate extracted data
interface ValidationResult {
  valid: boolean;
  warnings: string[];
}

function validateExtraction(data: ExtractedData): ValidationResult {
  const warnings: string[] = [];
  
  // Check for required fields
  if (data.seasons.length === 0) {
    warnings.push('No seasons detected');
  }
  
  // Validate dates are parseable
  for (const season of data.seasons) {
    if (season.start && !isValidDateString(season.start)) {
      warnings.push(`Ambiguous start date: ${season.start}`);
    }
    if (season.end && !isValidDateString(season.end)) {
      warnings.push(`Ambiguous end date: ${season.end}`);
    }
  }
  
  // Check bag limits are reasonable
  for (const limit of data.bag_limits) {
    const val = parseInt(limit.value);
    if (isNaN(val) || val < 0 || val > 50) {
      warnings.push(`Suspicious bag limit value: ${limit.value}`);
    }
  }
  
  // Must have at least some legal methods for hunting categories
  if (data.legal_methods.length === 0) {
    warnings.push('No legal methods detected');
  }
  
  return {
    valid: warnings.filter(w => w.includes('No seasons')).length === 0,
    warnings
  };
}

function isValidDateString(dateStr: string): boolean {
  // Check if it looks like a valid date format
  const patterns = [
    /^[A-Z][a-z]+\.?\s+\d{1,2}$/,  // Oct. 15 or October 15
    /^\d{1,2}\/\d{1,2}$/           // 10/15
  ];
  return patterns.some(p => p.test(dateStr.trim()));
}

// Compute confidence score
function computeConfidence(
  content: string,
  data: ExtractedData,
  validation: ValidationResult,
  isPdf: boolean,
  previousHash: string | null,
  newHash: string
): number {
  let score = 1.0;
  
  // Penalties
  if (isPdf) score -= 0.30;
  
  if (validation.warnings.some(w => w.includes('Ambiguous'))) {
    score -= 0.25;
  }
  
  if (validation.warnings.some(w => w.includes('No seasons'))) {
    score -= 0.30;
  }
  
  // Large content change (page rewrite) - compare hash distance conceptually
  // We'll use a simple heuristic: if we had a previous hash and extracted very different data
  if (previousHash && data.seasons.length === 0 && data.bag_limits.length === 0) {
    score -= 0.15;
  }
  
  // Bonuses
  // Structured HTML table detected
  if (content.toLowerCase().includes('<table') && content.toLowerCase().includes('season')) {
    score += 0.20;
  }
  
  // Good extraction with multiple seasons and limits
  if (data.seasons.length >= 2 && data.bag_limits.length >= 1 && data.legal_methods.length >= 2) {
    score += 0.10;
  }
  
  // Clamp to 0-1 range
  return Math.max(0, Math.min(1, score));
}

// Convert extracted data to summary JSON format
function toSummaryJson(data: ExtractedData): object {
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

    // Get all sources
    const { data: sources, error: sourcesError } = await supabase
      .from("state_regulations_sources")
      .select("*");

    if (sourcesError) {
      throw new Error(`Failed to fetch sources: ${sourcesError.message}`);
    }

    if (!sources || sources.length === 0) {
      return new Response(
        JSON.stringify({ message: "No sources to check", checked: 0, auto_approved: 0, pending: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const seasonYearLabel = getSeasonYearLabel();
    const yearStart = getYearStart();
    const now = iso(new Date())!;
    
    let checked = 0;
    let autoApproved = 0;
    let pendingCount = 0;
    const results: Array<{
      state: string;
      category: string;
      region: string;
      status: string;
      confidence?: number;
      warnings?: string[];
      error?: string;
    }> = [];

    for (const source of sources) {
      const regionKey = source.region_key || 'STATEWIDE';
      const regionLabel = source.region_label || 'Statewide';
      
      try {
        // Fetch with timeout
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 30000);

        const response = await fetch(source.source_url, {
          headers: {
            "User-Agent": "TheSkinning Shed Regulations Checker/3.0",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
          },
          signal: controller.signal
        });

        clearTimeout(timeout);

        if (!response.ok) {
          results.push({
            state: source.state_code,
            category: source.category,
            region: regionKey,
            status: "http_error",
            error: `HTTP ${response.status}`
          });
          continue;
        }

        const contentType = response.headers.get('content-type') || '';
        const isPdf = contentType.includes('pdf');
        
        let rawContent = await response.text();
        const normalizedContent = normalizeContent(rawContent);
        const newHash = await hashContent(normalizedContent);
        
        // Update last checked
        await supabase
          .from("state_regulations_sources")
          .update({ last_checked_at: now })
          .eq("id", source.id);

        checked++;
        
        const previousHash = source.content_hash;
        const hasChanged = previousHash && previousHash !== newHash;
        const isNew = !previousHash;

        if (!hasChanged && !isNew) {
          results.push({
            state: source.state_code,
            category: source.category,
            region: regionKey,
            status: "unchanged"
          });
          
          // Update hash
          await supabase
            .from("state_regulations_sources")
            .update({ content_hash: newHash, updated_at: now })
            .eq("id", source.id);
          continue;
        }

        // Content changed or new - extract and validate
        const extractedData = extractRegulationData(normalizedContent, source.category);
        const validation = validateExtraction(extractedData);
        const confidence = computeConfidence(
          normalizedContent,
          extractedData,
          validation,
          isPdf,
          previousHash,
          newHash
        );
        
        const summaryJson = toSummaryJson(extractedData);
        const diffSummary = isNew 
          ? 'Initial content extraction'
          : `Content changed. Confidence: ${(confidence * 100).toFixed(0)}%. Seasons: ${extractedData.seasons.length}, Limits: ${extractedData.bag_limits.length}`;

        let approvalMode: string;
        let approvedRowId: string | null = null;
        let pendingRowId: string | null = null;

        if (confidence >= AUTO_APPROVE_THRESHOLD && validation.valid) {
          // Auto-approve: upsert directly to approved table
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
            autoApproved++;
            
            // Update source with last approved hash
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
          // Insert into pending for admin review
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

          if (pendingError) {
            console.error(`Pending insert error: ${pendingError.message}`);
          } else {
            pendingRowId = pendingRow?.id || null;
            pendingCount++;
          }
          
          // Update source hash
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

        results.push({
          state: source.state_code,
          category: source.category,
          region: regionKey,
          status: approvalMode === 'auto' ? 'auto_approved' : 'pending',
          confidence: Math.round(confidence * 100) / 100,
          warnings: validation.warnings.length > 0 ? validation.warnings : undefined
        });

      } catch (fetchError) {
        const errorMsg = fetchError instanceof Error ? fetchError.message : String(fetchError);
        console.error(`Error checking ${source.state_code}/${source.category}/${regionKey}: ${errorMsg}`);
        results.push({
          state: source.state_code,
          category: source.category,
          region: regionKey,
          status: "fetch_error",
          error: errorMsg.substring(0, 100)
        });
      }
    }

    return new Response(
      JSON.stringify({
        message: "Check complete",
        checked,
        auto_approved: autoApproved,
        pending: pendingCount,
        total_sources: sources.length,
        season: seasonYearLabel,
        extraction_version: EXTRACTION_VERSION,
        auto_approve_threshold: AUTO_APPROVE_THRESHOLD,
        results
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : undefined;
    console.error("regulations-check-v3 error:", errorMsg);
    if (errorStack) {
      console.error("Stack trace:", errorStack);
    }
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
