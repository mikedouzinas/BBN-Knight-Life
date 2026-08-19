import { describe, expect, it } from 'vitest';
import { fromCanonicalKey, isValidIsoDate, toCanonicalKey, toLegacyKey } from './dates';

describe('date keys', () => {
  it('builds the canonical key without zero padding, as production has it', () => {
    expect(toCanonicalKey('2024-09-04')).toBe('2024/9/4');
    expect(toCanonicalKey('2024-10-11')).toBe('2024/10/11');
  });

  it('builds the legacy document ID with US English names, never a locale', () => {
    expect(toLegacyKey('2024-09-04')).toBe('Wednesday, September 4, 2024');
    expect(toLegacyKey('2026-03-03')).toBe('Tuesday, March 3, 2026');
  });

  it('round-trips the canonical key', () => {
    expect(fromCanonicalKey('2024/9/4')).toBe('2024-09-04');
    expect(fromCanonicalKey(toCanonicalKey('2025-12-12'))).toBe('2025-12-12');
  });

  it('rejects dates that do not exist', () => {
    expect(isValidIsoDate('2025-02-30')).toBe(false);
    expect(isValidIsoDate('2025-13-01')).toBe(false);
    expect(isValidIsoDate('2025-2-1')).toBe(false);
    expect(isValidIsoDate('2025-02-28')).toBe(true);
  });
});
