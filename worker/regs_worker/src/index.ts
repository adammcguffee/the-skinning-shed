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
import { RegsJob, getRunStatus, logJobEvent, recordWorkerHeartbeat } from './supabase';
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

// Heartbeat and stats tracking
let lastHeartbeatTime = 0;
let lastIdleLogTime = 0;
let claimedLast30s = 0;
let totalJobsClaimed = 0;
let totalJobsCompleted = 0;
let loopIterations = 0;
const HEARTBEAT_INTERVAL_MS = 30_000;
const IDLE_LOG_INTERVAL_MS = 30_000;
const HEALTH_CHECK_INTERVAL = 50; // Every N loops, do a health check

// ============================================================
// CRASH PROTECTION - Catch unhandled errors and exit cleanly
// ============================================================
process.on('unhandledRejection', (reason, promise) => {
  console.error('[Worker] FATAL: Unhandled Promise Rejection:', reason);
  console.error('[Worker] Promise:', promise);
  console.error('[Worker] Exiting with code 1 for systemd restart...');
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('[Worker] FATAL: Uncaught Exception:', error.message);
  console.error('[Worker] Stack:', error.stack);
  console.error('[Worker] Exiting with code 1 for systemd restart...');
  process.exit(1);
});

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

// ============================================================
// JOB SLOT TRACKING - Track completion status explicitly
// ============================================================
interface JobSlot {
  promise: Promise<void>;
  done: boolean;
  jobId: string;
  startTime: number;
}

const jobSlots: JobSlot[] = [];

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
      totalJobsCompleted++;
    } else if (result.skipReason) {
      console.log(`[Worker] Job ${job.id} skipped: ${result.skipReason} (${duration}ms)`);
      await completeJob(job.id, 'skipped', { skipReason: result.skipReason, resultJson });
      totalJobsCompleted++;
    } else {
      const errorMsg = result.error || 'Unknown error';
      console.error(`[Worker] Job ${job.id} failed: ${errorMsg} (${duration}ms)`);

      // Check if we should retry
      if (job.attempts < job.max_attempts && isRetryableError(errorMsg)) {
        console.log(`[Worker] Job ${job.id} will be retried (attempt ${job.attempts}/${job.max_attempts})`);
        await completeJob(job.id, 'failed', { errorMessage: `Retry pending: ${errorMsg}`, resultJson });
      } else {
        await completeJob(job.id, 'failed', { errorMessage: errorMsg, resultJson });
      }
      totalJobsCompleted++;
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : 'Unknown error';
    console.error(`[Worker] Job ${job.id} threw exception: ${errorMsg}`);
    try {
      await logJobEvent(job.id, 'error', errorMsg);
      await completeJob(job.id, 'failed', { errorMessage: errorMsg });
    } catch (dbErr) {
      console.error(`[Worker] Failed to log job error to DB:`, dbErr);
    }
    totalJobsCompleted++;
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
 * Log heartbeat with worker stats.
 */
async function logHeartbeat(): Promise<void> {
  const now = Date.now();
  if (now - lastHeartbeatTime < HEARTBEAT_INTERVAL_MS) return;
  
  const slotsDone = jobSlots.filter(s => s.done).length;
  const slotsActive = jobSlots.filter(s => !s.done).length;
  
  console.log(
    `[Worker] Heartbeat: slots=${jobSlots.length} active=${slotsActive} done=${slotsDone} ` +
    `claimed_last_30s=${claimedLast30s} total_claimed=${totalJobsClaimed} total_completed=${totalJobsCompleted} ` +
    `loops=${loopIterations}`
  );
  
  // Reset 30s counter
  claimedLast30s = 0;
  lastHeartbeatTime = now;
  
  // Record heartbeat to Supabase for UI visibility
  try {
    await recordWorkerHeartbeat(workerId, {
      active_jobs: slotsActive,
      total_claimed: totalJobsClaimed,
      total_completed: totalJobsCompleted,
    });
  } catch (err) {
    console.warn('[Worker] Failed to record heartbeat to Supabase:', err);
  }
}

/**
 * Perform health check - lightweight DB query to ensure connectivity.
 */
async function healthCheck(): Promise<void> {
  const start = Date.now();
  try {
    const { getSupabaseClient } = await import('./supabase');
    const client = getSupabaseClient();
    await client.from('regs_admin_runs').select('id').limit(1);
    const latency = Date.now() - start;
    console.log(`[Worker] Health check OK: DB latency ${latency}ms`);
  } catch (err) {
    const latency = Date.now() - start;
    console.error(`[Worker] Health check FAILED after ${latency}ms:`, err);
  }
}

/**
 * Clean up completed job slots.
 * Returns number of slots cleaned.
 */
function cleanupCompletedSlots(): number {
  let cleaned = 0;
  for (let i = jobSlots.length - 1; i >= 0; i--) {
    if (jobSlots[i].done) {
      jobSlots.splice(i, 1);
      activeJobs--;
      cleaned++;
    }
  }
  return cleaned;
}

/**
 * Main worker loop.
 */
async function workerLoop(): Promise<void> {
  console.log(`[Worker] Starting worker ${workerId}`);
  console.log(`[Worker] Concurrency: ${workerConcurrency} jobs, ${openaiConcurrency} OpenAI calls`);
  console.log(`[Worker] Poll interval: ${pollInterval}ms`);
  console.log(`[Worker] Shutdown timeout: ${SHUTDOWN_TIMEOUT_MS / 1000}s`);
  console.log(`[Worker] Heartbeat interval: ${HEARTBEAT_INTERVAL_MS / 1000}s`);
  console.log(`[Worker] Health check every ${HEALTH_CHECK_INTERVAL} loops`);

  const openaiPool = new PromisePool(openaiConcurrency);

  // Create a promise that resolves on shutdown signal
  const shutdownSignal = new Promise<void>((resolve) => {
    shutdownPromiseResolve = resolve;
  });

  // Initial health check
  await healthCheck();

  while (!shuttingDown) {
    loopIterations++;
    
    // Periodic heartbeat
    await logHeartbeat();
    
    // Periodic health check
    if (loopIterations % HEALTH_CHECK_INTERVAL === 0) {
      await healthCheck();
    }

    // Clean up completed slots - THIS IS THE CRITICAL FIX
    // Previously used Promise.race which was broken
    const cleaned = cleanupCompletedSlots();
    if (cleaned > 0) {
      console.log(`[Worker] Cleaned ${cleaned} completed slots, ${jobSlots.length} remaining`);
    }

    // Don't claim new jobs if shutting down
    if (shuttingDown) break;

    // Claim jobs to fill slots
    let claimAttempts = 0;
    const maxClaimAttempts = workerConcurrency * 2; // Prevent infinite loop
    
    while (jobSlots.length < workerConcurrency && !shuttingDown && claimAttempts < maxClaimAttempts) {
      claimAttempts++;
      
      let job: RegsJob | null = null;
      try {
        job = await claimJob(workerId);
      } catch (claimErr) {
        console.error('[Worker] Error claiming job (will retry):', claimErr);
        // Don't exit - just continue the loop
        break;
      }
      
      if (!job) {
        // No more jobs available - log idle status if no active jobs
        const activeCount = jobSlots.filter(s => !s.done).length;
        if (activeCount === 0 && !shuttingDown) {
          const now = Date.now();
          if (now - lastIdleLogTime >= IDLE_LOG_INTERVAL_MS) {
            console.log(`[Worker] No queued jobs available, idle (loop=${loopIterations})`);
            lastIdleLogTime = now;
          }
        }
        break; // No more jobs available
      }

      // Reset idle log time when we claim a job
      lastIdleLogTime = 0;
      activeJobs++;
      totalJobsClaimed++;
      claimedLast30s++;
      
      console.log(`[Worker] Claimed job ${job.id} (${activeJobs}/${workerConcurrency} active, total=${totalJobsClaimed})`);
      
      // Create slot with explicit done tracking
      const slot: JobSlot = {
        promise: null as any,
        done: false,
        jobId: job.id,
        startTime: Date.now(),
      };
      
      slot.promise = processJob(job, openaiPool)
        .catch((err) => {
          console.error(`[Worker] Unhandled error in job ${job!.id}:`, err);
        })
        .finally(() => {
          slot.done = true; // Mark slot as done regardless of success/failure
        });
      
      jobSlots.push(slot);
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
  const activeSlots = jobSlots.filter(s => !s.done);
  if (activeSlots.length > 0) {
    console.log(`[Worker] Shutdown initiated, waiting for ${activeSlots.length} active jobs to finish (max ${SHUTDOWN_TIMEOUT_MS / 1000}s)...`);
    
    const shutdownStart = Date.now();
    
    // Create a timeout promise
    const timeoutPromise = sleep(SHUTDOWN_TIMEOUT_MS).then(() => 'timeout');
    const jobsPromise = Promise.all(activeSlots.map(s => s.promise)).then(() => 'done');
    
    const result = await Promise.race([jobsPromise, timeoutPromise]);
    
    const elapsed = Date.now() - shutdownStart;
    
    if (result === 'timeout') {
      console.warn(`[Worker] Shutdown timeout reached after ${elapsed}ms, ${activeSlots.length} jobs may not have completed`);
    } else {
      console.log(`[Worker] All ${activeSlots.length} active jobs completed in ${elapsed}ms`);
    }
  } else {
    console.log('[Worker] No active jobs, shutting down immediately');
  }

  console.log(`[Worker] Shutdown complete. Stats: claimed=${totalJobsClaimed} completed=${totalJobsCompleted} loops=${loopIterations}`);
  process.exit(0);
}

/**
 * Main entry point.
 */
async function main(): Promise<void> {
  console.log('='.repeat(60));
  console.log('The Skinning Shed - Regulations Worker');
  console.log(`Started at: ${new Date().toISOString()}`);
  console.log(`Worker ID: ${workerId}`);
  console.log(`Node version: ${process.version}`);
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
    console.error('[Worker] Fatal error in worker loop:', err);
    console.error('[Worker] Exiting with code 1 for systemd restart...');
    process.exit(1);
  }
}

main();
