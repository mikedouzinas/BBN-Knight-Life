/**
 * The production ScheduleStore.
 *
 * One batch, so the canonical day and its legacy projection land together or not at all.
 * A partial write here is exactly the divergence this tool exists to end.
 *
 * HQ-603 lands here: add `batch.set(db.collection('schedules_v2').doc(plan.isoDate), ...)`
 * and nothing above this file changes.
 */
import 'server-only';
import type { Firestore } from 'firebase-admin/firestore';
import type { PublishPlan, RangePublishPlan, RangeStore, ScheduleStore } from '@/lib/schedule/publish';
import type { ScheduleDay } from '@/lib/schedule/types';
import { toCanonicalKey } from '@/lib/schedule/dates';

export const CANONICAL_DOC = 'schedules/special';
export const LEGACY_COLLECTION = 'special-schedules';
export const PUBLISH_LOG_COLLECTION = 'schedule-publish-log';
/**
 * Breaks. One document whose fields are spans keyed `2026/12/19-2027/1/3`.
 *
 * Deliberately NOT expanded into `schedules/special`. The app reads spans from here directly,
 * and expanding one summer would write ninety day documents that all say the same thing.
 */
export const BREAK_DOC = 'schedules/break';

export class FirestoreScheduleStore implements ScheduleStore {
  constructor(private readonly db: Firestore) {}

  async commit(plan: PublishPlan): Promise<void> {
    const batch = this.db.batch();

    // Canonical. `merge` because this single document holds every special day; a plain
    // set would delete the other 78.
    batch.set(this.db.doc(CANONICAL_DOC), { [plan.canonicalKey]: plan.canonicalValue }, { merge: true });

    // Legacy, derived. A plain set: this document is one day and is owned entirely by
    // the projection, so leftover fields from an older hand-entry must not survive.
    batch.set(this.db.collection(LEGACY_COLLECTION).doc(plan.legacyId), plan.legacyDoc);

    // Provenance. Its own collection because a document-level field on `schedules/special`
    // crashes the shipped app (see publish.ts).
    batch.set(this.db.collection(PUBLISH_LOG_COLLECTION).doc(plan.isoDate), {
      date: plan.isoDate,
      canonicalKey: plan.canonicalKey,
      legacyId: plan.legacyId,
      ...plan.provenance,
    });

    await batch.commit();
  }

  async readDay(isoDate: string): Promise<ScheduleDay | null> {
    const snapshot = await this.db.doc(CANONICAL_DOC).get();
    const data = snapshot.data() ?? {};
    return (data[toCanonicalKey(isoDate)] as ScheduleDay | undefined) ?? null;
  }
}

/**
 * The production RangeStore.
 *
 * `merge: true` on the break document, because it holds every span there is and a plain set
 * would delete the other twelve. That is the same trap as `schedules/special`, and the same
 * answer.
 *
 * Provenance goes to its own collection rather than onto the break document, for the reason
 * spelled out in publish.ts: the shipped app iterates every field of these documents and
 * force-casts each one, so an `updatedAt` at the top level crashes it on launch.
 */
export class FirestoreRangeStore implements RangeStore {
  constructor(private readonly db: Firestore) {}

  async readRanges(): Promise<Record<string, { reason: string }>> {
    const snapshot = await this.db.doc(BREAK_DOC).get();
    return (snapshot.data() ?? {}) as Record<string, { reason: string }>;
  }

  async commitRange(plan: RangePublishPlan): Promise<void> {
    const batch = this.db.batch();

    batch.set(this.db.doc(BREAK_DOC), { [plan.breakKey]: { reason: plan.range.reason } }, { merge: true });

    batch.set(this.db.collection(PUBLISH_LOG_COLLECTION).doc(`break-${plan.breakKey.replace(/\//g, '-')}`), {
      breakKey: plan.breakKey,
      startDate: plan.range.startDate,
      endDate: plan.range.endDate,
      reason: plan.range.reason,
      dayCount: plan.dayCount,
      ...plan.provenance,
    });

    await batch.commit();
  }
}
