/**
 * Discovery job processor.
 * Crawls official state wildlife agency sites to find portal links.
 * Uses strict JSON schema with GPT and implements fallback selection.
 */
import { RegsJob, getStateOfficialRoot, updatePortalLinks, logJobEvent } from './supabase';
import { crawlOfficialDomain, CrawlPage, CrawlResult } from './crawler';
import { callOpenAIWithRetry, parseJsonResponse } from './openai';
import { getModelFor, config } from './config';
import { PromisePool } from './limiter';

// Strict output schema for discovery
export interface DiscoveryOutput {
  state_code: string;
  hunting_regs_url: string | null;
  fishing_regs_url: string | null;
  confidence: {
    hunting_regs_url: number;
    fishing_regs_url: number;
  };
  evidence: {
    hunting: Array<{ url: string; snippet: string }>;
    fishing: Array<{ url: string; snippet: string }>;
  };
  notes: string;
  skip_reason: SkipReason | null;
}

export type SkipReason = 
  | 'FETCH_BLOCKED'
  | 'NO_CANDIDATES'
  | 'AMBIGUOUS'
  | 'ONLY_PDF'
  | 'JS_REQUIRED'
  | 'NO_OFFICIAL_ROOT'
  | 'NO_PAGES_FOUND'
  | 'GPT_FAILED'
  | 'RATE_LIMITED';

export interface DiscoveryResult {
  success: boolean;
  output?: DiscoveryOutput;
  skipReason?: SkipReason;
  error?: string;
  stats?: {
    pagesVisited: number;
    pagesFetched: number;
    candidatesFound: number;
    crawlDurationMs: number;
    gptDurationMs: number;
    retryCount: number;
  };
}

export async function processDiscoveryJob(
  job: RegsJob,
  openaiPool: PromisePool
): Promise<DiscoveryResult> {
  const stateCode = job.state_code;
  const tier = job.tier as 'basic' | 'pro';
  const startTime = Date.now();

  // Get official root
  const root = await getStateOfficialRoot(stateCode);
  if (!root) {
    await logJobEvent(job.id, 'warn', `No official root found for ${stateCode}`);
    return { 
      success: false, 
      skipReason: 'NO_OFFICIAL_ROOT',
      output: createSkipOutput(stateCode, 'NO_OFFICIAL_ROOT', 'No official wildlife agency root URL configured'),
    };
  }

  await logJobEvent(job.id, 'info', `Starting discovery for ${stateCode} (${root.state_name}) from ${root.official_root_url}`);

  // Crawl official domain
  const crawlStartTime = Date.now();
  const crawlResult: CrawlResult = await crawlOfficialDomain(root.official_root_url, root.official_domain, {
    maxPages: config.discoveryMaxPagesPerState,
    maxDepth: config.discoveryMaxDepth,
    earlyStopThreshold: config.discoveryEarlyStopThreshold,
  });
  const crawlDurationMs = Date.now() - crawlStartTime;

  // Log crawl stats
  await logJobEvent(job.id, 'info', 
    `Crawl complete: ${crawlResult.stats.pagesFetched} pages fetched, ` +
    `${crawlResult.pages.length} candidates, ${crawlResult.stats.durationMs}ms` +
    (crawlResult.stats.earlyStop ? ` (early stop: ${crawlResult.stats.earlyStopReason})` : '')
  );

  // Handle blocked crawls
  if (crawlResult.blocked) {
    await logJobEvent(job.id, 'warn', `Crawl blocked: ${crawlResult.blockReason}`);
    const output = createSkipOutput(stateCode, 'FETCH_BLOCKED', `Website blocked access: ${crawlResult.blockReason}`);
    await saveDiscoveryResult(stateCode, output);
    return { 
      success: false, 
      skipReason: 'FETCH_BLOCKED',
      output,
      stats: {
        pagesVisited: crawlResult.stats.pagesVisited,
        pagesFetched: crawlResult.stats.pagesFetched,
        candidatesFound: 0,
        crawlDurationMs,
        gptDurationMs: 0,
        retryCount: 0,
      },
    };
  }

  if (crawlResult.pages.length === 0) {
    await logJobEvent(job.id, 'warn', `No candidate pages found for ${stateCode}`);
    const output = createSkipOutput(stateCode, 'NO_PAGES_FOUND', 'Crawl found no relevant pages');
    await saveDiscoveryResult(stateCode, output);
    return { 
      success: false, 
      skipReason: 'NO_PAGES_FOUND',
      output,
      stats: {
        pagesVisited: crawlResult.stats.pagesVisited,
        pagesFetched: crawlResult.stats.pagesFetched,
        candidatesFound: 0,
        crawlDurationMs,
        gptDurationMs: 0,
        retryCount: 0,
      },
    };
  }

  // Limit to top N for GPT
  const topPages = crawlResult.pages.slice(0, config.discoveryCandidateTopN);
  
  await logJobEvent(job.id, 'info', `Sending ${topPages.length} candidates to GPT (top scores: ${topPages.slice(0, 3).map(p => p.score.toFixed(2)).join(', ')})`);

  // Get GPT guidance with retry
  const gptStartTime = Date.now();
  const gptResult = await getGptGuidance(
    stateCode,
    root.state_name,
    root.official_domain,
    topPages,
    tier,
    openaiPool
  );
  const gptDurationMs = Date.now() - gptStartTime;

  const stats = {
    pagesVisited: crawlResult.stats.pagesVisited,
    pagesFetched: crawlResult.stats.pagesFetched,
    candidatesFound: crawlResult.pages.length,
    crawlDurationMs,
    gptDurationMs,
    retryCount: gptResult.retryCount || 0,
  };

  // Handle GPT failure with fallback
  if (gptResult.error || !gptResult.output) {
    await logJobEvent(job.id, 'warn', `GPT failed: ${gptResult.error}, attempting fallback selection`);
    
    // Fallback: use heuristic selection
    const fallbackOutput = performFallbackSelection(stateCode, topPages, root.official_domain);
    
    if (fallbackOutput.hunting_regs_url || fallbackOutput.fishing_regs_url) {
      await logJobEvent(job.id, 'info', 
        `Fallback selection found: hunting=${fallbackOutput.hunting_regs_url ? 'yes' : 'no'}, ` +
        `fishing=${fallbackOutput.fishing_regs_url ? 'yes' : 'no'}`
      );
      
      // Save with low confidence (pending review)
      await saveDiscoveryResult(stateCode, fallbackOutput);
      
      return {
        success: true,
        output: fallbackOutput,
        stats,
      };
    }

    // Fallback also failed
    if (gptResult.rateLimited) {
      const output = createSkipOutput(stateCode, 'RATE_LIMITED', 'OpenAI rate limit exceeded');
      return { success: false, skipReason: 'RATE_LIMITED', output, stats };
    }

    const output = createSkipOutput(stateCode, 'GPT_FAILED', gptResult.error || 'GPT returned no results');
    return { success: false, skipReason: 'GPT_FAILED', output, stats };
  }

  const output = gptResult.output;

  // Validate URLs are on official domain
  if (output.hunting_regs_url && !isOnOfficialDomain(output.hunting_regs_url, root.official_domain)) {
    await logJobEvent(job.id, 'warn', `Rejected hunting URL (not on official domain): ${output.hunting_regs_url}`);
    output.hunting_regs_url = null;
    output.confidence.hunting_regs_url = 0;
  }
  if (output.fishing_regs_url && !isOnOfficialDomain(output.fishing_regs_url, root.official_domain)) {
    await logJobEvent(job.id, 'warn', `Rejected fishing URL (not on official domain): ${output.fishing_regs_url}`);
    output.fishing_regs_url = null;
    output.confidence.fishing_regs_url = 0;
  }

  // Check if we found anything useful
  const hasHunting = output.hunting_regs_url && output.confidence.hunting_regs_url >= config.discoveryMinConfidence;
  const hasFishing = output.fishing_regs_url && output.confidence.fishing_regs_url >= config.discoveryMinConfidence;

  await logJobEvent(job.id, 'info', 
    `GPT selection: hunting=${output.hunting_regs_url ? `${output.confidence.hunting_regs_url.toFixed(2)}` : 'none'}, ` +
    `fishing=${output.fishing_regs_url ? `${output.confidence.fishing_regs_url.toFixed(2)}` : 'none'}`
  );

  // Save result to database
  await saveDiscoveryResult(stateCode, output);

  // Log summary
  const totalDuration = Date.now() - startTime;
  await logJobEvent(job.id, 'info', 
    `Discovery complete for ${stateCode}: ` +
    `hunting=${hasHunting ? 'found' : 'not found'}, fishing=${hasFishing ? 'found' : 'not found'}, ` +
    `total ${totalDuration}ms`
  );

  // Consider it a success if we found at least one URL
  if (hasHunting || hasFishing) {
    return { success: true, output, stats };
  }

  // No high-confidence results, but we still save what we found (low confidence)
  if (output.hunting_regs_url || output.fishing_regs_url) {
    return { success: true, output, stats };
  }

  // Nothing found
  output.skip_reason = 'NO_CANDIDATES';
  return { success: false, skipReason: 'NO_CANDIDATES', output, stats };
}

/**
 * Create a skip output with the given reason.
 */
function createSkipOutput(stateCode: string, skipReason: SkipReason, notes: string): DiscoveryOutput {
  return {
    state_code: stateCode,
    hunting_regs_url: null,
    fishing_regs_url: null,
    confidence: { hunting_regs_url: 0, fishing_regs_url: 0 },
    evidence: { hunting: [], fishing: [] },
    notes,
    skip_reason: skipReason,
  };
}

/**
 * Check if a URL is on the official domain.
 */
function isOnOfficialDomain(url: string, officialDomain: string): boolean {
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.toLowerCase();
    const domain = officialDomain.toLowerCase().replace(/^www\./, '');
    return host === domain || host === 'www.' + domain || host.endsWith('.' + domain);
  } catch {
    return false;
  }
}

/**
 * Perform fallback selection using heuristics when GPT fails.
 */
function performFallbackSelection(
  stateCode: string,
  pages: CrawlPage[],
  officialDomain: string
): DiscoveryOutput {
  const output: DiscoveryOutput = {
    state_code: stateCode,
    hunting_regs_url: null,
    fishing_regs_url: null,
    confidence: { hunting_regs_url: 0, fishing_regs_url: 0 },
    evidence: { hunting: [], fishing: [] },
    notes: 'Selected via fallback heuristics (GPT failed)',
    skip_reason: null,
  };

  // Find best hunting candidate
  const huntingKeywords = ['hunting regulations', 'hunting seasons', 'deer season', 'deer hunting', 'hunting guide', 'hunting digest'];
  for (const page of pages) {
    if (!isOnOfficialDomain(page.url, officialDomain)) continue;
    
    const combined = (page.title + ' ' + page.snippet + ' ' + page.url).toLowerCase();
    const matchCount = huntingKeywords.filter(kw => combined.includes(kw)).length;
    
    if (matchCount >= 2) {
      output.hunting_regs_url = page.url;
      output.confidence.hunting_regs_url = Math.min(0.5, matchCount * 0.15); // Low confidence for fallback
      output.evidence.hunting.push({ url: page.url, snippet: page.snippet.slice(0, 200) });
      break;
    }
  }

  // Find best fishing candidate
  const fishingKeywords = ['fishing regulations', 'fishing guide', 'fishing seasons', 'creel limit', 'fishing rules'];
  for (const page of pages) {
    if (!isOnOfficialDomain(page.url, officialDomain)) continue;
    
    const combined = (page.title + ' ' + page.snippet + ' ' + page.url).toLowerCase();
    const matchCount = fishingKeywords.filter(kw => combined.includes(kw)).length;
    
    if (matchCount >= 2) {
      output.fishing_regs_url = page.url;
      output.confidence.fishing_regs_url = Math.min(0.5, matchCount * 0.15);
      output.evidence.fishing.push({ url: page.url, snippet: page.snippet.slice(0, 200) });
      break;
    }
  }

  return output;
}

/**
 * Save discovery result to state_portal_links.
 */
async function saveDiscoveryResult(stateCode: string, output: DiscoveryOutput): Promise<void> {
  const updates: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
    discovery_result_json: output, // Store full output for debugging
  };

  // Only update URLs if they have sufficient confidence
  if (output.hunting_regs_url && output.confidence.hunting_regs_url >= config.discoveryMinConfidence) {
    updates.hunting_regs_url = output.hunting_regs_url;
    updates.hunting_regs_url_status = 'discovered';
    updates.hunting_regs_confidence = output.confidence.hunting_regs_url;
  } else if (output.hunting_regs_url) {
    // Low confidence - save but mark as pending review
    updates.hunting_regs_url = output.hunting_regs_url;
    updates.hunting_regs_url_status = 'pending_review';
    updates.hunting_regs_confidence = output.confidence.hunting_regs_url;
  }

  if (output.fishing_regs_url && output.confidence.fishing_regs_url >= config.discoveryMinConfidence) {
    updates.fishing_regs_url = output.fishing_regs_url;
    updates.fishing_regs_url_status = 'discovered';
    updates.fishing_regs_confidence = output.confidence.fishing_regs_url;
  } else if (output.fishing_regs_url) {
    updates.fishing_regs_url = output.fishing_regs_url;
    updates.fishing_regs_url_status = 'pending_review';
    updates.fishing_regs_confidence = output.confidence.fishing_regs_url;
  }

  // Store skip reason if applicable
  if (output.skip_reason) {
    updates.discovery_skip_reason = output.skip_reason;
  }

  await updatePortalLinks(stateCode, updates);
}

// GPT guidance types
interface GptGuidanceResult {
  output?: DiscoveryOutput;
  error?: string;
  rateLimited?: boolean;
  retryCount?: number;
}

/**
 * Get GPT guidance on which pages are most relevant.
 * Uses strict JSON schema and explicit instructions.
 */
async function getGptGuidance(
  stateCode: string,
  stateName: string,
  officialDomain: string,
  pages: CrawlPage[],
  tier: 'basic' | 'pro',
  pool: PromisePool
): Promise<GptGuidanceResult> {
  const model = getModelFor(tier, 'discovery');

  // Format pages for prompt
  const pagesText = pages
    .map((p, i) => 
      `[${i}] Title: ${p.title}\n` +
      `    URL: ${p.url}\n` +
      `    Score: ${p.score.toFixed(2)} | Keywords: ${p.keywords.slice(0, 5).join(', ')}\n` +
      `    Snippet: ${p.snippet.slice(0, 300)}...`
    )
    .join('\n\n');

  const systemPrompt = `You are an expert at identifying official government wildlife agency regulation pages.

TASK: Analyze pages from ${stateName}'s official wildlife/game agency website (${officialDomain}) and identify:
1. The official statewide HUNTING regulations page (deer, turkey, game seasons, bag limits)
2. The official statewide FISHING regulations page (fishing seasons, creel limits, size limits)

STRICT RULES:
- URLs MUST be on the official domain: ${officialDomain} (or subdomains like www.${officialDomain})
- Do NOT select pages that are:
  * Press releases or news articles
  * License purchase/application pages (unless they also contain regulation info)
  * Blog posts or event announcements
  * PDFs UNLESS it's the main regulations guide/digest
- PREFER pages with:
  * "regulations", "seasons", "bag limits", "guide", "handbook" in title/URL
  * Actual season dates, limits, and rules (not just links to them)
  * Statewide coverage (not county/region-specific)
- EVIDENCE is REQUIRED: You must cite a specific snippet that shows why you chose each URL
- If you cannot find a suitable page with confidence >= 0.70, return null for that category
- Do NOT hallucinate or guess URLs - only use URLs from the provided list

OUTPUT: Return ONLY valid JSON matching this exact schema:

{
  "state_code": "${stateCode}",
  "hunting_regs_url": "<URL from list or null>",
  "fishing_regs_url": "<URL from list or null>",
  "confidence": {
    "hunting_regs_url": <0.0-1.0>,
    "fishing_regs_url": <0.0-1.0>
  },
  "evidence": {
    "hunting": [{"url": "<URL>", "snippet": "<exact text that proves this is the regs page>"}],
    "fishing": [{"url": "<URL>", "snippet": "<exact text that proves this is the regs page>"}]
  },
  "notes": "<brief explanation of your selections or why you couldn't find them>",
  "skip_reason": null | "NO_CANDIDATES" | "AMBIGUOUS" | "ONLY_PDF" | "JS_REQUIRED"
}`;

  const userPrompt = `Here are ${pages.length} candidate pages from ${stateName} (${stateCode}) official wildlife website.
Find the best HUNTING regulations page and FISHING regulations page.

CANDIDATES:
${pagesText}

Remember:
- Only use URLs from this list
- Evidence snippets are REQUIRED for any URL you select
- Return null with skip_reason if you can't find a suitable page
- Confidence must be >= 0.70 to be useful`;

  const result = await callOpenAIWithRetry(
    {
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0,
      maxTokens: 2048,
      responseFormat: 'json',
    },
    pool
  );

  if (result.error) {
    return { error: result.error, rateLimited: result.rateLimited, retryCount: result.retryCount };
  }

  const parsed = parseJsonResponse<DiscoveryOutput>(result.content);

  if (!parsed) {
    return { error: 'Failed to parse GPT response as JSON', retryCount: result.retryCount };
  }

  // Validate the output structure
  if (typeof parsed.state_code !== 'string') {
    parsed.state_code = stateCode;
  }
  if (!parsed.confidence) {
    parsed.confidence = { hunting_regs_url: 0, fishing_regs_url: 0 };
  }
  if (!parsed.evidence) {
    parsed.evidence = { hunting: [], fishing: [] };
  }

  return { output: parsed, retryCount: result.retryCount };
}
