/**
 * Extraction job processor.
 * Parses HTML/PDF sources to extract structured season data via GPT.
 * Uses strict JSON schema with mandatory citations.
 */
import {
  RegsJob,
  getPortalLinks,
  upsertExtractedRegulations,
  logJobEvent,
} from './supabase';
import {
  getContentInfo,
  downloadPdfToFile,
  extractPdfText,
  filterRelevantContent,
  cleanupTempFile,
} from './pdf';
import { callOpenAIWithRetry, parseJsonResponse } from './openai';
import { getModelFor, config } from './config';
import { PromisePool } from './limiter';
import { sleepWithJitter } from './limiter';

// Strict output schema for extraction
export interface ExtractionOutput {
  state_code: string;
  species: 'deer' | 'turkey';
  season_entries: SeasonEntry[];
  bag_limits: {
    daily: string | null;
    possession: string | null;
    season_total: string | null;
    notes: string | null;
  };
  unit_scope: 'statewide' | 'zone_based' | 'county_based' | 'unknown';
  citations: Citation[];
  confidence_overall: number;
  skip_reason: ExtractionSkipReason | null;
  notes: string;
}

export interface SeasonEntry {
  season_name: string;
  weapon: string | null;
  start_date: string; // YYYY-MM-DD
  end_date: string; // YYYY-MM-DD
  bag_limit: string | null;
  antler_restrictions: string | null;
  area_notes: string | null;
  notes: string | null;
}

export interface Citation {
  url: string;
  type: 'html' | 'pdf';
  snippet: string;
  page_number: number | null;
}

export type ExtractionSkipReason =
  | 'NO_SOURCE'
  | 'PDF_TOO_LARGE'
  | 'PDF_PARSE_FAILED'
  | 'FETCH_BLOCKED'
  | 'AMBIGUOUS'
  | 'OUT_OF_SEASON'
  | 'VALIDATION_FAILED'
  | 'NO_SEASONS_FOUND'
  | 'LOW_CONFIDENCE'
  | 'INSUFFICIENT_CONTENT'
  | 'GPT_FAILED'
  | 'RATE_LIMITED';

export interface ExtractionResult {
  success: boolean;
  output?: ExtractionOutput;
  skipReason?: ExtractionSkipReason;
  error?: string;
  stats?: {
    sourceType: 'html' | 'pdf';
    contentLength: number;
    fetchDurationMs: number;
    gptDurationMs: number;
    retryCount: number;
  };
}

export async function processExtractionJob(
  job: RegsJob,
  openaiPool: PromisePool
): Promise<ExtractionResult> {
  const stateCode = job.state_code;
  const species = job.species as 'deer' | 'turkey';
  const tier = job.tier as 'basic' | 'pro';
  const startTime = Date.now();

  if (!species) {
    return { success: false, error: 'No species specified' };
  }

  await logJobEvent(job.id, 'info', `Starting ${species} extraction for ${stateCode}`);

  // Get portal links
  const portalLinks = await getPortalLinks(stateCode);
  if (!portalLinks) {
    const output = createSkipOutput(stateCode, species, 'NO_SOURCE', 'No portal links configured');
    return { success: false, skipReason: 'NO_SOURCE', output };
  }

  // Determine source URL based on species
  let sourceUrl: string | null = null;
  if (species === 'deer') {
    sourceUrl = (portalLinks.deer_seasons_url as string) || 
                (portalLinks.hunting_regs_url as string) || 
                (portalLinks.hunting_digest_url as string);
  } else {
    sourceUrl = (portalLinks.turkey_seasons_url as string) || 
                (portalLinks.hunting_regs_url as string) || 
                (portalLinks.hunting_digest_url as string);
  }

  if (!sourceUrl) {
    const output = createSkipOutput(stateCode, species, 'NO_SOURCE', 'No source URL available for this species');
    return { success: false, skipReason: 'NO_SOURCE', output };
  }

  await logJobEvent(job.id, 'info', `Source URL: ${sourceUrl}`);

  // Fetch content with retry
  const fetchStartTime = Date.now();
  const contentResult = await fetchContentWithRetry(sourceUrl, job.id, species);
  const fetchDurationMs = Date.now() - fetchStartTime;

  if (contentResult.skipReason) {
    const output = createSkipOutput(stateCode, species, contentResult.skipReason, contentResult.error || 'Fetch failed');
    return { 
      success: false, 
      skipReason: contentResult.skipReason, 
      output,
      stats: {
        sourceType: contentResult.sourceType || 'html',
        contentLength: 0,
        fetchDurationMs,
        gptDurationMs: 0,
        retryCount: 0,
      },
    };
  }

  if (!contentResult.content || contentResult.content.length < 100) {
    const output = createSkipOutput(stateCode, species, 'INSUFFICIENT_CONTENT', 'Retrieved content too short');
    return { success: false, skipReason: 'INSUFFICIENT_CONTENT', output };
  }

  await logJobEvent(job.id, 'info', 
    `Fetched ${contentResult.content.length} chars from ${contentResult.sourceType} (${fetchDurationMs}ms)`
  );

  // Call GPT for extraction
  const gptStartTime = Date.now();
  const gptResult = await extractWithGpt(
    stateCode,
    species,
    sourceUrl,
    contentResult.content,
    contentResult.sourceType,
    tier,
    openaiPool
  );
  const gptDurationMs = Date.now() - gptStartTime;

  const stats = {
    sourceType: contentResult.sourceType,
    contentLength: contentResult.content.length,
    fetchDurationMs,
    gptDurationMs,
    retryCount: gptResult.retryCount || 0,
  };

  if (gptResult.error || !gptResult.output) {
    await logJobEvent(job.id, 'warn', `GPT extraction failed: ${gptResult.error}`);
    
    if (gptResult.rateLimited) {
      const output = createSkipOutput(stateCode, species, 'RATE_LIMITED', 'OpenAI rate limit exceeded');
      return { success: false, skipReason: 'RATE_LIMITED', output, stats };
    }

    const output = createSkipOutput(stateCode, species, 'GPT_FAILED', gptResult.error || 'GPT returned no results');
    return { success: false, skipReason: 'GPT_FAILED', output, stats };
  }

  const output = gptResult.output;

  // Validate output
  const validationResult = validateExtractionOutput(output);
  if (!validationResult.valid) {
    await logJobEvent(job.id, 'warn', `Validation failed: ${validationResult.reason}`);
    output.skip_reason = 'VALIDATION_FAILED';
    output.notes = validationResult.reason || 'Validation failed';
    return { success: false, skipReason: 'VALIDATION_FAILED', output, stats };
  }

  // Check for meaningful content
  if (output.season_entries.length === 0) {
    await logJobEvent(job.id, 'warn', `No season entries found in extraction`);
    output.skip_reason = 'NO_SEASONS_FOUND';
    return { success: false, skipReason: 'NO_SEASONS_FOUND', output, stats };
  }

  if (output.confidence_overall < 0.6) {
    await logJobEvent(job.id, 'warn', `Low confidence extraction: ${output.confidence_overall}`);
    output.skip_reason = 'LOW_CONFIDENCE';
    return { success: false, skipReason: 'LOW_CONFIDENCE', output, stats };
  }

  // Check citations
  if (output.citations.length === 0) {
    await logJobEvent(job.id, 'warn', `No citations provided`);
    output.confidence_overall = Math.min(output.confidence_overall, 0.5);
  }

  // Save to database
  const currentYear = new Date().getFullYear();
  const seasonYearLabel = `${currentYear}-${currentYear + 1}`;

  await upsertExtractedRegulations({
    state_code: stateCode,
    species_group: species,
    region_key: output.unit_scope === 'statewide' ? 'STATEWIDE' : 'MIXED',
    season_year_label: seasonYearLabel,
    source_url: sourceUrl,
    confidence_score: output.confidence_overall,
    data: output,
    model_used: getModelFor(tier, 'extract'),
    tier_used: tier,
    citations: output.citations,
    status: output.confidence_overall >= 0.8 ? 'published' : 'needs_review',
  });

  const totalDuration = Date.now() - startTime;
  await logJobEvent(job.id, 'info', 
    `Extraction complete for ${stateCode} ${species}: ` +
    `${output.season_entries.length} seasons, confidence ${output.confidence_overall.toFixed(2)}, ` +
    `${output.citations.length} citations, ${totalDuration}ms`
  );

  return { success: true, output, stats };
}

/**
 * Create a skip output with the given reason.
 */
function createSkipOutput(
  stateCode: string, 
  species: 'deer' | 'turkey', 
  skipReason: ExtractionSkipReason, 
  notes: string
): ExtractionOutput {
  return {
    state_code: stateCode,
    species,
    season_entries: [],
    bag_limits: { daily: null, possession: null, season_total: null, notes: null },
    unit_scope: 'unknown',
    citations: [],
    confidence_overall: 0,
    skip_reason: skipReason,
    notes,
  };
}

/**
 * Fetch content from URL with retry on transient failures.
 */
async function fetchContentWithRetry(
  sourceUrl: string,
  jobId: string,
  species: 'deer' | 'turkey'
): Promise<{
  content: string | null;
  sourceType: 'html' | 'pdf';
  skipReason?: ExtractionSkipReason;
  error?: string;
}> {
  const maxRetries = config.fetchMaxRetries;
  let tempPdfPath: string | null = null;

  try {
    // Check content type
    const contentInfo = await getContentInfo(sourceUrl);

    if (contentInfo.isPdf) {
      if (contentInfo.tooLarge) {
        return { content: null, sourceType: 'pdf', skipReason: 'PDF_TOO_LARGE', error: 'PDF exceeds size limit' };
      }

      // Download PDF with retry
      let downloadResult: Awaited<ReturnType<typeof downloadPdfToFile>> | null = null;
      for (let attempt = 0; attempt <= maxRetries; attempt++) {
        downloadResult = await downloadPdfToFile(sourceUrl);
        if (downloadResult.filePath || downloadResult.skipReason) break;
        if (attempt < maxRetries) {
          await sleepWithJitter(config.fetchRetryDelayMs * (attempt + 1));
        }
      }

      if (!downloadResult || downloadResult.skipReason) {
        return { 
          content: null, 
          sourceType: 'pdf', 
          skipReason: downloadResult?.skipReason as ExtractionSkipReason || 'PDF_TOO_LARGE',
          error: downloadResult?.error,
        };
      }
      if (downloadResult.error || !downloadResult.filePath) {
        return { content: null, sourceType: 'pdf', skipReason: 'FETCH_BLOCKED', error: downloadResult.error };
      }

      tempPdfPath = downloadResult.filePath;

      // Extract text
      const textResult = await extractPdfText(tempPdfPath);
      if (textResult.error || !textResult.text) {
        cleanupTempFile(tempPdfPath);
        return { content: null, sourceType: 'pdf', skipReason: 'PDF_PARSE_FAILED', error: textResult.error };
      }

      // Filter to relevant content
      const content = filterRelevantContent(textResult.text, species, config.pdfMaxContextChars);
      cleanupTempFile(tempPdfPath);

      return { content, sourceType: 'pdf' };
    } else {
      // Fetch HTML with retry
      let html: string | null = null;
      let lastError: string | null = null;

      for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          const controller = new AbortController();
          const timeout = setTimeout(() => controller.abort(), config.fetchTimeoutMs);

          const response = await fetch(sourceUrl, {
            signal: controller.signal,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          });

          clearTimeout(timeout);

          if (response.status === 403 || response.status === 429) {
            return { content: null, sourceType: 'html', skipReason: 'FETCH_BLOCKED', error: `HTTP ${response.status}` };
          }

          if (!response.ok) {
            lastError = `HTTP ${response.status}`;
            if (response.status >= 500 && attempt < maxRetries) {
              await sleepWithJitter(config.fetchRetryDelayMs * (attempt + 1));
              continue;
            }
            return { content: null, sourceType: 'html', error: lastError };
          }

          html = await response.text();
          break;
        } catch (err) {
          lastError = err instanceof Error ? err.message : 'Unknown error';
          if (attempt < maxRetries) {
            await sleepWithJitter(config.fetchRetryDelayMs * (attempt + 1));
            continue;
          }
        }
      }

      if (!html) {
        return { content: null, sourceType: 'html', error: lastError || 'Fetch failed' };
      }

      // Strip HTML and limit
      const content = html
        .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
        .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
        .replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, '')
        .replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, '')
        .replace(/<[^>]+>/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, config.pdfMaxContextChars);

      return { content, sourceType: 'html' };
    }
  } finally {
    if (tempPdfPath) {
      cleanupTempFile(tempPdfPath);
    }
  }
}

/**
 * Validate extraction output.
 */
function validateExtractionOutput(output: ExtractionOutput): { valid: boolean; reason?: string } {
  // Check dates are valid
  for (const entry of output.season_entries) {
    if (!isValidDate(entry.start_date)) {
      return { valid: false, reason: `Invalid start date: ${entry.start_date}` };
    }
    if (!isValidDate(entry.end_date)) {
      return { valid: false, reason: `Invalid end date: ${entry.end_date}` };
    }
    
    // Check dates are plausible (within reasonable range)
    const startYear = parseInt(entry.start_date.split('-')[0], 10);
    const currentYear = new Date().getFullYear();
    if (startYear < currentYear - 1 || startYear > currentYear + 2) {
      return { valid: false, reason: `Date year out of range: ${entry.start_date}` };
    }

    // Check end is after start
    if (entry.end_date < entry.start_date) {
      return { valid: false, reason: `End date before start date: ${entry.start_date} to ${entry.end_date}` };
    }
  }

  return { valid: true };
}

function isValidDate(dateStr: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return false;
  const date = new Date(dateStr);
  return !isNaN(date.getTime());
}

// GPT extraction types
interface GptExtractionResult {
  output?: ExtractionOutput;
  error?: string;
  rateLimited?: boolean;
  retryCount?: number;
}

/**
 * Extract season data using GPT with strict JSON schema.
 */
async function extractWithGpt(
  stateCode: string,
  species: 'deer' | 'turkey',
  sourceUrl: string,
  content: string,
  sourceType: 'html' | 'pdf',
  tier: 'basic' | 'pro',
  pool: PromisePool
): Promise<GptExtractionResult> {
  const model = getModelFor(tier, 'extract');
  const currentYear = new Date().getFullYear();

  const systemPrompt = `You are an expert at extracting hunting season regulations from official state wildlife agency documents.

TASK: Extract ${species.toUpperCase()} hunting season information for state ${stateCode}.

For each season, extract:
- season_name: Name (e.g., "Archery Season", "General Firearms Season", "Early Muzzleloader")
- weapon: Allowed weapons (bow, rifle, shotgun, muzzleloader, crossbow, etc.) or null
- start_date: YYYY-MM-DD format (REQUIRED)
- end_date: YYYY-MM-DD format (REQUIRED)
- bag_limit: Specific bag limit for this season or null
- antler_restrictions: Any antler point restrictions (e.g., "3 points on one side minimum")
- area_notes: Zone/area restrictions if not statewide
- notes: Any special notes

CRITICAL RULES:
1. ONLY extract information that is EXPLICITLY stated in the document
2. Do NOT guess or infer dates - if exact dates aren't shown, do NOT include that season
3. CITATIONS ARE REQUIRED for any date you extract - include the exact text that shows the dates
4. Dates must be in YYYY-MM-DD format (assume year ${currentYear} or ${currentYear + 1} based on season timing)
5. If the document shows date ranges spanning multiple lines or formats, parse carefully
6. Do NOT hallucinate - if unsure, exclude the season rather than guess

OUTPUT: Return ONLY valid JSON matching this exact schema:

{
  "state_code": "${stateCode}",
  "species": "${species}",
  "season_entries": [
    {
      "season_name": "...",
      "weapon": "bow" | "rifle" | "shotgun" | "muzzleloader" | "crossbow" | "any legal" | null,
      "start_date": "YYYY-MM-DD",
      "end_date": "YYYY-MM-DD",
      "bag_limit": "..." | null,
      "antler_restrictions": "..." | null,
      "area_notes": "..." | null,
      "notes": "..." | null
    }
  ],
  "bag_limits": {
    "daily": "..." | null,
    "possession": "..." | null,
    "season_total": "..." | null,
    "notes": "..." | null
  },
  "unit_scope": "statewide" | "zone_based" | "county_based" | "unknown",
  "citations": [
    {
      "url": "${sourceUrl}",
      "type": "${sourceType}",
      "snippet": "<EXACT text from document that shows the dates/limits>",
      "page_number": <number or null>
    }
  ],
  "confidence_overall": <0.0-1.0>,
  "skip_reason": null | "NO_SEASONS_FOUND" | "AMBIGUOUS" | "OUT_OF_SEASON",
  "notes": "<explanation of what you found or why you couldn't extract>"
}`;

  const userPrompt = `Extract ${species} hunting season data from this ${sourceType.toUpperCase()} document for ${stateCode}.

SOURCE: ${sourceUrl}

DOCUMENT CONTENT:
${content}

Remember:
- ONLY include seasons with explicit dates
- Include exact citation snippets for each date you extract
- Set confidence based on how clear/complete the information is
- If no usable data, return empty season_entries with skip_reason`;

  const result = await callOpenAIWithRetry(
    {
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0,
      maxTokens: 4096,
      responseFormat: 'json',
    },
    pool
  );

  if (result.error) {
    return { error: result.error, rateLimited: result.rateLimited, retryCount: result.retryCount };
  }

  const parsed = parseJsonResponse<ExtractionOutput>(result.content);

  if (!parsed) {
    return { error: 'Failed to parse GPT response as JSON', retryCount: result.retryCount };
  }

  // Ensure required fields exist
  if (!parsed.state_code) parsed.state_code = stateCode;
  if (!parsed.species) parsed.species = species;
  if (!parsed.season_entries) parsed.season_entries = [];
  if (!parsed.bag_limits) parsed.bag_limits = { daily: null, possession: null, season_total: null, notes: null };
  if (!parsed.citations) parsed.citations = [];
  if (typeof parsed.confidence_overall !== 'number') parsed.confidence_overall = 0.5;

  return { output: parsed, retryCount: result.retryCount };
}
