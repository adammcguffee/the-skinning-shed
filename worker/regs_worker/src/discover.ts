/**
 * Discovery job processor.
 * Crawls official state wildlife agency sites to find portal links.
 * Supports HTML pages and PDF handbooks, with misc_related fallback.
 */
import { RegsJob, getStateOfficialRoot, updatePortalLinks, logJobEvent } from './supabase';
import { crawlOfficialDomain, CrawlPage, CrawlResult } from './crawler';
import { callOpenAIWithRetry, parseJsonResponse } from './openai';
import { getModelFor, config } from './config';
import { PromisePool } from './limiter';

// ============================================================
// Output Schema (strict JSON contract)
// ============================================================

export interface DiscoveryOutput {
  state_code: string;
  hunting: {
    url: string | null;         // HTML page
    pdf_url: string | null;     // PDF handbook/guide
    confidence: number;
    evidence: Array<{ url: string; snippet: string }>;
  };
  fishing: {
    url: string | null;
    pdf_url: string | null;
    confidence: number;
    evidence: Array<{ url: string; snippet: string }>;
  };
  misc_related: Array<{
    url: string;
    label: string;  // "Regulations landing page", "Season dates", "PDF handbook", "Bag limits", "License+regs"
    confidence: number;
    evidence_snippet: string;
  }>;
  notes: string;
}

export type SkipReason = 
  | 'FETCH_BLOCKED'
  | 'NO_CANDIDATES'
  | 'NO_OFFICIAL_ROOT'
  | 'NO_PAGES_FOUND'
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
    pdfCandidates: number;
    crawlDurationMs: number;
    gptDurationMs: number;
    retryCount: number;
  };
}

// ============================================================
// Main Discovery Processor
// ============================================================

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
      output: createEmptyOutput(stateCode, 'No official wildlife agency root URL configured'),
    };
  }

  await logJobEvent(job.id, 'info', `Starting discovery for ${stateCode} (${root.state_name}) from ${root.official_root_url}`);

  // Crawl official domain (includes PDF detection)
  const crawlStartTime = Date.now();
  const crawlResult: CrawlResult = await crawlOfficialDomain(root.official_root_url, root.official_domain, {
    maxPages: config.discoveryMaxPagesPerState,
    maxDepth: config.discoveryMaxDepth,
    earlyStopThreshold: config.discoveryEarlyStopThreshold,
  });
  const crawlDurationMs = Date.now() - crawlStartTime;

  // Count PDF candidates
  const pdfCandidates = crawlResult.pages.filter(p => isPdfUrl(p.url)).length;

  await logJobEvent(job.id, 'info', 
    `Crawl complete: ${crawlResult.stats.pagesFetched} pages, ` +
    `${crawlResult.pages.length} candidates (${pdfCandidates} PDFs), ${crawlResult.stats.durationMs}ms` +
    (crawlResult.stats.earlyStop ? ` (early stop)` : '')
  );

  // Handle blocked crawls
  if (crawlResult.blocked) {
    await logJobEvent(job.id, 'warn', `Crawl blocked: ${crawlResult.blockReason}`);
    const output = createEmptyOutput(stateCode, `Website blocked access: ${crawlResult.blockReason}`);
    await saveDiscoveryResult(stateCode, output);
    return { 
      success: false, 
      skipReason: 'FETCH_BLOCKED',
      output,
      stats: {
        pagesVisited: crawlResult.stats.pagesVisited,
        pagesFetched: crawlResult.stats.pagesFetched,
        candidatesFound: 0,
        pdfCandidates: 0,
        crawlDurationMs,
        gptDurationMs: 0,
        retryCount: 0,
      },
    };
  }

  if (crawlResult.pages.length === 0) {
    await logJobEvent(job.id, 'warn', `No candidate pages found for ${stateCode}`);
    const output = createEmptyOutput(stateCode, 'Crawl found no relevant pages');
    await saveDiscoveryResult(stateCode, output);
    return { 
      success: false, 
      skipReason: 'NO_PAGES_FOUND',
      output,
      stats: {
        pagesVisited: crawlResult.stats.pagesVisited,
        pagesFetched: crawlResult.stats.pagesFetched,
        candidatesFound: 0,
        pdfCandidates: 0,
        crawlDurationMs,
        gptDurationMs: 0,
        retryCount: 0,
      },
    };
  }

  // Limit to top N for GPT, but ensure some PDFs are included
  const topPages = selectTopCandidates(crawlResult.pages, config.discoveryCandidateTopN);
  
  await logJobEvent(job.id, 'info', `Sending ${topPages.length} candidates to GPT`);

  // Get GPT guidance
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
    pdfCandidates,
    crawlDurationMs,
    gptDurationMs,
    retryCount: gptResult.retryCount || 0,
  };

  // Handle GPT failure with fallback
  if (gptResult.error || !gptResult.output) {
    await logJobEvent(job.id, 'warn', `GPT failed: ${gptResult.error}, using fallback selection`);
    
    // Fallback: create output from best candidates
    const fallbackOutput = performFallbackSelection(stateCode, topPages, root.official_domain);
    
    // Always save something if we have candidates
    if (fallbackOutput.hunting.url || fallbackOutput.hunting.pdf_url || 
        fallbackOutput.fishing.url || fallbackOutput.fishing.pdf_url ||
        fallbackOutput.misc_related.length > 0) {
      await logJobEvent(job.id, 'info', 
        `Fallback selection: hunting=${fallbackOutput.hunting.url || fallbackOutput.hunting.pdf_url || 'none'}, ` +
        `fishing=${fallbackOutput.fishing.url || fallbackOutput.fishing.pdf_url || 'none'}, ` +
        `misc=${fallbackOutput.misc_related.length}`
      );
      
      await saveDiscoveryResult(stateCode, fallbackOutput);
      return { success: true, output: fallbackOutput, stats };
    }

    if (gptResult.rateLimited) {
      return { success: false, skipReason: 'RATE_LIMITED', output: fallbackOutput, stats };
    }

    return { success: false, skipReason: 'NO_CANDIDATES', output: fallbackOutput, stats };
  }

  const output = gptResult.output;

  // Validate URLs are on official domain
  validateAndCleanOutput(output, root.official_domain);

  // Log results
  const huntingSource = output.hunting.url || output.hunting.pdf_url;
  const fishingSource = output.fishing.url || output.fishing.pdf_url;
  await logJobEvent(job.id, 'info', 
    `GPT selection: hunting=${huntingSource ? `${output.hunting.confidence.toFixed(2)}` : 'none'} ` +
    `(pdf=${output.hunting.pdf_url ? 'yes' : 'no'}), ` +
    `fishing=${fishingSource ? `${output.fishing.confidence.toFixed(2)}` : 'none'} ` +
    `(pdf=${output.fishing.pdf_url ? 'yes' : 'no'}), ` +
    `misc=${output.misc_related.length}`
  );

  // Save to database
  await saveDiscoveryResult(stateCode, output);

  const totalDuration = Date.now() - startTime;
  await logJobEvent(job.id, 'info', `Discovery complete for ${stateCode} in ${totalDuration}ms`);

  // Success if we found anything
  const hasAnything = huntingSource || fishingSource || output.misc_related.length > 0;
  return { success: hasAnything, output, stats };
}

// ============================================================
// Helper Functions
// ============================================================

function createEmptyOutput(stateCode: string, notes: string): DiscoveryOutput {
  return {
    state_code: stateCode,
    hunting: { url: null, pdf_url: null, confidence: 0, evidence: [] },
    fishing: { url: null, pdf_url: null, confidence: 0, evidence: [] },
    misc_related: [],
    notes,
  };
}

function isPdfUrl(url: string): boolean {
  const lower = url.toLowerCase();
  return lower.endsWith('.pdf') || lower.includes('.pdf?') || lower.includes('/pdf/');
}

/**
 * Select top candidates ensuring mix of HTML and PDF.
 */
function selectTopCandidates(pages: CrawlPage[], maxCount: number): CrawlPage[] {
  const htmlPages: CrawlPage[] = [];
  const pdfPages: CrawlPage[] = [];
  
  for (const page of pages) {
    if (isPdfUrl(page.url)) {
      pdfPages.push(page);
    } else {
      htmlPages.push(page);
    }
  }
  
  // Ensure at least 20% are PDFs if available
  const pdfSlots = Math.min(pdfPages.length, Math.max(10, Math.floor(maxCount * 0.2)));
  const htmlSlots = maxCount - pdfSlots;
  
  const result: CrawlPage[] = [];
  result.push(...htmlPages.slice(0, htmlSlots));
  result.push(...pdfPages.slice(0, pdfSlots));
  
  // Sort by score
  result.sort((a, b) => b.score - a.score);
  
  return result.slice(0, maxCount);
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
    hunting: { url: null, pdf_url: null, confidence: 0, evidence: [] },
    fishing: { url: null, pdf_url: null, confidence: 0, evidence: [] },
    misc_related: [],
    notes: 'Selected via fallback heuristics (GPT failed)',
  };

  const huntingKeywords = ['hunting regulations', 'hunting seasons', 'deer season', 'deer hunting', 'hunting guide', 'hunting digest', 'game regulations'];
  const fishingKeywords = ['fishing regulations', 'fishing guide', 'fishing seasons', 'creel limit', 'fishing rules', 'angling'];
  const regsKeywords = ['regulations', 'rules', 'seasons', 'guide', 'handbook', 'digest', 'bag limit'];

  // Find best hunting candidate (prefer HTML, then PDF)
  for (const page of pages) {
    if (!isOnOfficialDomain(page.url, officialDomain)) continue;
    
    const combined = (page.title + ' ' + page.snippet + ' ' + page.url).toLowerCase();
    const matchCount = huntingKeywords.filter(kw => combined.includes(kw)).length;
    
    if (matchCount >= 2) {
      const isPdf = isPdfUrl(page.url);
      if (isPdf) {
        if (!output.hunting.pdf_url) {
          output.hunting.pdf_url = page.url;
          output.hunting.confidence = Math.min(0.5, matchCount * 0.12);
          output.hunting.evidence.push({ url: page.url, snippet: page.snippet.slice(0, 200) });
        }
      } else {
        if (!output.hunting.url) {
          output.hunting.url = page.url;
          output.hunting.confidence = Math.min(0.5, matchCount * 0.12);
          output.hunting.evidence.push({ url: page.url, snippet: page.snippet.slice(0, 200) });
          break; // Found HTML, stop looking
        }
      }
    }
  }

  // Find best fishing candidate
  for (const page of pages) {
    if (!isOnOfficialDomain(page.url, officialDomain)) continue;
    
    const combined = (page.title + ' ' + page.snippet + ' ' + page.url).toLowerCase();
    const matchCount = fishingKeywords.filter(kw => combined.includes(kw)).length;
    
    if (matchCount >= 2) {
      const isPdf = isPdfUrl(page.url);
      if (isPdf) {
        if (!output.fishing.pdf_url) {
          output.fishing.pdf_url = page.url;
          output.fishing.confidence = Math.min(0.5, matchCount * 0.12);
          output.fishing.evidence.push({ url: page.url, snippet: page.snippet.slice(0, 200) });
        }
      } else {
        if (!output.fishing.url) {
          output.fishing.url = page.url;
          output.fishing.confidence = Math.min(0.5, matchCount * 0.12);
          output.fishing.evidence.push({ url: page.url, snippet: page.snippet.slice(0, 200) });
          break;
        }
      }
    }
  }

  // Add misc related URLs for general regs pages
  for (const page of pages) {
    if (output.misc_related.length >= 5) break;
    if (!isOnOfficialDomain(page.url, officialDomain)) continue;
    
    // Skip if already used as hunting/fishing
    if (page.url === output.hunting.url || page.url === output.hunting.pdf_url ||
        page.url === output.fishing.url || page.url === output.fishing.pdf_url) continue;
    
    const combined = (page.title + ' ' + page.snippet + ' ' + page.url).toLowerCase();
    const matchCount = regsKeywords.filter(kw => combined.includes(kw)).length;
    
    if (matchCount >= 1) {
      const label = classifyPageLabel(combined);
      output.misc_related.push({
        url: page.url,
        label,
        confidence: Math.min(0.40, matchCount * 0.10),
        evidence_snippet: page.snippet.slice(0, 200),
      });
    }
  }

  return output;
}

function classifyPageLabel(text: string): string {
  if (text.includes('digest') || text.includes('guide') || text.includes('handbook')) return 'PDF handbook';
  if (text.includes('season') && (text.includes('date') || text.includes('open'))) return 'Season dates';
  if (text.includes('bag limit') || text.includes('creel limit')) return 'Bag limits';
  if (text.includes('license') && text.includes('regulation')) return 'License+regs';
  return 'Regulations landing page';
}

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

function validateAndCleanOutput(output: DiscoveryOutput, officialDomain: string): void {
  // Validate hunting URLs
  if (output.hunting.url && !isOnOfficialDomain(output.hunting.url, officialDomain)) {
    output.hunting.url = null;
    output.hunting.confidence = 0;
  }
  if (output.hunting.pdf_url && !isOnOfficialDomain(output.hunting.pdf_url, officialDomain)) {
    output.hunting.pdf_url = null;
  }
  
  // Validate fishing URLs
  if (output.fishing.url && !isOnOfficialDomain(output.fishing.url, officialDomain)) {
    output.fishing.url = null;
    output.fishing.confidence = 0;
  }
  if (output.fishing.pdf_url && !isOnOfficialDomain(output.fishing.pdf_url, officialDomain)) {
    output.fishing.pdf_url = null;
  }
  
  // Validate misc URLs
  output.misc_related = output.misc_related.filter(m => isOnOfficialDomain(m.url, officialDomain));
}

/**
 * Save discovery result to state_portal_links.
 */
async function saveDiscoveryResult(stateCode: string, output: DiscoveryOutput): Promise<void> {
  const updates: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
    discovery_result_json: output, // Store full output for debugging
    discovery_notes: output.notes,
  };

  // Build confidence object
  const confidence: Record<string, number> = {};
  if (output.hunting.url || output.hunting.pdf_url) {
    confidence.hunting = output.hunting.confidence;
    confidence.hunting_pdf = output.hunting.pdf_url ? output.hunting.confidence : 0;
  }
  if (output.fishing.url || output.fishing.pdf_url) {
    confidence.fishing = output.fishing.confidence;
    confidence.fishing_pdf = output.fishing.pdf_url ? output.fishing.confidence : 0;
  }
  if (output.misc_related.length > 0) {
    confidence.misc = Math.max(...output.misc_related.map(m => m.confidence));
  }
  updates.discovery_confidence = confidence;

  // Hunting HTML
  if (output.hunting.url && output.hunting.confidence >= config.discoveryMinConfidence) {
    updates.hunting_regs_url = output.hunting.url;
    updates.hunting_regs_url_status = 'discovered';
  } else if (output.hunting.url) {
    updates.hunting_regs_url = output.hunting.url;
    updates.hunting_regs_url_status = 'pending_review';
  }

  // Hunting PDF
  if (output.hunting.pdf_url) {
    updates.hunting_regs_pdf_url = output.hunting.pdf_url;
    updates.hunting_regs_pdf_status = 'discovered';
  }

  // Fishing HTML
  if (output.fishing.url && output.fishing.confidence >= config.discoveryMinConfidence) {
    updates.fishing_regs_url = output.fishing.url;
    updates.fishing_regs_url_status = 'discovered';
  } else if (output.fishing.url) {
    updates.fishing_regs_url = output.fishing.url;
    updates.fishing_regs_url_status = 'pending_review';
  }

  // Fishing PDF
  if (output.fishing.pdf_url) {
    updates.fishing_regs_pdf_url = output.fishing.pdf_url;
    updates.fishing_regs_pdf_status = 'discovered';
  }

  // Misc related URLs
  if (output.misc_related.length > 0) {
    updates.misc_related_urls = output.misc_related.map(m => ({
      url: m.url,
      label: m.label,
      confidence: m.confidence,
      evidence_snippet: m.evidence_snippet,
    }));
  }

  await updatePortalLinks(stateCode, updates);
}

// ============================================================
// GPT Guidance
// ============================================================

interface GptGuidanceResult {
  output?: DiscoveryOutput;
  error?: string;
  rateLimited?: boolean;
  retryCount?: number;
}

async function getGptGuidance(
  stateCode: string,
  stateName: string,
  officialDomain: string,
  pages: CrawlPage[],
  tier: 'basic' | 'pro',
  pool: PromisePool
): Promise<GptGuidanceResult> {
  const model = getModelFor(tier, 'discovery');

  // Format pages, marking PDFs
  const pagesText = pages
    .map((p, i) => {
      const isPdf = isPdfUrl(p.url);
      return `[${i}] ${isPdf ? '[PDF] ' : ''}${p.title}\n` +
        `    URL: ${p.url}\n` +
        `    Score: ${p.score.toFixed(2)} | Keywords: ${p.keywords.slice(0, 5).join(', ')}\n` +
        `    Snippet: ${p.snippet.slice(0, 300)}...`;
    })
    .join('\n\n');

  const systemPrompt = `You are an expert at identifying official government wildlife agency regulation pages.

TASK: Analyze pages from ${stateName}'s official wildlife agency website (${officialDomain}) and identify:
1. The official statewide HUNTING regulations page (HTML preferred, PDF acceptable)
2. The official statewide FISHING regulations page (HTML preferred, PDF acceptable)
3. Any other related regulations pages as "misc_related" fallback

IMPORTANT RULES:
- ALL URLs must be on the official domain: ${officialDomain} (or subdomains)
- If regulations are ONLY available as a PDF handbook/guide, use pdf_url field (leave url null)
- If HTML page exists, prefer it over PDF
- NEVER hallucinate URLs - only use URLs from the provided list
- Evidence snippets are REQUIRED for any URL you return
- If uncertain but a page looks regulation-related, add it to misc_related
- Do NOT return empty results if there are any regulation-related candidates

REJECT pages that are:
- Press releases, news articles, blog posts
- License purchase pages (unless they also contain regulations)
- Event announcements
- Pages from other domains

PREFER pages with keywords:
- "regulations", "seasons", "bag limits", "guide", "handbook", "digest"
- Specific season dates, limits, and rules

OUTPUT: Return ONLY valid JSON matching this exact schema:

{
  "state_code": "${stateCode}",
  "hunting": {
    "url": "<HTML page URL from list or null>",
    "pdf_url": "<PDF handbook URL from list or null>",
    "confidence": <0.0-1.0>,
    "evidence": [{"url": "<URL>", "snippet": "<text proving this is the regs page>"}]
  },
  "fishing": {
    "url": "<HTML page URL from list or null>",
    "pdf_url": "<PDF handbook URL from list or null>",
    "confidence": <0.0-1.0>,
    "evidence": [{"url": "<URL>", "snippet": "<text proving this is the regs page>"}]
  },
  "misc_related": [
    {
      "url": "<related regulations URL>",
      "label": "Regulations landing page" | "Season dates" | "PDF handbook" | "Bag limits" | "License+regs",
      "confidence": <0.0-1.0>,
      "evidence_snippet": "<text showing this is regulations-related>"
    }
  ],
  "notes": "<brief explanation of selections>"
}`;

  const userPrompt = `Here are ${pages.length} candidate pages from ${stateName} (${stateCode}) official wildlife website.
Find the best HUNTING regulations page and FISHING regulations page.
Pages marked [PDF] are PDF documents.

CANDIDATES:
${pagesText}

Remember:
- Only use URLs from this list (on ${officialDomain})
- If regs are PDF-only, use pdf_url field
- Add uncertain but relevant pages to misc_related
- Evidence snippets required`;

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

  // Ensure required structure
  if (!parsed.state_code) parsed.state_code = stateCode;
  if (!parsed.hunting) parsed.hunting = { url: null, pdf_url: null, confidence: 0, evidence: [] };
  if (!parsed.fishing) parsed.fishing = { url: null, pdf_url: null, confidence: 0, evidence: [] };
  if (!parsed.misc_related) parsed.misc_related = [];
  if (!parsed.notes) parsed.notes = '';

  return { output: parsed, retryCount: result.retryCount };
}
