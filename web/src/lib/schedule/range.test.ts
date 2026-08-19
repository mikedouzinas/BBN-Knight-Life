/**
 * Ranges, and specifically the shapes that crash the SHIPPED 2.4.1 app.
 *
 * Those students cannot be made to update, so every rule here is load-bearing against a
 * binary that will never change. A reversed span is not a validation nicety: CalendarVC
 * builds `(start...end)`, a Swift ClosedRange, which traps at runtime.
 */
import { describe, expect, it } from 'vitest';
import {
  ScheduleValidationError,
  planRangePublish,
  publishRange,
  rangesOverlap,
  type RangePublishPlan,
  type RangeStore,
} from './publish';

function store(existing: Record<string, { reason: string }> = {}) {
  const committed: RangePublishPlan[] = [];
  const impl: RangeStore & { committed: RangePublishPlan[] } = {
    committed,
    readRanges: async () => existing,
    commitRange: async (plan) => {
      committed.push(plan);
    },
  };
  return impl;
}

const REQUEST = (over: Partial<{ startDate: string; endDate: string; reason: string }> = {}) => ({
  range: { startDate: '2026-12-19', endDate: '2027-01-03', reason: 'Winter break', ...over },
  updatedBy: 'admin@bbns.org',
  source: 'ingest' as const,
});

describe('planning a range', () => {
  it('builds the key the shipped app can parse, and counts the days', () => {
    const plan = planRangePublish(REQUEST());
    expect(plan.breakKey).toBe('2026/12/19-2027/1/3');
    expect(plan.dayCount).toBe(16);
  });

  it('accepts a single-day span', () => {
    expect(planRangePublish(REQUEST({ startDate: '2026-11-11', endDate: '2026-11-11' })).dayCount).toBe(1);
  });

  /**
   * FALSIFIED 2026-08-19: removed the `endDate < startDate` refinement from
   * scheduleRangeSchema. This failed with
   *   AssertionError: expected function to throw an error, but it didn't
   * The assertion is that it throws at all, so rewording the message cannot break it, and
   * deleting the check cannot pass it.
   */
  it('REFUSES a reversed span, which traps the shipped app at runtime', () => {
    expect(() => planRangePublish(REQUEST({ startDate: '2027-01-03', endDate: '2026-12-19' })))
      .toThrow(ScheduleValidationError);
  });

  it('refuses a span with no reason, which the shipped app force-casts', () => {
    expect(() => planRangePublish(REQUEST({ reason: '' }))).toThrow(ScheduleValidationError);
  });

  it('refuses a date that is not YYYY-MM-DD', () => {
    expect(() => planRangePublish(REQUEST({ startDate: '2026/12/19' }))).toThrow(ScheduleValidationError);
    expect(() => planRangePublish(REQUEST({ startDate: '2026-02-30' }))).toThrow(ScheduleValidationError);
  });

  it('never writes while planning', async () => {
    const s = store();
    planRangePublish(REQUEST());
    expect(s.committed).toEqual([]);
  });
});

describe('overlap', () => {
  it('detects every way two spans can share a day', () => {
    const a = { start: '2026-12-19', end: '2027-01-03' };
    expect(rangesOverlap(a, { start: '2026-12-25', end: '2026-12-26' })).toBe(true);  // inside
    expect(rangesOverlap(a, { start: '2026-12-01', end: '2026-12-19' })).toBe(true);  // touches start
    expect(rangesOverlap(a, { start: '2027-01-03', end: '2027-01-20' })).toBe(true);  // touches end
    expect(rangesOverlap(a, { start: '2026-01-01', end: '2027-12-31' })).toBe(true);  // encloses
    expect(rangesOverlap(a, { start: '2027-01-04', end: '2027-01-20' })).toBe(false); // adjacent, clear
    expect(rangesOverlap(a, { start: '2026-11-01', end: '2026-12-18' })).toBe(false);
  });

  /**
   * FALSIFIED 2026-08-19: made publishRange skip the overlap scan. This failed with
   *   AssertionError: promise resolved "{ …(4) }" instead of rejecting
   * i.e. it went ahead and published a span over one already there.
   */
  it('refuses a span overlapping one already published', async () => {
    const s = store({ '2026/12/22-2027/1/2': { reason: 'Winter break' } });
    await expect(publishRange(s, REQUEST())).rejects.toThrow(ScheduleValidationError);
    expect(s.committed).toEqual([]);
  });

  it('allows republishing the same span, which is an edit', async () => {
    const s = store({ '2026/12/19-2027/1/3': { reason: 'Winter break' } });
    await publishRange(s, REQUEST({ reason: 'Winter break (extended)' }));
    expect(s.committed).toHaveLength(1);
    expect(s.committed[0].range.reason).toBe('Winter break (extended)');
  });

  it('allows a span that merely abuts another', async () => {
    const s = store({ '2026/11/25-2026/11/29': { reason: 'Thanksgiving break' } });
    await publishRange(s, REQUEST({ startDate: '2026-11-30', endDate: '2026-12-05' }));
    expect(s.committed).toHaveLength(1);
  });

  it('ignores a malformed existing key rather than crashing on it', async () => {
    const s = store({ 'not-a-range-key-at-all': { reason: 'junk' }, 'nohyphen': { reason: 'junk' } });
    await publishRange(s, REQUEST());
    expect(s.committed).toHaveLength(1);
  });
});

describe('the real 2026-27 calendar', () => {
  it('plans every published break without complaint', () => {
    const real: [string, string, string][] = [
      ['2026-06-15', '2026-09-07', 'Summer break'],
      ['2026-11-25', '2026-11-29', 'Thanksgiving break'],
      ['2026-12-19', '2027-01-03', 'Winter break'],
      ['2027-03-13', '2027-03-28', 'Spring break'],
      ['2027-06-09', '2027-09-06', 'Summer break'],
    ];
    for (const [startDate, endDate, reason] of real) {
      const plan = planRangePublish(REQUEST({ startDate, endDate, reason }));
      expect(plan.breakKey.split('-')).toHaveLength(2);
      expect(plan.dayCount).toBeGreaterThan(0);
    }
  });
});
