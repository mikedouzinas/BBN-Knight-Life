/**
 * The range write path, against the Firestore emulator.
 *
 * The unit tests use a fake store, so they prove the rules and prove nothing about what
 * actually lands in Firestore. This proves the document shape, and the shape is the part that
 * can crash 582 phones: the shipped 2.4.1 app force-casts every field of `schedules/break`
 * and builds a Swift ClosedRange from every key.
 *
 * Run with:  npm run test:emulator
 * Nothing here can reach production; the Admin SDK routes to the emulator host and the
 * project id is a fake one.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { FirestoreRangeStore, BREAK_DOC, PUBLISH_LOG_COLLECTION } from './firestoreStore';
import { ScheduleValidationError, publishRange } from '@/lib/schedule/publish';

const emulated = process.env.FIRESTORE_EMULATOR_HOST ? describe : describe.skip;

emulated('FirestoreRangeStore', () => {
  let db: Firestore;
  let app: ReturnType<typeof initializeApp>;
  let store: FirestoreRangeStore;

  beforeAll(async () => {
    app = initializeApp({ projectId: 'knight-life-range-test' }, `range-test-${Date.now()}`);
    db = getFirestore(app);
    store = new FirestoreRangeStore(db);
  });

  beforeEach(async () => {
    // A break that must survive every publish below untouched.
    await db.doc(BREAK_DOC).set({ '2026/11/25-2026/11/29': { reason: 'Thanksgiving break' } });
  });

  afterAll(async () => {
    await deleteApp(app);
  });

  const request = (startDate: string, endDate: string, reason: string) => ({
    range: { startDate, endDate, reason },
    updatedBy: 'admin@bbns.org',
    source: 'ingest' as const,
  });

  it('writes a span the shipped app can parse', async () => {
    await publishRange(store, request('2026-12-19', '2027-01-03', 'Winter break'));

    const doc = (await db.doc(BREAK_DOC).get()).data() ?? {};
    const key = '2026/12/19-2027/1/3';

    expect(doc[key]).toEqual({ reason: 'Winter break' });
    // The three properties the shipped parser assumes without checking.
    expect(key.split('-')).toHaveLength(2);
    expect(typeof doc[key].reason).toBe('string');
    expect(key.split('-')[0] <= key.split('-')[1]).toBe(true);
  });

  it('MERGES rather than replacing, so publishing one break does not delete the others', async () => {
    await publishRange(store, request('2027-03-13', '2027-03-28', 'Spring break'));

    const doc = (await db.doc(BREAK_DOC).get()).data() ?? {};
    expect(Object.keys(doc).sort()).toEqual(['2026/11/25-2026/11/29', '2027/3/13-2027/3/28']);
    expect(doc['2026/11/25-2026/11/29']).toEqual({ reason: 'Thanksgiving break' });
  });

  it('puts NO document-level field on the break document', async () => {
    await publishRange(store, request('2027-03-13', '2027-03-28', 'Spring break'));

    const doc = (await db.doc(BREAK_DOC).get()).data() ?? {};
    // Every field must be a span. An `updatedAt` at this level is a launch crash: the shipped
    // app iterates every field and force-casts each one to a break.
    for (const [key, value] of Object.entries(doc)) {
      expect(key.split('-'), `field "${key}" is not a span`).toHaveLength(2);
      expect(typeof value, `field "${key}" is not a map`).toBe('object');
      expect(typeof (value as { reason?: unknown }).reason).toBe('string');
    }
  });

  it('records who published it, in its own collection', async () => {
    await publishRange(store, request('2027-03-13', '2027-03-28', 'Spring break'));

    const log = await db.collection(PUBLISH_LOG_COLLECTION).doc('break-2027-3-13-2027-3-28').get();
    expect(log.exists).toBe(true);
    expect(log.data()).toMatchObject({
      breakKey: '2027/3/13-2027/3/28',
      startDate: '2027-03-13',
      endDate: '2027-03-28',
      reason: 'Spring break',
      dayCount: 16,
      updatedBy: 'admin@bbns.org',
    });
  });

  it('refuses to write a span overlapping one already there', async () => {
    await expect(publishRange(store, request('2026-11-27', '2026-12-02', 'Overlaps')))
      .rejects.toThrow(ScheduleValidationError);

    const doc = (await db.doc(BREAK_DOC).get()).data() ?? {};
    expect(Object.keys(doc)).toEqual(['2026/11/25-2026/11/29']);
  });

  it('writes nothing at all when validation fails', async () => {
    await expect(publishRange(store, request('2027-05-10', '2027-05-01', 'Backwards')))
      .rejects.toThrow(ScheduleValidationError);

    const doc = (await db.doc(BREAK_DOC).get()).data() ?? {};
    expect(Object.keys(doc)).toEqual(['2026/11/25-2026/11/29']);

    // The specific log document, not the collection's size. Asserting an empty collection
    // assumed no earlier test in this file had written one, which was false and made the
    // test fail for a reason that had nothing to do with the behaviour being checked.
    const log = await db.collection(PUBLISH_LOG_COLLECTION).doc('break-2027-5-10-2027-5-1').get();
    expect(log.exists).toBe(false);
  });
});
