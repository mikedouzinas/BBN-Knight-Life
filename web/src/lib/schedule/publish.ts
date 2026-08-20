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
import { datedScheduleDaySchema, issueLines, scheduleRangeSchema, type ScheduleRange } from './schema';
import { toBreakKey, toCanonicalKey, toLegacyBreakId, daysBetween } from './dates';
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


/* -------------------------------------------------------------------------- ranges ---- */

export interface RangePublishRequest {
  range: ScheduleRange;
  updatedBy: string;
  source: PublishSource;
}

export interface RangePublishPlan {
  /** `schedules/break` field key, e.g. `2026/12/19-2027/1/3`. */
  breakKey: string;
  /**
   * `special-schedules` document id, e.g. `Saturday, December 19, 2026-Sunday, January 3, 2027`.
   *
   * Derived, never authored. The shipped 2.4.1 app reads THIS, not breakKey, when deciding
   * whether to schedule notifications, so publishing a break without it silences the calendar
   * and leaves the alarms.
   */
  legacyBreakId: string;
  range: ScheduleRange;
  /** Inclusive, so a reviewer can see "16 days" rather than count. */
  dayCount: number;
  provenance: { updatedBy: string; source: PublishSource; updatedAt: string };
}

export interface RangeStore {
  /** Every range currently published, keyed as `schedules/break` holds them. */
  readRanges(): Promise<Record<string, { reason: string }>>;
  commitRange(plan: RangePublishPlan): Promise<void>;
}

/** Validate and describe a range without writing it. */
export function planRangePublish(request: RangePublishRequest): RangePublishPlan {
  const parsed = scheduleRangeSchema.safeParse(request.range);
  if (!parsed.success) throw new ScheduleValidationError(issueLines(parsed.error as z.ZodError));

  const range = parsed.data;
  return {
    breakKey: toBreakKey(range.startDate, range.endDate),
    legacyBreakId: toLegacyBreakId(range.startDate, range.endDate),
    range,
    dayCount: daysBetween(range.startDate, range.endDate),
    provenance: {
      updatedBy: request.updatedBy,
      source: request.source,
      updatedAt: new Date().toISOString(),
    },
  };
}

/** True when two inclusive ISO spans share at least one day. */
export function rangesOverlap(a: { start: string; end: string }, b: { start: string; end: string }): boolean {
  return a.start <= b.end && b.start <= a.end;
}

/**
 * Validate, check against what is already published, write.
 *
 * Overlap is refused rather than merged. Two ranges covering the same day are not a crash,
 * but they are a disagreement nobody can see: the app takes whichever the dictionary iterates
 * first, so students get "Winter break" or "Spring break" depending on Firestore's ordering.
 * Refusing makes the admin say which one they meant.
 */
export async function publishRange(store: RangeStore, request: RangePublishRequest): Promise<RangePublishPlan> {
  const plan = planRangePublish(request);

  const existing = await store.readRanges();
  const clashes: string[] = [];
  for (const key of Object.keys(existing)) {
    if (key === plan.breakKey) continue; // republishing the same span is an edit, not a clash
    const parts = key.split('-');
    if (parts.length !== 2) continue;
    const [y1, m1, d1] = parts[0].split('/').map(Number);
    const [y2, m2, d2] = parts[1].split('/').map(Number);
    const iso = (y: number, m: number, d: number) =>
      `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const other = { start: iso(y1, m1, d1), end: iso(y2, m2, d2) };
    if (rangesOverlap({ start: plan.range.startDate, end: plan.range.endDate }, other)) {
      clashes.push(`${key} (${existing[key]?.reason ?? 'no reason'})`);
    }
  }
  if (clashes.length) {
    throw new ScheduleValidationError([
      `that span overlaps a break already published: ${clashes.join(', ')}`,
      'Two breaks covering one day disagree, and the app shows whichever it reads first.',
    ]);
  }

  await store.commitRange(plan);
  return plan;
}
