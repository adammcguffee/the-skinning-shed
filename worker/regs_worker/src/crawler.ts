import { config } from './config';

export interface CrawlPage {
  url: string;
  title: string;
  snippet: string;
  depth: number;
}

/**
 * Simple web crawler that stays within official domain
 */
export async function crawlOfficialDomain(
  rootUrl: string,
  officialDomain: string,
  options: {
    maxPages?: number;
    maxDepth?: number;
    relevantKeywords?: string[];
  } = {}
): Promise<CrawlPage[]> {
  const maxPages = options.maxPages ?? 100;
  const maxDepth = options.maxDepth ?? 3;
  const relevantKeywords = options.relevantKeywords ?? [
    'hunting', 'fishing', 'deer', 'turkey', 'season', 'regulation',
    'license', 'permit', 'wildlife', 'game', 'digest', 'rules',
  ];

  const visited = new Set<string>();
  const pages: CrawlPage[] = [];
  const queue: Array<{ url: string; depth: number }> = [{ url: rootUrl, depth: 0 }];

  while (queue.length > 0 && pages.length < maxPages) {
    const item = queue.shift();
    if (!item) break;

    const { url, depth } = item;
    
    // Normalize URL
    const normalizedUrl = normalizeUrl(url);
    if (visited.has(normalizedUrl)) continue;
    visited.add(normalizedUrl);

    // Check if URL is within official domain
    if (!isWithinDomain(normalizedUrl, officialDomain)) continue;

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), config.fetchTimeoutMs);

      const response = await fetch(normalizedUrl, {
        signal: controller.signal,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; SkinningShedBot/1.0)',
        },
      });

      clearTimeout(timeout);

      if (!response.ok) continue;

      const contentType = response.headers.get('content-type') || '';
      if (!contentType.includes('text/html')) continue;

      const html = await response.text();
      const title = extractTitle(html);
      const snippet = extractSnippet(html, relevantKeywords);
      const links = extractLinks(html, normalizedUrl);

      // Score relevance
      const relevanceScore = scoreRelevance(title + ' ' + snippet, relevantKeywords);

      if (relevanceScore > 0) {
        pages.push({
          url: normalizedUrl,
          title: title.slice(0, 200),
          snippet: snippet.slice(0, 500),
          depth,
        });
      }

      // Add child links to queue
      if (depth < maxDepth) {
        for (const link of links) {
          if (!visited.has(normalizeUrl(link))) {
            queue.push({ url: link, depth: depth + 1 });
          }
        }
      }
    } catch {
      // Skip failed fetches
      continue;
    }
  }

  // Sort by relevance
  pages.sort((a, b) => {
    const scoreA = scoreRelevance(a.title + ' ' + a.snippet, relevantKeywords);
    const scoreB = scoreRelevance(b.title + ' ' + b.snippet, relevantKeywords);
    return scoreB - scoreA;
  });

  return pages;
}

function normalizeUrl(url: string): string {
  try {
    const parsed = new URL(url);
    // Remove trailing slash, fragment, and common tracking params
    parsed.hash = '';
    parsed.searchParams.delete('utm_source');
    parsed.searchParams.delete('utm_medium');
    parsed.searchParams.delete('utm_campaign');
    let normalized = parsed.toString();
    if (normalized.endsWith('/')) {
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
    return host === targetDomain || host.endsWith('.' + targetDomain);
  } catch {
    return false;
  }
}

function extractTitle(html: string): string {
  const match = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  return match ? match[1].trim() : '';
}

function extractSnippet(html: string, keywords: string[]): string {
  // Remove script and style tags
  let text = html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  // Find most relevant section
  const lowerText = text.toLowerCase();
  let bestStart = 0;
  let bestScore = 0;

  for (let i = 0; i < text.length - 500; i += 100) {
    const section = lowerText.slice(i, i + 500);
    let score = 0;
    for (const kw of keywords) {
      if (section.includes(kw.toLowerCase())) {
        score++;
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
  const regex = /href=["']([^"']+)["']/gi;
  let match;

  while ((match = regex.exec(html)) !== null) {
    try {
      const href = match[1];
      // Skip fragments, javascript, and mailto
      if (href.startsWith('#') || href.startsWith('javascript:') || href.startsWith('mailto:')) {
        continue;
      }
      
      const absoluteUrl = new URL(href, baseUrl).toString();
      links.push(absoluteUrl);
    } catch {
      continue;
    }
  }

  return links;
}

function scoreRelevance(text: string, keywords: string[]): number {
  const lowerText = text.toLowerCase();
  let score = 0;

  for (const kw of keywords) {
    if (lowerText.includes(kw.toLowerCase())) {
      score++;
    }
  }

  return score;
}
