import dotenv from 'dotenv';
dotenv.config();

export const config = {
  // Supabase
  supabaseUrl: process.env.SUPABASE_URL || '',
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',

  // OpenAI
  openaiApiKey: process.env.OPENAI_API_KEY || '',
  openaiModelBasic: process.env.OPENAI_MODEL_BASIC || 'gpt-4.1-mini',
  openaiModelPro: process.env.OPENAI_MODEL_PRO || 'gpt-4.1',
  openaiModelProDiscovery: process.env.OPENAI_MODEL_PRO_DISCOVERY,
  openaiModelProExtract: process.env.OPENAI_MODEL_PRO_EXTRACT,
  openaiMaxRetries: parseInt(process.env.OPENAI_MAX_RETRIES || '6', 10),
  openaiMaxConcurrency: parseInt(process.env.OPENAI_MAX_CONCURRENCY || '2', 10),

  // Worker
  workerId: process.env.WORKER_ID || `worker-${process.pid}`,
  workerConcurrency: parseInt(process.env.WORKER_CONCURRENCY || '4', 10),
  jobPollIntervalMs: parseInt(process.env.JOB_POLL_INTERVAL_MS || '2000', 10),

  // PDF limits
  pdfMaxBytes: parseInt(process.env.REGS_PDF_MAX_BYTES || '40000000', 10),
  pdfMaxTextChars: parseInt(process.env.REGS_PDF_MAX_TEXT_CHARS || '600000', 10),
  pdfMaxContextChars: parseInt(process.env.REGS_PDF_MAX_CONTEXT_CHARS || '60000', 10),

  // Timeouts
  fetchTimeoutMs: parseInt(process.env.REGS_FETCH_TIMEOUT_MS || '30000', 10),
  pdfTimeoutMs: parseInt(process.env.REGS_PDF_TIMEOUT_MS || '60000', 10),
};

export function getModelFor(tier: 'basic' | 'pro', task: 'discovery' | 'extract'): string {
  if (tier === 'pro') {
    if (task === 'discovery' && config.openaiModelProDiscovery) {
      return config.openaiModelProDiscovery;
    }
    if (task === 'extract' && config.openaiModelProExtract) {
      return config.openaiModelProExtract;
    }
    return config.openaiModelPro;
  }
  return config.openaiModelBasic;
}

export function validateConfig(): void {
  const required = [
    'supabaseUrl',
    'supabaseServiceRoleKey',
    'openaiApiKey',
  ] as const;

  for (const key of required) {
    if (!config[key]) {
      throw new Error(`Missing required config: ${key}`);
    }
  }
}
