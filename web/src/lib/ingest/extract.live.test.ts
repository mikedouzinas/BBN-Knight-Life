/**
 * A real call to the model. Skipped unless ANTHROPIC_API_KEY is set, so `npm test` stays
 * offline and free. Run it when the prompt or the tool schema changes:
 *
 *   ANTHROPIC_API_KEY=... npx vitest run src/lib/ingest/extract.live.test.ts
 *
 * It asserts the two things that are actually load-bearing: the model's output passes
 * the strict schema, and the lunch waves come out as two groups rather than one flat
 * list. It reads nothing from Firestore and writes nothing anywhere.
 */
import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { extractSchedule } from './extract';
import { renderForAudience } from '@/lib/schedule/render';

const fixture = (name: string) => fs.readFileSync(path.join(__dirname, '__fixtures__', name)).toString('base64');

const live = process.env.ANTHROPIC_API_KEY ? describe : describe.skip;

const SOURCE = `Special Schedule - Wednesday, September 4

8:15-9:00    E
9:05-9:50    C
9:55-10:30   Class Meeting
10:35-11:20  D

First lunch:   Lunch 11:25-12:05, then G 12:10-12:55
Second lunch:  G 11:25-12:10, then Lunch 12:15-12:55

1:00-1:30    Dessert in the Courtyard
1:30-2:30    Student Leadership Workshop (grades 11 and 12 only)`;

live('extractSchedule against the live model', () => {
  it('reads a schedule email into a day that validates', { timeout: 180_000 }, async () => {
    const result = await extractSchedule({ text: SOURCE, defaultYear: 2024 });

    expect(result.rejected).toEqual([]);
    expect(result.days).toHaveLength(1);
    const [day] = result.days;
    expect(day.date).toBe('2024-09-04');
    expect(day.day.type).toBe('blocks');

    const first = renderForAudience(day.day, { grade: '10', lunchWave: 'L1' }).map((r) => r.name);
    const second = renderForAudience(day.day, { grade: '10', lunchWave: 'L2' }).map((r) => r.name);

    // The lunch split has to survive as two groups, not one flat list, or half the
    // school is shown the wrong hour.
    expect(first.indexOf('Lunch')).toBeLessThan(first.length - 1);
    expect(second.indexOf('Lunch')).toBeGreaterThan(0);
    expect(first).not.toEqual(second);

    // Grade-restricted content stays restricted.
    const ninth = renderForAudience(day.day, { grade: '9', lunchWave: 'L1' }).map((r) => r.name);
    const twelfth = renderForAudience(day.day, { grade: '12', lunchWave: 'L1' }).map((r) => r.name);
    expect(twelfth.some((n) => n.includes('Leadership'))).toBe(true);
    expect(ninth.some((n) => n.includes('Leadership'))).toBe(false);
  });
});

live('extractSchedule from a file', () => {
  /**
   * The same one-page schedule as a PDF and as a photo of that PDF. Both paths are
   * covered because "it handles PDFs" and "it handles a picture someone took" are
   * different claims and only one of them was ever obvious.
   */
  const expectations = (day: { date: string; day: import('@/lib/schedule/types').ScheduleDay }) => {
    expect(day.date).toBe('2025-10-16');
    const first = renderForAudience(day.day, { grade: '11', lunchWave: 'L1' }).map((r) => r.name);
    const second = renderForAudience(day.day, { grade: '11', lunchWave: 'L2' }).map((r) => r.name);
    expect(first).not.toEqual(second);
    expect(first[0]).toBe('B');
    expect(first.indexOf('Lunch')).toBeLessThan(first.indexOf('C'));
    expect(second.indexOf('C')).toBeLessThan(second.indexOf('Lunch'));
    expect(first).toContain('Assembly');
  };

  it('reads a PDF', { timeout: 180_000 }, async () => {
    const result = await extractSchedule({
      attachments: [{ mediaType: 'application/pdf', data: fixture('sample-schedule.pdf') }],
      defaultYear: 2025,
    });
    expect(result.rejected).toEqual([]);
    expect(result.days).toHaveLength(1);
    expectations(result.days[0]);
  });

  it('reads a photo', { timeout: 180_000 }, async () => {
    const result = await extractSchedule({
      attachments: [{ mediaType: 'image/png', data: fixture('sample-schedule.png') }],
      defaultYear: 2025,
    });
    expect(result.rejected).toEqual([]);
    expect(result.days).toHaveLength(1);
    expectations(result.days[0]);
  });
});

live('ranges, against the real model', () => {
  it('reads a break announcement as ONE range, not a pile of days', async () => {
    const result = await extractSchedule({
      text:
        'Winter break begins after classes on Friday, December 18. ' +
        'Classes resume Monday, January 4.',
      hintDate: '2026-12-18',
    });

    expect(result.ranges).toHaveLength(1);
    expect(result.days).toHaveLength(0);

    const range = result.ranges[0];
    expect(range.startDate).toBe('2026-12-19');
    // The whole point. "Classes resume Monday Jan 4" means the last day OFF is Sunday Jan 3.
    // Reading the resume date as the end date takes an extra day of school off the calendar.
    expect(range.endDate).toBe('2027-01-03');
    expect(range.reason.toLowerCase()).toContain('winter');
  }, 120_000);

  it('still uses a day, not a range, for a single holiday', async () => {
    const result = await extractSchedule({
      text: 'No school Monday, October 12, Indigenous Peoples Day.',
      hintDate: '2026-10-12',
    });

    expect(result.ranges).toHaveLength(0);
    expect(result.days).toHaveLength(1);
    expect(result.days[0].day.type).toBe('noschool');
  }, 120_000);

  it('handles a source carrying a break AND a schedule day together', async () => {
    const result = await extractSchedule({
      text:
        'Thanksgiving break runs from Wednesday November 25 through Sunday November 29. ' +
        'On Tuesday November 24 we run a half day: A 8:15-9:00 am, B 9:05-9:50 am, ' +
        'C 10:00-10:45 am, then dismissal.',
      hintDate: '2026-11-24',
    });

    expect(result.ranges).toHaveLength(1);
    expect(result.ranges[0].startDate).toBe('2026-11-25');
    expect(result.ranges[0].endDate).toBe('2026-11-29');
    expect(result.days).toHaveLength(1);
    expect(result.days[0].date).toBe('2026-11-24');
    expect(result.days[0].day.type).toBe('blocks');
  }, 120_000);
});
