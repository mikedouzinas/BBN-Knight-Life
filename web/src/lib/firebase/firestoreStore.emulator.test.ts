/**
 * The real write path, against the Firestore emulator.
 *
 * Skipped unless FIRESTORE_EMULATOR_HOST is set, so `npm test` never needs a network or
 * a running emulator. From the repo root:
 *
 *   firebase emulators:exec --only firestore "cd web && npm test"
 *
 * Nothing here can reach production: the Admin SDK routes every call to the emulator
 * host when that variable is set, and the project id below is a fake one.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { FirestoreScheduleStore, CANONICAL_DOC, LEGACY_COLLECTION, PUBLISH_LOG_COLLECTION } from './firestoreStore';
import { publishDay } from '@/lib/schedule/publish';
import type { ScheduleDay } from '@/lib/schedule/types';
import productionV2 from '@/lib/schedule/__fixtures__/production-v2-2024-09-04.json';

const emulated = process.env.FIRESTORE_EMULATOR_HOST ? describe : describe.skip;

emulated('FirestoreScheduleStore', () => {
  let db: Firestore;
  let app: ReturnType<typeof initializeApp>;

  beforeAll(async () => {
    app = initializeApp({ projectId: 'knight-life-test' }, `test-${Date.now()}`);
    db = getFirestore(app);
    // A day that must survive the publish untouched.
    await db.doc(CANONICAL_DOC).set({ '2024/9/2': { type: 'noschool', reason: 'Labor Day' } });
  });

  afterAll(async () => {
    await deleteApp(app);
  });

  it('writes the canonical day, the legacy projection, and the provenance in one commit', async () => {
    const store = new FirestoreScheduleStore(db);
    const plan = await publishDay(store, {
      date: '2024-09-04',
      day: productionV2 as ScheduleDay,
      updatedBy: 'maintainer@bbns.org',
      source: 'ingest',
    });

    const canonical = (await db.doc(CANONICAL_DOC).get()).data()!;
    expect(canonical['2024/9/4']).toEqual(plan.canonicalValue);

    // The other 78 days are still there. A plain set instead of a merge deletes them,
    // and nothing would notice until every student opened a blank calendar.
    expect(canonical['2024/9/2']).toEqual({ type: 'noschool', reason: 'Labor Day' });

    const legacy = (await db.collection(LEGACY_COLLECTION).doc('Wednesday, September 4, 2024').get()).data();
    expect(legacy).toEqual(plan.legacyDoc);

    const log = (await db.collection(PUBLISH_LOG_COLLECTION).doc('2024-09-04').get()).data();
    expect(log).toMatchObject({ updatedBy: 'maintainer@bbns.org', source: 'ingest', canonicalKey: '2024/9/4' });
  });

  it('adds no document-level field to schedules/special, which would crash the shipped app', async () => {
    const canonical = (await db.doc(CANONICAL_DOC).get()).data()!;
    for (const [key, value] of Object.entries(canonical)) {
      expect(key).toMatch(/^\d{4}\/\d{1,2}\/\d{1,2}$/);
      expect(typeof (value as { type?: unknown }).type).toBe('string');
    }
  });

  it('replaces a hand-entered legacy document rather than merging into it', async () => {
    await db.collection(LEGACY_COLLECTION).doc('Wednesday, September 4, 2024').set({ junk: 'left over from 2022' }, { merge: true });
    const store = new FirestoreScheduleStore(db);
    await publishDay(store, {
      date: '2024-09-04',
      day: productionV2 as ScheduleDay,
      updatedBy: 'maintainer@bbns.org',
      source: 'ingest',
    });
    const legacy = (await db.collection(LEGACY_COLLECTION).doc('Wednesday, September 4, 2024').get()).data()!;
    expect(legacy.junk).toBeUndefined();
  });

  it('reads a published day back', async () => {
    const store = new FirestoreScheduleStore(db);
    expect(await store.readDay('2024-09-02')).toEqual({ type: 'noschool', reason: 'Labor Day' });
    expect(await store.readDay('2030-01-01')).toBeNull();
  });
});
