/**
 * publish(): the ONLY path from a validated day to storage.
 *
 * The UI does not write. The model layer does not write. Everything funnels through
 * `publishDay`, which validates, derives the legacy projection, and hands one plan to a
 * `ScheduleStore`. HQ-603 re-keys the canonical store to `schedules_v2/{YYYY-MM-DD}` by
 * changing `FirestoreScheduleStore` and adding a field to `PublishPlan`, touching neither
 * the UI nor the model layer.
 *
 * DO NOT ADD A DOCUMENT-LEVEL FIELD TO `schedules/special`. `AuthVC.swift:69` iterates
 * every field of that document and force-casts each one to a day: `value as! [String: Any]`
 * then `data["type"] as! String`. An `updatedAt` timestamp at the top level crashes the
 * shipped app on launch for every student. Provenance goes in its own collection below,
 * which is also where the answer to "who maintained this?" will live from now on.
 */
import { z } from 'zod';
import type { LegacyDayDoc, ScheduleDay } from './types';
import { datedScheduleDaySchema, issueLines } from './schema';
import { toCanonicalKey } from './dates';
import { deriveLegacyDay } from './derive';

export type PublishSource = 'manual' | 'ingest';

export interface PublishRequest {
  /** YYYY-MM-DD. */
  date: string;
  day: ScheduleDay;
  /** The signed-in admin's email. Recorded, never trusted from the client. */
  updatedBy: string;
  source: PublishSource;
}

export interface PublishPlan {
  isoDate: string;
  /** `schedules/special` field key, e.g. `2024/9/4`. */
  canonicalKey: string;
  canonicalValue: ScheduleDay;
  /** `special-schedules` document ID, e.g. `Wednesday, September 4, 2024`. */
  legacyId: string;
  legacyDoc: LegacyDayDoc;
  provenance: { updatedBy: string; source: PublishSource; updatedAt: string };
}

export interface ScheduleStore {
  /** Write the whole plan. Both destinations or neither. */
  commit(plan: PublishPlan): Promise<void>;
  /** Optional: what is already published for this date, for a before/after diff. */
  readDay?(isoDate: string): Promise<ScheduleDay | null>;
}

export class ScheduleValidationError extends Error {
  readonly issues: string[];
  constructor(issues: string[]) {
    super(`schedule failed validation:\n${issues.join('\n')}`);
    this.name = 'ScheduleValidationError';
    this.issues = issues;
  }
}

/**
 * Validate and derive, without writing. The preview screen renders this, so what an
 * admin confirms is the exact object that gets committed, not a re-derivation of it.
 */
export function planPublish(request: PublishRequest): PublishPlan {
  const parsed = datedScheduleDaySchema.safeParse({ date: request.date, day: request.day });
  if (!parsed.success) throw new ScheduleValidationError(issueLines(parsed.error as z.ZodError));

  const { date, day } = parsed.data;
  const legacy = deriveLegacyDay(date, day);
  return {
    isoDate: date,
    canonicalKey: toCanonicalKey(date),
    canonicalValue: day as ScheduleDay,
    legacyId: legacy.id,
    legacyDoc: legacy.doc,
    provenance: {
      updatedBy: request.updatedBy,
      source: request.source,
      updatedAt: new Date().toISOString(),
    },
  };
}

/** Validate, derive, write. Nothing else in this app is allowed to write a schedule. */
export async function publishDay(store: ScheduleStore, request: PublishRequest): Promise<PublishPlan> {
  const plan = planPublish(request);
  await store.commit(plan);
  return plan;
}
