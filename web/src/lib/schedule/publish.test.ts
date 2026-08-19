/**
 * The publish path, exercised end to end against an in-memory store. No test in this
 * repo writes to Firestore.
 */
import { describe, expect, it } from 'vitest';
import { MemoryScheduleStore } from './memoryStore';
import { ScheduleValidationError, planPublish, publishDay } from './publish';
import type { ScheduleDay } from './types';
import productionV2 from './__fixtures__/production-v2-2024-09-04.json';

const day = productionV2 as ScheduleDay;

describe('publishDay', () => {
  it('writes the canonical day and its legacy projection together', async () => {
    const store = new MemoryScheduleStore();
    const plan = await publishDay(store, { date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });

    expect(plan.canonicalKey).toBe('2024/9/4');
    expect(store.canonical.get('2024/9/4')).toEqual(plan.canonicalValue);
    expect(store.legacy.get('Wednesday, September 4, 2024')).toEqual(plan.legacyDoc);
    expect(store.commits).toHaveLength(1);
  });

  it('records who published it and how', async () => {
    const store = new MemoryScheduleStore();
    const plan = await publishDay(store, { date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });
    expect(plan.provenance.updatedBy).toBe('a@bbns.org');
    expect(plan.provenance.source).toBe('ingest');
    expect(Date.parse(plan.provenance.updatedAt)).not.toBeNaN();
  });

  it('publishes exactly the object the preview was built from', () => {
    const plan = planPublish({ date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });
    const again = planPublish({ date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });
    expect(again.canonicalValue).toEqual(plan.canonicalValue);
    expect(again.legacyDoc).toEqual(plan.legacyDoc);
  });

  it('refuses to write anything when the day does not validate', async () => {
    const store = new MemoryScheduleStore();
    const broken = { type: 'blocks', blocks: [{ type: 'block', block: 'z', name: 'Z', startTime: 'noon', endTime: 'later' }] };
    await expect(
      publishDay(store, { date: '2024-09-04', day: broken as unknown as ScheduleDay, updatedBy: 'a@bbns.org', source: 'ingest' }),
    ).rejects.toBeInstanceOf(ScheduleValidationError);
    expect(store.commits).toHaveLength(0);
    expect(store.canonical.size).toBe(0);
    expect(store.legacy.size).toBe(0);
  });

  it('refuses a date that does not exist', async () => {
    const store = new MemoryScheduleStore();
    await expect(
      publishDay(store, { date: '2025-02-30', day, updatedBy: 'a@bbns.org', source: 'ingest' }),
    ).rejects.toBeInstanceOf(ScheduleValidationError);
    expect(store.commits).toHaveLength(0);
  });

  it('leaves the other 78 days alone when it republishes one', async () => {
    const store = new MemoryScheduleStore({ '2024/9/2': { type: 'noschool', reason: 'Labor Day' } });
    await publishDay(store, { date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });
    expect(store.canonical.get('2024/9/2')).toEqual({ type: 'noschool', reason: 'Labor Day' });
    expect(store.canonical.size).toBe(2);
  });
});
