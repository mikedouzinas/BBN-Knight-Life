import { describe, expect, it } from 'vitest';
import { toBreakKey, fromBreakKey, daysBetween } from './dates';
describe('range helpers', () => {
  it('builds the break key the shipped app parses', () => {
    expect(toBreakKey('2026-12-19', '2027-01-03')).toBe('2026/12/19-2027/1/3');
  });
  it('round-trips', () => {
    expect(fromBreakKey('2026/12/19-2027/1/3')).toEqual({ start: '2026-12-19', end: '2027-01-03' });
  });
  it('counts days inclusively across a month and year boundary', () => {
    expect(daysBetween('2026-12-19', '2027-01-03')).toBe(16);
    expect(daysBetween('2026-09-08', '2026-09-08')).toBe(1);
    expect(daysBetween('2026-06-15', '2026-09-07')).toBe(85);
  });
});
