import { describe, expect, it } from 'vitest';
import { audienceLabel, renderForAudience } from './render';
import { scheduleDaySchema } from './schema';
import type { ScheduleDay } from './types';
import productionV2 from './__fixtures__/production-v2-2024-09-04.json';
import gradeDayV2 from './__fixtures__/production-v2-2024-09-03.json';

const lunchDay = scheduleDaySchema.parse(productionV2) as ScheduleDay;
const gradeDay = scheduleDaySchema.parse(gradeDayV2) as ScheduleDay;

describe('renderForAudience', () => {
  it('gives a first-lunch student lunch before G2', () => {
    const rows = renderForAudience(lunchDay, { grade: '10', lunchWave: 'L1' }).map((r) => r.name);
    expect(rows).toContain('G2');
    expect(rows).not.toContain('G1');
    expect(rows.indexOf('Lunch')).toBeLessThan(rows.indexOf('G2'));
  });

  it('gives a second-lunch student G1 before lunch', () => {
    const rows = renderForAudience(lunchDay, { grade: '10', lunchWave: 'L2' }).map((r) => r.name);
    expect(rows).toContain('G1');
    expect(rows).not.toContain('G2');
    expect(rows.indexOf('G1')).toBeLessThan(rows.indexOf('Lunch'));
  });

  it('shows both waves to a student who has not set one, matching the app', () => {
    const rows = renderForAudience(lunchDay, { grade: '10', lunchWave: null }).map((r) => r.name);
    expect(rows).toContain('G1');
    expect(rows).toContain('G2');
  });

  it('shows a ninth grader only their own orientation blocks', () => {
    const rows = renderForAudience(gradeDay, { grade: '9', lunchWave: 'L1' }).map((r) => r.name);
    expect(rows).toContain('Gr. 9 Arrival/Bag Drop');
    expect(rows).not.toContain('New 10/11s Orientation');
  });

  it('shows a twelfth grader nothing from the ninth grade group', () => {
    const rows = renderForAudience(gradeDay, { grade: '12', lunchWave: 'L1' }).map((r) => r.name);
    expect(rows).not.toContain('Gr. 9 Arrival/Bag Drop');
    expect(rows).toContain('Advisory');
  });

  it('labels rows that came from a group', () => {
    const advisory = renderForAudience(gradeDay, { grade: '11', lunchWave: 'L1' }).find((r) => r.name === 'Advisory');
    expect(advisory?.audienceLabel).toBe('Gr. 10-12');
  });

  it('sorts by time, not by authored order', () => {
    const rows = renderForAudience(lunchDay, { grade: '9', lunchWave: 'L2' });
    const hours = rows.map((r) => r.startTime);
    expect(hours[0]).toBe('8:15 am');
    expect(hours[hours.length - 1]).toBe('1:30 pm');
  });
});

describe('audienceLabel', () => {
  it('compresses runs of grades', () => {
    expect(audienceLabel(['10', '11', '12', 'teacher'])).toBe('Gr. 10-12');
    expect(audienceLabel(['9', 'teacher'])).toBe('Gr. 9');
    expect(audienceLabel(['9', '12', 'teacher'])).toBe('Gr. 9/12');
    expect(audienceLabel(['9', '10', '11', '12'])).toBe('All grades');
    expect(audienceLabel(['teacher'])).toBe('Faculty');
    expect(audienceLabel(['L1'])).toBe('1st lunch');
    expect(audienceLabel(['L2'])).toBe('2nd lunch');
  });
});
