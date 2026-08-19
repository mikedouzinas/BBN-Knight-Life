/**
 * The derivation is the one thing here that can silently corrupt what an old client
 * sees, so it is tested against real production documents rather than invented ones.
 * Both fixtures were read out of the live database on 2026-08-19.
 */
import { describe, expect, it } from 'vitest';
import { deriveLegacyDay, flattenForWave } from './derive';
import { scheduleDaySchema } from './schema';
import { parseTime12, toLegacyTime } from './time';
import type { LegacyBlock, ScheduleDay } from './types';
import productionV2 from './__fixtures__/production-v2-2024-09-04.json';
import productionV1 from './__fixtures__/production-v1-2024-09-04.json';
import gradeDayV2 from './__fixtures__/production-v2-2024-09-03.json';

function normalizeProduction(rows: { name: string; block: string; startTime: string; endTime: string }[]): LegacyBlock[] {
  // Production rows were hand-entered over four years, so their times use several
  // spellings. Comparing content means comparing them in one spelling.
  return rows.map((row) => ({
    name: row.name,
    block: row.block,
    startTime: toLegacyTime(row.startTime) ?? row.startTime,
    endTime: toLegacyTime(row.endTime) ?? row.endTime,
  }));
}

describe('deriveLegacyDay against a real production day', () => {
  const day = scheduleDaySchema.parse(productionV2) as ScheduleDay;
  const derived = deriveLegacyDay('2024-09-04', day);

  it('keys the document the way the shipped app looks it up', () => {
    expect(derived.id).toBe('Wednesday, September 4, 2024');
    expect(derived.doc.date).toBe('Wednesday, September 4, 2024');
  });

  it('reproduces the second lunch wave in `blocks`', () => {
    expect(derived.doc.blocks).toEqual(normalizeProduction(productionV1.blocks));
  });

  it('reproduces the first lunch wave in `blocks-l1`, and fixes one am/pm typo doing it', () => {
    const production = normalizeProduction(productionV1['blocks-l1']);
    // Production has this lunch ending at "12:05am", i.e. five past midnight. It is one
    // of the three am/pm typos the migration notes call out, and it is exactly what a
    // hand-typed second copy produces. The canonical day says 12:05 pm, so the
    // projection writes 12:05 pm. This assertion is the difference, spelled out.
    const typo = production.findIndex((row) => row.name === 'Lunch' && row.endTime === '12:05am');
    expect(typo).toBeGreaterThanOrEqual(0);
    expect(derived.doc['blocks-l1'][typo].endTime).toBe('12:05pm');

    production[typo] = { ...production[typo], endTime: '12:05pm' };
    expect(derived.doc['blocks-l1']).toEqual(production);
  });

  it('puts G1 before lunch in the second wave and after it in the first', () => {
    // If these two are ever swapped, half the school goes to lunch an hour early and
    // nothing errors. This is the assertion that catches it.
    const second = derived.doc.blocks.map((b) => b.name);
    const first = derived.doc['blocks-l1'].map((b) => b.name);
    expect(second.indexOf('G1')).toBeLessThan(second.indexOf('Lunch'));
    expect(first.indexOf('Lunch')).toBeLessThan(first.indexOf('G2'));
  });

  it('writes only times the shipped app can parse', () => {
    for (const row of [...derived.doc.blocks, ...derived.doc['blocks-l1']]) {
      expect(row.startTime).toMatch(/^\d{2}:\d{2}(am|pm)$/);
      expect(row.endTime).toMatch(/^\d{2}:\d{2}(am|pm)$/);
    }
  });

  it('writes "A".."G" for letter blocks and "N/A" for everything else', () => {
    const byName = Object.fromEntries(derived.doc.blocks.map((b) => [b.name, b.block]));
    expect(byName.E).toBe('E');
    expect(byName.G1).toBe('G');
    expect(byName['Class Meeting']).toBe('N/A');
    expect(byName.Lunch).toBe('N/A');
  });

  it('orders rows by start time', () => {
    const minutes = derived.doc.blocks.map((b) => parseTime12(b.startTime)!);
    expect(minutes).toEqual([...minutes].sort((a, b) => a - b));
  });
});

describe('grade-filtered content, which the legacy schema cannot express', () => {
  const day = scheduleDaySchema.parse(gradeDayV2) as ScheduleDay;
  const derived = deriveLegacyDay('2024-09-03', day);
  const names = derived.doc.blocks.map((b) => b.name);

  it('keeps grade-specific rows instead of dropping them', () => {
    expect(names).toContain('Gr. 9 Arrival/Bag Drop');
    expect(names).toContain('Gr. 10-11 New 10/11s Orientation');
  });

  it('folds the audience into the row name', () => {
    expect(names).toContain('Gr. 10-12 Advisory');
  });

  it('does not label a row that already names its grade', () => {
    expect(names).not.toContain('Gr. 9 Gr. 9 Arrival/Bag Drop');
  });

  it('puts the same grade rows in both waves, since grade is not a lunch wave', () => {
    expect(derived.doc['blocks-l1']).toEqual(derived.doc.blocks);
  });
});

describe('non-teaching days', () => {
  it('writes a no-school day with a reason and no rows', () => {
    const derived = deriveLegacyDay('2024-09-02', { type: 'noschool', reason: 'Labor Day' });
    expect(derived.doc).toEqual({
      date: 'Monday, September 2, 2024',
      reason: 'Labor Day',
      imageUrl: '',
      blocks: [],
      'blocks-l1': [],
    });
  });

  it('carries an image day through as an image', () => {
    const derived = deriveLegacyDay('2024-06-03', { type: 'image', imageUrl: 'https://example.com/s.png' });
    expect(derived.doc.imageUrl).toBe('https://example.com/s.png');
    expect(derived.doc.blocks).toEqual([]);
  });
});

describe('flattenForWave', () => {
  const day: ScheduleDay = {
    type: 'blocks',
    blocks: [
      { type: 'block', block: 'a', name: 'A', startTime: '8:00 am', endTime: '8:45 am' },
      {
        type: 'specific',
        filter: ['L1'],
        matchMode: 'any',
        lunchBlock: 'b',
        contents: [{ type: 'lunch', startTime: '11:00 am', endTime: '11:30 am' }],
      },
      {
        type: 'specific',
        filter: ['L2'],
        matchMode: 'any',
        lunchBlock: 'b',
        contents: [{ type: 'lunch', startTime: '11:30 am', endTime: '12:00 pm' }],
      },
    ],
  };

  it('gives each wave only its own lunch', () => {
    expect(flattenForWave(day, 'L1').map((r) => r.startTime)).toEqual(['08:00am', '11:00am']);
    expect(flattenForWave(day, 'L2').map((r) => r.startTime)).toEqual(['08:00am', '11:30am']);
  });
});
