/**
 * HQ-644: dayWarnings never blocked a publish before this ticket and still doesn't -
 * these tests are about what shows up in the warning list, not about anything failing.
 */
import { describe, expect, it } from 'vitest';
import type { ScheduleDay } from './types';
import { dayWarnings } from './warnings';

const NOSCHOOL: ScheduleDay = { type: 'noschool', reason: 'Snow day' };

const BLOCKS: ScheduleDay = {
  type: 'blocks',
  blocks: [
    { type: 'block', block: 'a', name: 'A', startTime: '8:00 am', endTime: '8:45 am' },
    { type: 'lunch', name: 'Lunch', startTime: '11:45 am', endTime: '12:15 pm' },
  ],
};

// A known Saturday and a known Wednesday, so the test doesn't depend on the day it runs.
const SATURDAY = '2026-12-05';
const WEDNESDAY = '2026-12-02';

describe('dayWarnings weekend check (HQ-644)', () => {
  it('warns loudly when a full schedule is published for a weekend', () => {
    const warnings = dayWarnings(SATURDAY, BLOCKS);
    expect(warnings.some((w) => w.includes('almost certainly wrong'))).toBe(true);
  });

  it('warns quietly when a no-school day is published for a weekend', () => {
    const warnings = dayWarnings(SATURDAY, NOSCHOOL);
    expect(warnings).toContain('Saturday, December 5, 2026 is a weekend.');
    expect(warnings.some((w) => w.includes('almost certainly wrong'))).toBe(false);
  });

  it('does not warn about a weekday', () => {
    const warnings = dayWarnings(WEDNESDAY, BLOCKS);
    expect(warnings.some((w) => w.toLowerCase().includes('weekend'))).toBe(false);
  });

  it('still returns the existing blocks-only warnings unrelated to the weekend check', () => {
    const noLunch: ScheduleDay = {
      type: 'blocks',
      blocks: [{ type: 'block', block: 'a', name: 'A', startTime: '8:00 am', endTime: '8:45 am' }],
    };
    const warnings = dayWarnings(WEDNESDAY, noLunch);
    expect(warnings).toContain('No lunch anywhere in this day.');
  });
});
