/**
 * Extraction job processor.
 * Parses HTML/PDF sources to extract structured season data via GPT.
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

interface SeasonData {
  name: string;
  start_date: string;
  end_date: string;
  weapon_type?: string;
  bag_limit?: string;
  antler_restrictions?: string;
  notes?: string;
}

interface ExtractionResult {
  species: string;
  state_code: string;
  season_year: string;
  seasons: SeasonData[];
  general_bag_limit?: string;
  license_required?: string;
  special_permits?: string[];
  citations: Array<{ text: string; source: string }>;
  confidence_overall: number;
  confidence_fields: Record<string, number>;
}

export async function processExtractionJob(
  job: RegsJob,
  openaiPool: PromisePool
): Promise<{
  success: boolean;
  result?: ExtractionResult;
  skipReason?: string;
  error?: string;
}> {
  const stateCode = job.state_code;
  const species = job.species;
  const tier = job.tier;

  if (!species) {
    return { success: false, error: 'No species specified' };
  }

  await logJobEvent(job.id, 'info', `Starting ${species} extraction for ${stateCode}`);

  // Get portal links
  const portalLinks = await getPortalLinks(stateCode);
  if (!portalLinks) {
    return { success: false, skipReason: 'NO_PORTAL_LINKS' };
  }

  // Determine source URL
  const sourceUrl =
    species === 'deer'
      ? (portalLinks.deer_seasons_url as string) || (portalLinks.hunting_digest_url as string)
      : (portalLinks.turkey_seasons_url as string) || (portalLinks.hunting_digest_url as string);

  if (!sourceUrl) {
    return { success: false, skipReason: 'NO_SOURCE_URL' };
  }

  await logJobEvent(job.id, 'info', `Source URL: ${sourceUrl}`);

  // Get content
  let content: string | null = null;
  let tempPdfPath: string | null = null;

  // Check if PDF
  const contentInfo = await getContentInfo(sourceUrl);

  if (contentInfo.isPdf) {
    if (contentInfo.tooLarge) {
      return { success: false, skipReason: 'PDF_TOO_LARGE' };
    }

    // Download PDF to temp file (streaming, bounded)
    const downloadResult = await downloadPdfToFile(sourceUrl);
    if (downloadResult.skipReason) {
      return { success: false, skipReason: downloadResult.skipReason };
    }
    if (downloadResult.error) {
      return { success: false, error: `PDF download failed: ${downloadResult.error}` };
    }

    tempPdfPath = downloadResult.filePath;

    // Extract text from temp file
    const textResult = await extractPdfText(tempPdfPath!);
    if (textResult.error) {
      cleanupTempFile(tempPdfPath!);
      return { success: false, skipReason: 'PDF_PARSE_FAILED' };
    }

    // Filter to relevant content
    content = filterRelevantContent(textResult.text!, species, config.pdfMaxContextChars);

    await logJobEvent(job.id, 'info', `Extracted ${content.length} chars from PDF`);
  } else {
    // Fetch HTML
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), config.fetchTimeoutMs);

      const response = await fetch(sourceUrl, {
        signal: controller.signal,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; SkinningShedBot/1.0)',
        },
      });

      clearTimeout(timeout);

      if (!response.ok) {
        return { success: false, error: `HTTP ${response.status}` };
      }

      const html = await response.text();
      // Strip HTML tags and limit
      content = html
        .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
        .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
        .replace(/<[^>]+>/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, config.pdfMaxContextChars);

      await logJobEvent(job.id, 'info', `Fetched ${content.length} chars from HTML`);
    } catch (err) {
      return { success: false, error: `Fetch failed: ${err instanceof Error ? err.message : 'Unknown'}` };
    }
  }

  if (!content || content.length < 100) {
    if (tempPdfPath) cleanupTempFile(tempPdfPath);
    return { success: false, skipReason: 'INSUFFICIENT_CONTENT' };
  }

  // Call GPT for extraction
  const extractionResult = await extractWithGpt(
    stateCode,
    species,
    sourceUrl,
    content,
    tier,
    openaiPool
  );

  // Cleanup temp file
  if (tempPdfPath) cleanupTempFile(tempPdfPath);

  if (extractionResult.error) {
    if (extractionResult.rateLimited) {
      return { success: false, skipReason: 'RATE_LIMITED' };
    }
    return { success: false, error: extractionResult.error };
  }

  if (!extractionResult.data) {
    return { success: false, skipReason: 'GPT_NO_DATA' };
  }

  const result = extractionResult.data;

  // Validate: must have seasons and citations
  if (!result.seasons || result.seasons.length === 0) {
    return { success: false, skipReason: 'NO_SEASONS_FOUND' };
  }

  if (result.confidence_overall < 0.6) {
    return { success: false, skipReason: 'LOW_CONFIDENCE' };
  }

  // Save to database
  const currentYear = new Date().getFullYear();
  const seasonYearLabel = `${currentYear}-${currentYear + 1}`;

  await upsertExtractedRegulations({
    state_code: stateCode,
    species_group: species,
    region_key: 'STATEWIDE',
    season_year_label: seasonYearLabel,
    source_url: sourceUrl,
    confidence_score: result.confidence_overall,
    data: result,
    model_used: getModelFor(tier, 'extract'),
    tier_used: tier,
    citations: result.citations,
    status: result.confidence_overall >= 0.8 ? 'published' : 'needs_review',
  });

  await logJobEvent(
    job.id,
    'info',
    `Extracted ${result.seasons.length} seasons, confidence ${result.confidence_overall}`
  );

  return { success: true, result };
}

interface GptExtractionResult {
  data?: ExtractionResult;
  error?: string;
  rateLimited?: boolean;
}

async function extractWithGpt(
  stateCode: string,
  species: 'deer' | 'turkey',
  sourceUrl: string,
  content: string,
  tier: 'basic' | 'pro',
  pool: PromisePool
): Promise<GptExtractionResult> {
  const model = getModelFor(tier, 'extract');

  const systemPrompt = `You are an expert at extracting hunting season regulations from official state wildlife agency documents.

Extract ${species} hunting season information for state ${stateCode}.

For each season you find, extract:
- name: Season name (e.g., "Archery Season", "General Firearms Season")
- start_date: Start date in YYYY-MM-DD format
- end_date: End date in YYYY-MM-DD format  
- weapon_type: Allowed weapons (bow, rifle, shotgun, muzzleloader, etc.)
- bag_limit: Bag limit for this season
- antler_restrictions: Any antler point restrictions
- notes: Any special notes or restrictions

Also extract:
- general_bag_limit: Overall season bag limit
- license_required: Type of license needed
- special_permits: List of any special permits required

CRITICAL RULES:
1. Only extract information that is EXPLICITLY stated in the document
2. Do NOT guess or infer dates - if exact dates aren't shown, skip that season
3. Include a citation (exact quote) from the document for each key fact
4. Set confidence_overall based on how complete and clear the data is (0.0-1.0)
5. Set confidence_fields for each field you extracted

Respond with JSON:
{
  "species": "${species}",
  "state_code": "${stateCode}",
  "season_year": "2025-2026",
  "seasons": [
    {
      "name": "...",
      "start_date": "YYYY-MM-DD",
      "end_date": "YYYY-MM-DD",
      "weapon_type": "...",
      "bag_limit": "...",
      "antler_restrictions": "...",
      "notes": "..."
    }
  ],
  "general_bag_limit": "...",
  "license_required": "...",
  "special_permits": ["..."],
  "citations": [
    { "text": "exact quote from document", "source": "section name or context" }
  ],
  "confidence_overall": 0.0-1.0,
  "confidence_fields": {
    "seasons": 0.0-1.0,
    "dates": 0.0-1.0,
    "bag_limits": 0.0-1.0
  }
}`;

  const result = await callOpenAIWithRetry(
    {
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Source: ${sourceUrl}\n\nDocument content:\n\n${content}` },
      ],
      temperature: 0,
      maxTokens: 4096,
      responseFormat: 'json',
    },
    pool
  );

  if (result.error) {
    return { error: result.error, rateLimited: result.rateLimited };
  }

  const parsed = parseJsonResponse<ExtractionResult>(result.content);

  if (!parsed) {
    return { error: 'Failed to parse GPT response' };
  }

  return { data: parsed };
}
