/**
 * Regulations Worker - Main Entry Point
 * 
 * Polls Supabase for queued jobs and processes them:
 * - discover_state: Crawl official site, find portal links via GPT
 * - extract_state_species: Parse HTML/PDF, extract season data via GPT
 * 
 * Run with: npm start (after npm run build)
 */
import { config, validateConfig } from './config';
import { RegsJob, getRunStatus, logJobEvent } from './supabase';
import { claimJob, completeJob, shouldContinueRun } from './job_claim';
import { PromisePool, sleep } from './limiter';
import { processDiscoveryJob } from './discover';
import { processExtractionJob } from './extract';

const workerId = config.workerId;
const workerConcurrency = config.workerConcurrency;
const openaiConcurrency = config.openaiMaxConcurrency;
const pollInterval = config.jobPollIntervalMs;

// Graceful shutdown state
let shuttingDown = false;
let activeJobs = 0;
let shutdownPromiseResolve: (() => void) | null = null;

// Max time to wait for active jobs to finish (150s, well under systemd's 180s timeout)
const SHUTDOWN_TIMEOUT_MS = 150_000;

// Graceful shutdown handlers
process.on('SIGTERM', () => {
  console.log('[Worker] Received SIGTERM, initiating graceful shutdown...');
  console.log(`[Worker] Active jobs: ${activeJobs}, will wait up to ${SHUTDOWN_TIMEOUT_MS / 1000}s for completion`);
  shuttingDown = true;
  if (shutdownPromiseResolve) {
    shutdownPromiseResolve();
  }
});

process.on('SIGINT', () => {
  console.log('[Worker] Received SIGINT, initiating graceful shutdown...');
  console.log(`[Worker] Active jobs: ${activeJobs}, will wait up to ${SHUTDOWN_TIMEOUT_MS / 1000}s for completion`);
  shuttingDown = true;
  if (shutdownPromiseResolve) {
    shutdownPromiseResolve();
  }
});

/**
 * Process a single job.
 */
async function processJob(job: RegsJob, openaiPool: PromisePool): Promise<void> {
  const startTime = Date.now();
  console.log(`[Worker] Processing job ${job.id} (${job.job_type} for ${job.state_code})`);

  try {
    // Check if run is stopping
    const runStatus = await getRunStatus(job.run_id);
    if (runStatus === 'stopping' || runStatus === 'stopped') {
      console.log(`[Worker] Run ${job.run_id} is ${runStatus}, canceling job`);
      await completeJob(job.id, 'canceled', { skipReason: 'Run stopped' });
      return;
    }

    let result: {
      success: boolean;
      output?: unknown;
      skipReason?: string;
      error?: string;
      stats?: Record<string, unknown>;
    };

    if (job.job_type === 'discover_state') {
      result = await processDiscoveryJob(job, openaiPool);
    } else if (job.job_type === 'extract_state_species') {
      result = await processExtractionJob(job, openaiPool);
    } else {
      result = { success: false, error: `Unknown job type: ${job.job_type}` };
    }

    const duration = Date.now() - startTime;

    // Build result JSON including stats for debugging
    const resultJson = {
      output: result.output,
      stats: result.stats,
      duration_ms: duration,
    };

    if (result.success) {
      console.log(`[Worker] Job ${job.id} completed in ${duration}ms`);
      await completeJob(job.id, 'done', { resultJson });
    } else if (result.skipReason) {
      console.log(`[Worker] Job ${job.id} skipped: ${result.skipReason} (${duration}ms)`);
      await completeJob(job.id, 'skipped', { skipReason: result.skipReason, resultJson });
    } else {
      const errorMsg = result.error || 'Unknown error';
      console.error(`[Worker] Job ${job.id} failed: ${errorMsg} (${duration}ms)`);

      // Check if we should retry
      if (job.attempts < job.max_attempts && isRetryableError(errorMsg)) {
        console.log(`[Worker] Job ${job.id} will be retried (attempt ${job.attempts}/${job.max_attempts})`);
        // Mark as failed but allow retry - the job stays in a state where it can be reclaimed
        await completeJob(job.id, 'failed', { errorMessage: `Retry pending: ${errorMsg}`, resultJson });
      } else {
        await completeJob(job.id, 'failed', { errorMessage: errorMsg, resultJson });
      }
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : 'Unknown error';
    console.error(`[Worker] Job ${job.id} threw exception: ${errorMsg}`);
    await logJobEvent(job.id, 'error', errorMsg);
    await completeJob(job.id, 'failed', { errorMessage: errorMsg });
  }
}

/**
 * Check if an error is retryable (transient).
 */
function isRetryableError(error: string): boolean {
  const retryable = [
    '429',
    'rate limit',
    'timeout',
    '500',
    '502',
    '503',
    '504',
    'ECONNRESET',
    'ETIMEDOUT',
    'ENOTFOUND',
  ];
  const lowerError = error.toLowerCase();
  return retryable.some((r) => lowerError.includes(r.toLowerCase()));
}

/**
 * Main worker loop.
 */
async function workerLoop(): Promise<void> {
  console.log(`[Worker] Starting worker ${workerId}`);
  console.log(`[Worker] Concurrency: ${workerConcurrency} jobs, ${openaiConcurrency} OpenAI calls`);
  console.log(`[Worker] Poll interval: ${pollInterval}ms`);
  console.log(`[Worker] Shutdown timeout: ${SHUTDOWN_TIMEOUT_MS / 1000}s`);

  const openaiPool = new PromisePool(openaiConcurrency);
  const jobSlots: Array<Promise<void>> = [];

  // Create a promise that resolves on shutdown signal
  const shutdownSignal = new Promise<void>((resolve) => {
    shutdownPromiseResolve = resolve;
  });

  while (!shuttingDown) {
    // Clean up completed slots
    for (let i = jobSlots.length - 1; i >= 0; i--) {
      const slot = jobSlots[i];
      const isDone = await Promise.race([
        slot.then(() => true),
        Promise.resolve(false),
      ]);
      if (isDone) {
        jobSlots.splice(i, 1);
        activeJobs--;
      }
    }

    // Don't claim new jobs if shutting down
    if (shuttingDown) break;

    // Claim jobs to fill slots
    while (jobSlots.length < workerConcurrency && !shuttingDown) {
      const job = await claimJob(workerId);
      if (!job) {
        break; // No more jobs available
      }

      activeJobs++;
      console.log(`[Worker] Claimed job ${job.id} (${activeJobs}/${workerConcurrency} active)`);
      
      const jobPromise = processJob(job, openaiPool).catch((err) => {
        console.error(`[Worker] Unhandled error in job ${job.id}:`, err);
      });
      jobSlots.push(jobPromise);
    }

    // Wait before next poll, but also listen for shutdown signal
    if (!shuttingDown) {
      await Promise.race([
        sleep(pollInterval),
        shutdownSignal,
      ]);
    }
  }

  // Wait for active jobs to finish with timeout
  if (jobSlots.length > 0) {
    console.log(`[Worker] Shutdown initiated, waiting for ${jobSlots.length} active jobs to finish (max ${SHUTDOWN_TIMEOUT_MS / 1000}s)...`);
    
    const shutdownStart = Date.now();
    
    // Create a timeout promise
    const timeoutPromise = sleep(SHUTDOWN_TIMEOUT_MS).then(() => 'timeout');
    const jobsPromise = Promise.all(jobSlots).then(() => 'done');
    
    const result = await Promise.race([jobsPromise, timeoutPromise]);
    
    const elapsed = Date.now() - shutdownStart;
    
    if (result === 'timeout') {
      console.warn(`[Worker] Shutdown timeout reached after ${elapsed}ms, ${jobSlots.length} jobs may not have completed`);
    } else {
      console.log(`[Worker] All ${jobSlots.length} active jobs completed in ${elapsed}ms`);
    }
  } else {
    console.log('[Worker] No active jobs, shutting down immediately');
  }

  console.log('[Worker] Shutdown complete, exiting...');
  process.exit(0);
}

/**
 * Main entry point.
 */
async function main(): Promise<void> {
  console.log('='.repeat(60));
  console.log('The Skinning Shed - Regulations Worker');
  console.log('='.repeat(60));

  try {
    validateConfig();
    console.log('[Worker] Configuration validated');
  } catch (err) {
    console.error('[Worker] Configuration error:', err);
    process.exit(1);
  }

  try {
    await workerLoop();
  } catch (err) {
    console.error('[Worker] Fatal error:', err);
    process.exit(1);
  }
}

main();
