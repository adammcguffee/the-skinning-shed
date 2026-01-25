/**
 * Smart web crawler for regulations discovery.
 * Breadth-first crawl with keyword scoring and early stopping.
 */
import { config } from './config';
import { sleepWithJitter } from './limiter';

export interface CrawlPage {
  url: string;
  title: string;
  snippet: string;
  depth: number;
  score: number;
  keywords: string[];
}

export interface CrawlStats {
  pagesVisited: number;
  pagesFetched: number;
  pagesBlocked: number;
  pagesSkipped: number;
  durationMs: number;
  earlyStop: boolean;
  earlyStopReason?: string;
}

export interface CrawlResult {
  pages: CrawlPage[];
  stats: CrawlStats;
  blocked: boolean;
  blockReason?: string;
}

// Keywords that indicate regulations/season pages (high value)
const HUNTING_REGS_KEYWORDS = [
  'hunting regulations', 'hunting seasons', 'hunting guide', 'hunting digest',
  'deer season', 'deer hunting', 'turkey season', 'turkey hunting',
  'bag limit', 'season dates', 'harvest', 'antler', 'archery season',
  'firearm season', 'muzzleloader', 'small game', 'big game',
  'game regulations', 'wildlife regulations', 'rules and regulations',
];

const FISHING_REGS_KEYWORDS = [
  'fishing regulations', 'fishing guide', 'fishing seasons',
  'creel limit', 'size limit', 'trout', 'bass', 'catfish',
  'sportfish', 'freshwater fishing', 'saltwater fishing',
  'fishing rules', 'angling',
];

// Keywords that indicate non-regs pages (low value)
const DEPRIORITIZE_KEYWORDS = [
  'news', 'blog', 'press release', 'press-release', 'article',
  'event', 'calendar', 'meeting', 'public notice', 'comment period',
  'shop', 'store', 'merchandise', 'gift', 'careers', 'jobs',
  'contact us', 'about us', 'history', 'mission', 'staff',
  'facebook', 'twitter', 'instagram', 'youtube', 'social media',
  'subscribe', 'newsletter', 'email signup',
];

// URL patterns to skip entirely (but NOT pdfs - we want those!)
const SKIP_URL_PATTERNS = [
  /\/(news|blog|events|calendar|press|media|shop|store|careers|jobs)\//i,
  /\.(jpg|jpeg|png|gif|svg|ico|css|js|woff|woff2|ttf|eot)$/i,
  /\?(utm_|fbclid|gclid|ref=)/i,
  /\/wp-content\/(?!uploads)/i, // Allow wp-content/uploads for PDFs
  /\/feed\/?$/i,
  /\/comments\/?$/i,
  /\/page\/\d+\/?$/i,
  /\/(tag|category|author)\//i,
];

// PDF-related keywords (boost these PDFs)
const PDF_REGS_KEYWORDS = [
  'regulation', 'guide', 'handbook', 'digest', 'seasons', 'rules',
  'hunting', 'fishing', 'wildlife', 'game', 'bag-limit', 'baglimit',
];

/**
 * Smart web crawler that stays within official domain.
 * Features:
 * - Breadth-first crawl
 * - Keyword scoring and prioritization
 * - Early stopping when high-confidence candidates found
 * - Deprioritization of news/blog/events
 * - Retry on transient failures
 */
export async function crawlOfficialDomain(
  rootUrl: string,
  officialDomain: string,
  options: {
    maxPages?: number;
    maxDepth?: number;
    earlyStopThreshold?: number;
  } = {}
): Promise<CrawlResult> {
  const startTime = Date.now();
  const maxPages = options.maxPages ?? config.discoveryMaxPagesPerState;
  const maxDepth = options.maxDepth ?? config.discoveryMaxDepth;
  const earlyStopThreshold = options.earlyStopThreshold ?? config.discoveryEarlyStopThreshold;

  const allKeywords = [...HUNTING_REGS_KEYWORDS, ...FISHING_REGS_KEYWORDS];

  const visited = new Set<string>();
  const pages: CrawlPage[] = [];
  const queue: Array<{ url: string; depth: number; priority: number }> = [];
  
  const stats: CrawlStats = {
    pagesVisited: 0,
    pagesFetched: 0,
    pagesBlocked: 0,
    pagesSkipped: 0,
    durationMs: 0,
    earlyStop: false,
  };

  // Start with root URL
  queue.push({ url: rootUrl, depth: 0, priority: 100 });

  // Track best candidates for early stopping
  let bestHuntingScore = 0;
  let bestFishingScore = 0;

  while (queue.length > 0 && pages.length < maxPages) {
    // Sort queue by priority (highest first)
    queue.sort((a, b) => b.priority - a.priority);
    
    const item = queue.shift();
    if (!item) break;

    const { url, depth } = item;
    
    // Normalize URL
    const normalizedUrl = normalizeUrl(url);
    if (visited.has(normalizedUrl)) continue;
    visited.add(normalizedUrl);
    stats.pagesVisited++;

    // Check if URL should be skipped
    if (shouldSkipUrl(normalizedUrl)) {
      stats.pagesSkipped++;
      continue;
    }

    // Check if URL is within official domain
    if (!isWithinDomain(normalizedUrl, officialDomain)) {
      stats.pagesSkipped++;
      continue;
    }

    // Fetch page with retry
    const fetchResult = await fetchPageWithRetry(normalizedUrl);
    
    if (fetchResult.blocked) {
      stats.pagesBlocked++;
      // If root URL is blocked, the whole crawl is blocked
      if (pages.length === 0) {
        return {
          pages: [],
          stats: { ...stats, durationMs: Date.now() - startTime },
          blocked: true,
          blockReason: fetchResult.blockReason,
        };
      }
      continue;
    }

    if (!fetchResult.html) {
      stats.pagesSkipped++;
      continue;
    }

    stats.pagesFetched++;
    const html = fetchResult.html;
    
    const title = extractTitle(html);
    const text = extractText(html);
    const snippet = extractBestSnippet(text, allKeywords);
    const links = extractLinks(html, normalizedUrl);

    // Score the page
    const { score, matchedKeywords, isHunting, isFishing } = scorePage(title, text, normalizedUrl);

    if (score > 0) {
      const page: CrawlPage = {
        url: normalizedUrl,
        title: title.slice(0, 200),
        snippet: snippet.slice(0, 500),
        depth,
        score,
        keywords: matchedKeywords,
      };
      pages.push(page);

      // Track best candidates for early stopping
      if (isHunting && score > bestHuntingScore) {
        bestHuntingScore = score;
      }
      if (isFishing && score > bestFishingScore) {
        bestFishingScore = score;
      }

      // Early stop if we have high-confidence candidates for both
      if (bestHuntingScore >= earlyStopThreshold && bestFishingScore >= earlyStopThreshold) {
        stats.earlyStop = true;
        stats.earlyStopReason = `Found high-confidence candidates (hunting: ${bestHuntingScore.toFixed(2)}, fishing: ${bestFishingScore.toFixed(2)})`;
        break;
      }
    }

    // Add child links to queue (breadth-first)
    if (depth < maxDepth) {
      for (const link of links) {
        const normLink = normalizeUrl(link);
        if (!visited.has(normLink) && !shouldSkipUrl(normLink) && isWithinDomain(normLink, officialDomain)) {
          const linkPriority = scoreLinkPriority(link, normLink);
          queue.push({ url: normLink, depth: depth + 1, priority: linkPriority });
        }
      }
    }
  }

  // If we have very few candidates, try sitemap.xml as fallback
  if (pages.length < 3 && !stats.earlyStop) {
    const sitemapPages = await trySitemapFallback(rootUrl, officialDomain, allKeywords);
    if (sitemapPages.length > 0) {
      console.log(`[Crawler] Added ${sitemapPages.length} candidates from sitemap.xml`);
      // Add sitemap candidates that aren't already in pages
      const existingUrls = new Set(pages.map(p => p.url));
      for (const sp of sitemapPages) {
        if (!existingUrls.has(sp.url)) {
          pages.push(sp);
        }
      }
    }
  }

  // Sort pages by score (highest first)
  pages.sort((a, b) => b.score - a.score);

  stats.durationMs = Date.now() - startTime;

  return {
    pages,
    stats,
    blocked: false,
  };
}

/**
 * Try to extract candidates from sitemap.xml as a fallback.
 */
async function trySitemapFallback(
  rootUrl: string,
  officialDomain: string,
  keywords: string[]
): Promise<CrawlPage[]> {
  const pages: CrawlPage[] = [];
  
  try {
    const parsed = new URL(rootUrl);
    const sitemapUrl = `${parsed.protocol}//${parsed.host}/sitemap.xml`;
    
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000); // 15s timeout for sitemap
    
    const response = await fetch(sitemapUrl, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/xml, text/xml, */*',
      },
    });
    
    clearTimeout(timeout);
    
    if (!response.ok) {
      return pages;
    }
    
    const xml = await response.text();
    
    // Extract URLs from sitemap
    const urlRegex = /<loc>([^<]+)<\/loc>/gi;
    let match;
    const candidates: Array<{ url: string; score: number }> = [];
    
    while ((match = urlRegex.exec(xml)) !== null) {
      const url = match[1].trim();
      
      // Only keep URLs on official domain
      if (!isWithinDomain(url, officialDomain)) continue;
      
      // Score by regs keywords in URL
      const lowerUrl = url.toLowerCase();
      let score = 0;
      
      // High-value patterns in URL
      if (lowerUrl.includes('regulation')) score += 3;
      if (lowerUrl.includes('hunting')) score += 2;
      if (lowerUrl.includes('fishing')) score += 2;
      if (lowerUrl.includes('season')) score += 2;
      if (lowerUrl.includes('guide') || lowerUrl.includes('digest')) score += 2;
      if (lowerUrl.includes('rules')) score += 1;
      if (lowerUrl.endsWith('.pdf')) score += 1;
      if (lowerUrl.includes('deer') || lowerUrl.includes('turkey')) score += 1;
      
      if (score > 0) {
        candidates.push({ url, score });
      }
    }
    
    // Sort by score and take top 30
    candidates.sort((a, b) => b.score - a.score);
    const topCandidates = candidates.slice(0, 30);
    
    for (const candidate of topCandidates) {
      const isPdf = candidate.url.toLowerCase().endsWith('.pdf');
      pages.push({
        url: candidate.url,
        title: isPdf ? 'PDF from sitemap' : 'Page from sitemap',
        snippet: `Found in sitemap.xml - ${candidate.url}`,
        depth: 0,
        score: candidate.score * 0.1, // Lower scores since we haven't verified content
        keywords: [],
      });
    }
  } catch (err) {
    // Sitemap fetch failed, that's OK
    console.log(`[Crawler] Sitemap fallback failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
  }
  
  return pages;
}

/**
 * Fetch a page with retry on transient failures.
 */
async function fetchPageWithRetry(url: string): Promise<{
  html: string | null;
  blocked: boolean;
  blockReason?: string;
  isPdf?: boolean;
}> {
  const maxRetries = config.fetchMaxRetries;
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), config.fetchTimeoutMs);

      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      });

      clearTimeout(timeout);

      // Check for blocking responses
      if (response.status === 403 || response.status === 429 || response.status === 451) {
        return {
          html: null,
          blocked: true,
          blockReason: `FETCH_BLOCKED_${response.status}`,
        };
      }

      if (!response.ok) {
        // Non-retryable HTTP errors
        if (response.status >= 400 && response.status < 500) {
          return { html: null, blocked: false };
        }
        // Server errors - retry
        throw new Error(`HTTP ${response.status}`);
      }

      const contentType = response.headers.get('content-type') || '';
      
      // Accept HTML pages and PDF documents
      const isHtml = contentType.includes('text/html');
      const isPdf = contentType.includes('application/pdf') || url.toLowerCase().endsWith('.pdf');
      
      if (!isHtml && !isPdf) {
        return { html: null, blocked: false };
      }

      // For PDFs, we don't need the content - just note it's a PDF
      if (isPdf) {
        return { html: `<title>PDF Document</title><body>PDF file at ${url}</body>`, blocked: false, isPdf: true };
      }

      const html = await response.text();
      return { html, blocked: false };
    } catch (err) {
      lastError = err as Error;
      const message = lastError.message || '';

      // Check for abort (timeout)
      if (message.includes('abort') || message.includes('timeout')) {
        if (attempt < maxRetries) {
          await sleepWithJitter(config.fetchRetryDelayMs * (attempt + 1));
          continue;
        }
      }

      // Check for network errors
      if (message.includes('ECONNRESET') || message.includes('ETIMEDOUT') || message.includes('ENOTFOUND')) {
        if (attempt < maxRetries) {
          await sleepWithJitter(config.fetchRetryDelayMs * (attempt + 1));
          continue;
        }
      }

      // Non-retryable error
      break;
    }
  }

  return { html: null, blocked: false };
}

/**
 * Check if a URL should be skipped entirely.
 */
function shouldSkipUrl(url: string): boolean {
  return SKIP_URL_PATTERNS.some((pattern) => pattern.test(url));
}

/**
 * Score a link for queue priority (higher = crawl sooner).
 */
function scoreLinkPriority(linkText: string, url: string): number {
  let priority = 50;
  const lowerUrl = url.toLowerCase();
  const lowerText = linkText.toLowerCase();
  const combined = lowerUrl + ' ' + lowerText;

  // Boost for regulations-related URLs
  if (combined.includes('regulation') || combined.includes('rules')) priority += 30;
  if (combined.includes('hunting') || combined.includes('fishing')) priority += 20;
  if (combined.includes('season') || combined.includes('guide') || combined.includes('digest')) priority += 15;
  if (combined.includes('deer') || combined.includes('turkey')) priority += 10;
  if (combined.includes('license') || combined.includes('permit')) priority += 5;

  // Penalize non-regs URLs
  if (DEPRIORITIZE_KEYWORDS.some((kw) => combined.includes(kw))) priority -= 30;
  
  // Prefer shorter paths (closer to root)
  const pathDepth = (new URL(url).pathname.match(/\//g) || []).length;
  priority -= pathDepth * 2;

  return Math.max(0, priority);
}

/**
 * Score a page for relevance.
 */
function scorePage(
  title: string,
  text: string,
  url: string
): { score: number; matchedKeywords: string[]; isHunting: boolean; isFishing: boolean } {
  const combined = (title + ' ' + text + ' ' + url).toLowerCase();
  const matchedKeywords: string[] = [];
  let huntingScore = 0;
  let fishingScore = 0;

  // Check hunting keywords
  for (const kw of HUNTING_REGS_KEYWORDS) {
    if (combined.includes(kw.toLowerCase())) {
      matchedKeywords.push(kw);
      huntingScore += 0.1;
    }
  }

  // Check fishing keywords
  for (const kw of FISHING_REGS_KEYWORDS) {
    if (combined.includes(kw.toLowerCase())) {
      matchedKeywords.push(kw);
      fishingScore += 0.1;
    }
  }

  // Penalize deprioritized content
  let penalty = 0;
  for (const kw of DEPRIORITIZE_KEYWORDS) {
    if (combined.includes(kw.toLowerCase())) {
      penalty += 0.05;
    }
  }

  // Boost for title matches (stronger signal)
  const lowerTitle = title.toLowerCase();
  if (lowerTitle.includes('regulation') || lowerTitle.includes('rules')) {
    huntingScore += 0.2;
    fishingScore += 0.2;
  }
  if (lowerTitle.includes('hunting')) huntingScore += 0.15;
  if (lowerTitle.includes('fishing')) fishingScore += 0.15;
  if (lowerTitle.includes('season')) {
    huntingScore += 0.1;
    fishingScore += 0.1;
  }

  // Cap scores at 1.0
  huntingScore = Math.min(1.0, Math.max(0, huntingScore - penalty));
  fishingScore = Math.min(1.0, Math.max(0, fishingScore - penalty));

  const score = Math.max(huntingScore, fishingScore);

  return {
    score,
    matchedKeywords,
    isHunting: huntingScore > 0.2,
    isFishing: fishingScore > 0.2,
  };
}

function normalizeUrl(url: string): string {
  try {
    const parsed = new URL(url);
    // Remove trailing slash, fragment, and common tracking params
    parsed.hash = '';
    parsed.searchParams.delete('utm_source');
    parsed.searchParams.delete('utm_medium');
    parsed.searchParams.delete('utm_campaign');
    parsed.searchParams.delete('fbclid');
    parsed.searchParams.delete('gclid');
    let normalized = parsed.toString();
    if (normalized.endsWith('/') && parsed.pathname !== '/') {
      normalized = normalized.slice(0, -1);
    }
    return normalized;
  } catch {
    return url;
  }
}

function isWithinDomain(url: string, domain: string): boolean {
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.toLowerCase();
    const targetDomain = domain.toLowerCase().replace(/^www\./, '');
    return host === targetDomain || host === 'www.' + targetDomain || host.endsWith('.' + targetDomain);
  } catch {
    return false;
  }
}

function extractTitle(html: string): string {
  const match = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  return match ? decodeHtmlEntities(match[1].trim()) : '';
}

function extractText(html: string): string {
  // Remove script and style tags but KEEP nav/header/footer for text extraction
  // (they often contain useful menu link text)
  let text = html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  return decodeHtmlEntities(text);
}

function extractBestSnippet(text: string, keywords: string[]): string {
  const lowerText = text.toLowerCase();
  let bestStart = 0;
  let bestScore = 0;

  // Slide window to find most relevant section
  for (let i = 0; i < Math.min(text.length - 500, 10000); i += 100) {
    const section = lowerText.slice(i, i + 500);
    let score = 0;
    for (const kw of keywords) {
      if (section.includes(kw.toLowerCase())) {
        score += 1;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestStart = i;
    }
  }

  return text.slice(bestStart, bestStart + 500);
}

function extractLinks(html: string, baseUrl: string): string[] {
  const links: string[] = [];
  
  // Standard href links
  const hrefRegex = /href=["']([^"']+)["']/gi;
  let match;
  while ((match = hrefRegex.exec(html)) !== null) {
    addLinkIfValid(match[1], baseUrl, links);
  }
  
  // data-href attributes (common in modern sites)
  const dataHrefRegex = /data-href=["']([^"']+)["']/gi;
  while ((match = dataHrefRegex.exec(html)) !== null) {
    addLinkIfValid(match[1], baseUrl, links);
  }
  
  // data-url attributes
  const dataUrlRegex = /data-url=["']([^"']+)["']/gi;
  while ((match = dataUrlRegex.exec(html)) !== null) {
    addLinkIfValid(match[1], baseUrl, links);
  }
  
  // onclick with location.href (best effort)
  const onclickRegex = /onclick=["'][^"']*(?:location\.href|window\.location)\s*=\s*["']([^"']+)["']/gi;
  while ((match = onclickRegex.exec(html)) !== null) {
    addLinkIfValid(match[1], baseUrl, links);
  }
  
  // <a> tags with href in content (catches some dynamic patterns)
  const srcRegex = /src=["']([^"']+\.pdf)["']/gi;
  while ((match = srcRegex.exec(html)) !== null) {
    addLinkIfValid(match[1], baseUrl, links);
  }

  return [...new Set(links)]; // Dedupe
}

function addLinkIfValid(href: string, baseUrl: string, links: string[]): void {
  try {
    // Skip fragments, javascript, and mailto
    if (!href || href.startsWith('#') || href.startsWith('javascript:') || 
        href.startsWith('mailto:') || href.startsWith('tel:') || href.startsWith('data:')) {
      return;
    }
    
    const absoluteUrl = new URL(href, baseUrl).toString();
    links.push(absoluteUrl);
  } catch {
    // Invalid URL, skip
  }
}

function decodeHtmlEntities(text: string): string {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ');
}
