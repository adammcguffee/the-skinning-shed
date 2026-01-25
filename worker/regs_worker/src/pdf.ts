import fs from 'fs';
import path from 'path';
import os from 'os';
import pdfParse from 'pdf-parse';
import { config } from './config';

export interface PdfContentInfo {
  contentType: string;
  contentLength: number;
  isPdf: boolean;
  tooLarge: boolean;
}

/**
 * Check content info via HEAD request
 */
export async function getContentInfo(url: string): Promise<PdfContentInfo> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.fetchTimeoutMs);

  try {
    const response = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; SkinningShedBot/1.0)',
      },
    });

    const contentType = response.headers.get('content-type') || '';
    const contentLength = parseInt(response.headers.get('content-length') || '0', 10);
    const isPdf = contentType.toLowerCase().includes('pdf');

    return {
      contentType,
      contentLength,
      isPdf,
      tooLarge: contentLength > config.pdfMaxBytes,
    };
  } catch (err) {
    return {
      contentType: '',
      contentLength: 0,
      isPdf: false,
      tooLarge: false,
    };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Download PDF to temp file with size limit
 */
export async function downloadPdfToFile(url: string): Promise<{
  filePath: string | null;
  error?: string;
  skipReason?: string;
}> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.pdfTimeoutMs);

  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; SkinningShedBot/1.0)',
      },
    });

    if (!response.ok) {
      return { filePath: null, error: `HTTP ${response.status}` };
    }

    const contentType = response.headers.get('content-type') || '';
    if (!contentType.toLowerCase().includes('pdf')) {
      return { filePath: null, skipReason: 'PDF_NOT_A_PDF' };
    }

    const contentLength = parseInt(response.headers.get('content-length') || '0', 10);
    if (contentLength > config.pdfMaxBytes) {
      return { filePath: null, skipReason: 'PDF_TOO_LARGE' };
    }

    // Stream to temp file
    const tempDir = os.tmpdir();
    const tempFile = path.join(tempDir, `regs_pdf_${Date.now()}_${Math.random().toString(36).slice(2)}.pdf`);
    
    const chunks: Buffer[] = [];
    let totalBytes = 0;
    const reader = response.body?.getReader();

    if (!reader) {
      return { filePath: null, error: 'No response body' };
    }

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      totalBytes += value.length;
      if (totalBytes > config.pdfMaxBytes) {
        reader.cancel();
        return { filePath: null, skipReason: 'PDF_TOO_LARGE' };
      }

      chunks.push(Buffer.from(value));
    }

    const buffer = Buffer.concat(chunks);
    fs.writeFileSync(tempFile, buffer);

    return { filePath: tempFile };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    if (message.includes('aborted')) {
      return { filePath: null, error: 'Timeout' };
    }
    return { filePath: null, error: message };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Extract text from PDF file
 */
export async function extractPdfText(filePath: string): Promise<{
  text: string | null;
  error?: string;
}> {
  try {
    const buffer = fs.readFileSync(filePath);
    const data = await pdfParse(buffer, {
      max: 0, // No page limit
    });

    let text = data.text || '';

    // Limit text length
    if (text.length > config.pdfMaxTextChars) {
      text = text.slice(0, config.pdfMaxTextChars);
    }

    return { text };
  } catch (err) {
    return {
      text: null,
      error: err instanceof Error ? err.message : 'PDF parse failed',
    };
  }
}

/**
 * Filter text to keep only relevant sections for a species
 */
export function filterRelevantContent(
  text: string,
  species: 'deer' | 'turkey',
  maxChars: number = config.pdfMaxContextChars
): string {
  const lines = text.split('\n');
  const relevantLines: string[] = [];
  
  // Keywords to look for
  const speciesKeywords = species === 'deer'
    ? ['deer', 'buck', 'doe', 'antler', 'archery', 'firearm', 'muzzleloader', 'whitetail', 'mule deer']
    : ['turkey', 'gobbler', 'hen', 'spring', 'fall', 'beard'];
  
  const seasonKeywords = ['season', 'bag limit', 'harvest', 'hunting', 'open', 'closed', 'dates', 'tag', 'permit'];
  
  let inRelevantSection = false;
  let contextBuffer: string[] = [];
  let totalChars = 0;

  for (const line of lines) {
    const lowerLine = line.toLowerCase();
    
    // Check if this line mentions the species or season info
    const mentionsSpecies = speciesKeywords.some(kw => lowerLine.includes(kw));
    const mentionsSeason = seasonKeywords.some(kw => lowerLine.includes(kw));
    
    if (mentionsSpecies || mentionsSeason) {
      inRelevantSection = true;
      
      // Add context buffer
      for (const ctx of contextBuffer) {
        if (totalChars + ctx.length < maxChars) {
          relevantLines.push(ctx);
          totalChars += ctx.length + 1;
        }
      }
      contextBuffer = [];
    }
    
    if (inRelevantSection) {
      if (totalChars + line.length < maxChars) {
        relevantLines.push(line);
        totalChars += line.length + 1;
      } else {
        break;
      }
      
      // End section after 50 lines without species mention
      if (!mentionsSpecies && relevantLines.length > 50) {
        const last50 = relevantLines.slice(-50);
        const hasSpecies = last50.some(l => 
          speciesKeywords.some(kw => l.toLowerCase().includes(kw))
        );
        if (!hasSpecies) {
          inRelevantSection = false;
        }
      }
    } else {
      // Keep last 3 lines as context
      contextBuffer.push(line);
      if (contextBuffer.length > 3) {
        contextBuffer.shift();
      }
    }
  }

  return relevantLines.join('\n');
}

/**
 * Clean up temp file
 */
export function cleanupTempFile(filePath: string): void {
  try {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  } catch {
    // Ignore cleanup errors
  }
}
