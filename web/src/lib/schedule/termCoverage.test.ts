import { describe, expect, it } from 'vitest';
import { termCoverageWarning } from './termCoverage';

describe('termCoverageWarning', () => {
  it('warns when there is no term at all', () => {
    const warning = termCoverageWarning(null, '2026-08-19');
    expect(warning?.message).toMatch(/no school-year end date/i);
  });

  it('says nothing when the term ends comfortably in the future', () => {
    expect(termCoverageWarning({ end: '2027/6/8' }, '2026-09-08')).toBeNull();
  });

  it('warns with a day count when the end date is inside the window', () => {
    const warning = termCoverageWarning({ end: '2027-06-08'.split('-').join('/') }, '2027-05-25');
    expect(warning?.message).toMatch(/ends in 14 days/);
  });

  it('warns when the term already ended', () => {
    const warning = termCoverageWarning({ end: '2026/6/1' }, '2026-08-19');
    expect(warning?.message).toMatch(/already ended/);
  });

  it('warns on a malformed end date instead of throwing', () => {
    const warning = termCoverageWarning({ end: 'not-a-date' }, '2026-08-19');
    expect(warning?.message).toMatch(/not a valid/);
  });

  it('rejects a malformed today', () => {
    expect(() => termCoverageWarning({ end: '2027/6/8' }, 'June 1st')).toThrow();
  });
});
