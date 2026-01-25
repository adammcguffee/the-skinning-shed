import OpenAI from 'openai';
import { config } from './config';
import { PromisePool, sleepWithJitter } from './limiter';

let openaiClient: OpenAI | null = null;

export function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    openaiClient = new OpenAI({
      apiKey: config.openaiApiKey,
    });
  }
  return openaiClient;
}

export interface OpenAICallOptions {
  model: string;
  messages: Array<{ role: 'system' | 'user' | 'assistant'; content: string }>;
  temperature?: number;
  maxTokens?: number;
  responseFormat?: 'json' | 'text';
}

export interface OpenAICallResult {
  content: string | null;
  error?: string;
  rateLimited?: boolean;
}

/**
 * Call OpenAI with retry and exponential backoff
 */
export async function callOpenAIWithRetry(
  options: OpenAICallOptions,
  pool?: PromisePool
): Promise<OpenAICallResult> {
  const client = getOpenAIClient();
  const maxRetries = config.openaiMaxRetries;

  const doCall = async (): Promise<OpenAICallResult> => {
    let lastError: Error | null = null;
    let retryAfterMs = 1000;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const response = await client.chat.completions.create({
          model: options.model,
          messages: options.messages,
          temperature: options.temperature ?? 0,
          max_tokens: options.maxTokens ?? 4096,
          response_format: options.responseFormat === 'json' 
            ? { type: 'json_object' } 
            : undefined,
        });

        const content = response.choices[0]?.message?.content || null;
        return { content };
      } catch (err) {
        lastError = err as Error;
        const errorMessage = lastError.message || '';

        // Check for rate limit
        if (errorMessage.includes('429') || errorMessage.toLowerCase().includes('rate limit')) {
          console.warn(`[OpenAI] Rate limited (attempt ${attempt + 1}/${maxRetries}), waiting ${retryAfterMs}ms...`);
          
          // Try to parse Retry-After header from error
          const retryMatch = errorMessage.match(/retry.after[:\s]+(\d+)/i);
          if (retryMatch) {
            retryAfterMs = Math.max(retryAfterMs, parseInt(retryMatch[1], 10) * 1000);
          }

          await sleepWithJitter(retryAfterMs);
          retryAfterMs = Math.min(retryAfterMs * 2, 60000); // Cap at 60 seconds
          continue;
        }

        // Check for server errors (5xx)
        if (errorMessage.includes('500') || errorMessage.includes('502') || 
            errorMessage.includes('503') || errorMessage.includes('504')) {
          console.warn(`[OpenAI] Server error (attempt ${attempt + 1}/${maxRetries}), retrying...`);
          await sleepWithJitter(retryAfterMs);
          retryAfterMs = Math.min(retryAfterMs * 2, 30000);
          continue;
        }

        // Non-retryable error
        break;
      }
    }

    return {
      content: null,
      error: lastError?.message || 'Unknown error',
      rateLimited: lastError?.message?.includes('429') || false,
    };
  };

  // Use pool if provided
  if (pool) {
    return pool.run(doCall);
  }

  return doCall();
}

/**
 * Parse JSON response from OpenAI
 */
export function parseJsonResponse<T>(content: string | null): T | null {
  if (!content) return null;

  try {
    // Try to extract JSON from markdown code blocks
    const jsonMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[1].trim());
    }

    // Try direct parse
    return JSON.parse(content);
  } catch {
    console.warn('[OpenAI] Failed to parse JSON response');
    return null;
  }
}
