// workers/recompute/src/handler.ts — present in the tree BEFORE this spec runs.
// The spec's worker task extends it; it does not create it.

import { RECOMPUTE_MAX_ATTEMPTS } from './constants.js';

export interface RecomputeJob {
  periodId: string;
  attempt: number;
}

/**
 * Applies one recompute attempt. Returns false when the attempt cap is reached,
 * so the caller marks the job failed rather than re-enqueueing forever.
 */
export async function applyRecompute(job: RecomputeJob): Promise<boolean> {
  if (job.attempt >= RECOMPUTE_MAX_ATTEMPTS) return false;
  // …recompute body elided for the fixture…
  return true;
}
