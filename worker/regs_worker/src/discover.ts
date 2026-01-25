/**
 * Discovery job processor.
 * Crawls official state wildlife agency sites to find portal links.
 */
import { RegsJob, getStateOfficialRoot, updatePortalLinks, logJobEvent } from './supabase';
import { crawlOfficialDomain, CrawlPage } from './crawler';
import { callOpenAIWithRetry, parseJsonResponse } from './openai';
import { getModelFor } from './config';
import { PromisePool } from './limiter';

interface DiscoveryResult {
  deer_seasons_url?: string;
  turkey_seasons_url?: string;
  hunting_digest_url?: string;
  fishing_regs_url?: string;
  licensing_url?: string;
  buy_license_url?: string;
  evidence: Record<string, string>;
}

const CANDIDATE_TOP_N = 60;

export async function processDiscoveryJob(
  job: RegsJob,
  openaiPool: PromisePool
): Promise<{
  success: boolean;
  result?: DiscoveryResult;
  skipReason?: string;
  error?: string;
}> {
  const stateCode = job.state_code;
  const tier = job.tier;

  // Get official root
  const root = await getStateOfficialRoot(stateCode);
  if (!root) {
    return { success: false, skipReason: 'NO_OFFICIAL_ROOT' };
  }

  await logJobEvent(job.id, 'info', `Starting discovery for ${stateCode} (${root.state_name})`);

  // Crawl official domain
  const pages = await crawlOfficialDomain(root.official_root_url, root.official_domain, {
    maxPages: 150,
    maxDepth: 3,
    relevantKeywords: [
      'deer', 'turkey', 'hunting', 'fishing', 'season', 'regulation',
      'license', 'permit', 'digest', 'rules', 'bag limit', 'dates',
    ],
  });

  if (pages.length === 0) {
    return { success: false, skipReason: 'NO_PAGES_FOUND' };
  }

  await logJobEvent(job.id, 'info', `Found ${pages.length} candidate pages`);

  // Limit to top N for GPT
  const topPages = pages.slice(0, CANDIDATE_TOP_N);

  // Get GPT guidance on which pages are most relevant
  const guidanceResult = await getGptGuidance(
    stateCode,
    root.state_name,
    topPages,
    tier,
    openaiPool
  );

  if (guidanceResult.error) {
    if (guidanceResult.rateLimited) {
      return { success: false, skipReason: 'RATE_LIMITED' };
    }
    return { success: false, error: guidanceResult.error };
  }

  if (!guidanceResult.selections) {
    return { success: false, skipReason: 'GPT_NO_SELECTIONS' };
  }

  // Build result
  const result: DiscoveryResult = {
    evidence: {},
  };

  for (const [field, selection] of Object.entries(guidanceResult.selections)) {
    if (selection.url && selection.confidence >= 0.7) {
      const key = field as keyof Omit<DiscoveryResult, 'evidence'>;
      result[key] = selection.url;
      result.evidence[field] = selection.reason || '';
    }
  }

  // Update portal links
  const updates: Record<string, unknown> = {};
  if (result.deer_seasons_url) {
    updates.deer_seasons_url = result.deer_seasons_url;
    updates.deer_seasons_url_status = 'discovered';
  }
  if (result.turkey_seasons_url) {
    updates.turkey_seasons_url = result.turkey_seasons_url;
    updates.turkey_seasons_url_status = 'discovered';
  }
  if (result.hunting_digest_url) {
    updates.hunting_digest_url = result.hunting_digest_url;
    updates.hunting_digest_url_status = 'discovered';
  }
  if (result.fishing_regs_url) {
    updates.fishing_regs_url = result.fishing_regs_url;
    updates.fishing_regs_url_status = 'discovered';
  }
  if (result.licensing_url) {
    updates.licensing_url = result.licensing_url;
  }
  if (result.buy_license_url) {
    updates.buy_license_url = result.buy_license_url;
  }

  if (Object.keys(updates).length > 0) {
    await updatePortalLinks(stateCode, updates);
  }

  await logJobEvent(job.id, 'info', `Discovered ${Object.keys(updates).length} portal links`);

  return { success: true, result };
}

interface GptGuidanceResult {
  selections?: Record<string, { url: string; confidence: number; reason: string }>;
  error?: string;
  rateLimited?: boolean;
}

async function getGptGuidance(
  stateCode: string,
  stateName: string,
  pages: CrawlPage[],
  tier: 'basic' | 'pro',
  pool: PromisePool
): Promise<GptGuidanceResult> {
  const model = getModelFor(tier, 'discovery');

  const pagesText = pages
    .map((p, i) => `[${i}] ${p.title}\n    URL: ${p.url}\n    Snippet: ${p.snippet.slice(0, 200)}...`)
    .join('\n\n');

  const systemPrompt = `You are an expert at identifying official government wildlife agency pages.
You will be given a list of pages from ${stateName}'s official wildlife/game agency website.
Your task is to identify the BEST page for each category.

Categories to find:
- deer_seasons_url: The official page with deer hunting season dates and regulations
- turkey_seasons_url: The official page with turkey hunting season dates  
- hunting_digest_url: The main hunting regulations digest/guide (often a PDF)
- fishing_regs_url: The main fishing regulations page
- licensing_url: Where to view license requirements/info
- buy_license_url: Where to actually purchase/apply for licenses online

Rules:
- Only select pages you are confident are correct (confidence >= 0.7)
- Prefer pages with specific season dates over general info pages
- PDF links are acceptable for digest/regulations
- If unsure, set confidence below 0.7 and explain why

Respond with JSON:
{
  "deer_seasons_url": { "url": "...", "confidence": 0.0-1.0, "reason": "..." },
  "turkey_seasons_url": { "url": "...", "confidence": 0.0-1.0, "reason": "..." },
  "hunting_digest_url": { "url": "...", "confidence": 0.0-1.0, "reason": "..." },
  "fishing_regs_url": { "url": "...", "confidence": 0.0-1.0, "reason": "..." },
  "licensing_url": { "url": "...", "confidence": 0.0-1.0, "reason": "..." },
  "buy_license_url": { "url": "...", "confidence": 0.0-1.0, "reason": "..." }
}`;

  const result = await callOpenAIWithRetry(
    {
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Pages from ${stateName} (${stateCode}):\n\n${pagesText}` },
      ],
      temperature: 0,
      responseFormat: 'json',
    },
    pool
  );

  if (result.error) {
    return { error: result.error, rateLimited: result.rateLimited };
  }

  const parsed = parseJsonResponse<Record<string, { url: string; confidence: number; reason: string }>>(
    result.content
  );

  if (!parsed) {
    return { error: 'Failed to parse GPT response' };
  }

  return { selections: parsed };
}
