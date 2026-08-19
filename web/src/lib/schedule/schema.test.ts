import { describe, expect, it } from 'vitest';
import { issueLines, scheduleDaySchema } from './schema';
import productionV2 from './__fixtures__/production-v2-2024-09-04.json';
import gradeDayV2 from './__fixtures__/production-v2-2024-09-03.json';

function reject(day: unknown): string[] {
  const parsed = scheduleDaySchema.safeParse(day);
  expect(parsed.success).toBe(false);
  return parsed.success ? [] : issueLines(parsed.error);
}

describe('the schema accepts what is already published', () => {
  it('takes both real production days unchanged', () => {
    expect(scheduleDaySchema.safeParse(productionV2).success).toBe(true);
    expect(scheduleDaySchema.safeParse(gradeDayV2).success).toBe(true);
  });

  it('normalizes times on the way through', () => {
    const parsed = scheduleDaySchema.parse({
      type: 'blocks',
      blocks: [{ type: 'block', block: 'a', name: 'A', startTime: '08:15AM', endTime: '9:00 a.m.' }],
    });
    expect(parsed.blocks?.[0]).toMatchObject({ startTime: '8:15 am', endTime: '9:00 am' });
  });
});

describe('the schema rejects model output that would mislead a student', () => {
  it('rejects a block with no time', () => {
    expect(reject({ type: 'blocks', blocks: [{ type: 'block', block: 'a', name: 'A' }] }).join()).toMatch(/startTime/);
  });

  it('rejects a made-up block letter', () => {
    expect(reject({
      type: 'blocks',
      blocks: [{ type: 'block', block: 'h', name: 'H', startTime: '8:00 am', endTime: '9:00 am' }],
    }).join()).toMatch(/block/);
  });

  it('rejects 24-hour time', () => {
    expect(reject({
      type: 'blocks',
      blocks: [{ type: 'block', block: 'a', name: 'A', startTime: '13:00', endTime: '14:00' }],
    }).join()).toMatch(/12-hour/);
  });

  it('rejects a backwards block', () => {
    expect(reject({
      type: 'blocks',
      blocks: [{ type: 'block', block: 'a', name: 'A', startTime: '9:00 am', endTime: '8:00 am' }],
    }).join()).toMatch(/before/);
  });

  it('rejects a school day with nothing in it', () => {
    expect(reject({ type: 'blocks', blocks: [] }).join()).toMatch(/at least one block/);
  });

  it('rejects a no-school day with no reason, because students see the reason', () => {
    expect(reject({ type: 'noschool' }).join()).toMatch(/needs a reason/);
  });

  it('rejects a lunch-wave group that does not say which block it splits', () => {
    expect(reject({
      type: 'blocks',
      blocks: [{
        type: 'specific',
        filter: ['L1'],
        contents: [{ type: 'lunch', startTime: '11:25 am', endTime: '12:05 pm' }],
      }],
    }).join()).toMatch(/lunchBlock/);
  });

  it('rejects a group that mixes a grade and a lunch wave', () => {
    expect(reject({
      type: 'blocks',
      blocks: [{
        type: 'specific',
        filter: ['9', 'L1'],
        lunchBlock: 'g',
        contents: [{ type: 'lunch', startTime: '11:25 am', endTime: '12:05 pm' }],
      }],
    }).join()).toMatch(/not both/);
  });

  it('rejects the same lunch wave twice over one block', () => {
    const wave = (filter: string) => ({
      type: 'specific',
      filter: [filter],
      lunchBlock: 'g',
      contents: [{ type: 'lunch', startTime: '11:25 am', endTime: '12:05 pm' }],
    });
    expect(reject({ type: 'blocks', blocks: [wave('L1'), wave('L1')] }).join()).toMatch(/same lunch wave twice/);
  });

  it('rejects an empty group', () => {
    expect(reject({ type: 'blocks', blocks: [{ type: 'specific', filter: ['9'], contents: [] }] }).length).toBeGreaterThan(0);
  });

  it('rejects an unknown top-level type', () => {
    expect(reject({ type: 'halfday', blocks: [] }).length).toBeGreaterThan(0);
  });
});
