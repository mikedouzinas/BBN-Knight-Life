/**
 * HQ-656's actual reason for existing: a student-facing ingest endpoint means any of
 * ~600 accounts can spend Mike's Anthropic budget. This caps real attempts, not results
 * - the model call costs money whether or not its output validates, so the count is
 * spent before the call, not after a bad response.
 *
 * Mike's own shape: "once or twice a year, maybe a couple scheduled changes pretty
 * frequently." 5 per year - generous enough that a student who drops a class in
 * November doesn't hit a wall, bounded enough that a retry loop or a curious student
 * cannot run up a real bill. Stored on the student's own users/{uid} document, per the
 * ticket, so it can be raised without a release.
 */
import 'server-only';
import { FieldValue } from 'firebase-admin/firestore';
import { adminDb } from './admin';

export const DEFAULT_CLASS_SETUP_BUDGET = 5;
const RESET_INTERVAL_MS = 365 * 24 * 60 * 60 * 1000;

const REMAINING_FIELD = 'classSetupSubmissionsRemaining';
const RESETS_AT_FIELD = 'classSetupBudgetResetsAt';

export interface BudgetStatus {
  remaining: number;
  resetsAt: string;
}

/**
 * Spends one attempt if any remain, atomically. Returns null (nothing spent) if the
 * budget is exhausted for the current period - callers must not call the model in that
 * case. A period boundary that's passed resets to the full budget before spending one.
 */
export async function spendClassSetupAttempt(uid: string): Promise<BudgetStatus | null> {
  const ref = adminDb().collection('users').doc(uid);

  return adminDb().runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const data = snapshot.data() ?? {};
    const now = Date.now();

    const storedResetsAt = typeof data[RESETS_AT_FIELD] === 'string' ? Date.parse(data[RESETS_AT_FIELD]) : NaN;
    const periodExpired = Number.isNaN(storedResetsAt) || storedResetsAt <= now;

    let remaining = periodExpired
      ? DEFAULT_CLASS_SETUP_BUDGET
      : typeof data[REMAINING_FIELD] === 'number'
        ? data[REMAINING_FIELD]
        : DEFAULT_CLASS_SETUP_BUDGET;
    const resetsAt = periodExpired ? new Date(now + RESET_INTERVAL_MS).toISOString() : (data[RESETS_AT_FIELD] as string);

    if (remaining <= 0) {
      tx.set(ref, { [REMAINING_FIELD]: remaining, [RESETS_AT_FIELD]: resetsAt }, { merge: true });
      return null;
    }

    remaining -= 1;
    tx.set(ref, { [REMAINING_FIELD]: remaining, [RESETS_AT_FIELD]: resetsAt }, { merge: true });
    return { remaining, resetsAt };
  });
}

/** Admin top-up - "the person who drops a class in November is exactly the person the limit will hit." */
export async function topUpClassSetupBudget(uid: string, additional: number): Promise<BudgetStatus> {
  const ref = adminDb().collection('users').doc(uid);
  await ref.set(
    {
      [REMAINING_FIELD]: FieldValue.increment(additional),
      // A top-up on an account with no prior period start still needs a resetsAt, so a
      // brand-new field doesn't read as already-expired next call.
      [RESETS_AT_FIELD]: (await ref.get()).data()?.[RESETS_AT_FIELD] ?? new Date(Date.now() + RESET_INTERVAL_MS).toISOString(),
    },
    { merge: true },
  );
  const after = await ref.get();
  return {
    remaining: (after.data()?.[REMAINING_FIELD] as number) ?? additional,
    resetsAt: after.data()?.[RESETS_AT_FIELD] as string,
  };
}
