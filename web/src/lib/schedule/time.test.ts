import { describe, expect, it } from 'vitest';
import { formatCanonical, formatLegacy, normalizeTime12, parseTime12, toLegacyTime } from './time';

describe('parseTime12', () => {
  it('reads every spelling production contains', () => {
    expect(parseTime12('8:15 am')).toBe(8 * 60 + 15);
    expect(parseTime12('08:15am')).toBe(8 * 60 + 15);
    expect(parseTime12('01:00 pm')).toBe(13 * 60);
    expect(parseTime12('12:05 pm')).toBe(12 * 60 + 5);
    expect(parseTime12('12:05 am')).toBe(5);
    expect(parseTime12('8:15 am')).toBe(8 * 60 + 15); // narrow no-break space
    expect(parseTime12('8:15 A.M.')).toBe(8 * 60 + 15);
  });

  it('rejects anything that is not a 12-hour time', () => {
    for (const bad of ['08:15', '13:00 pm', '8:75 am', '0:15 am', 'noon', '', '8.15 am']) {
      expect(parseTime12(bad)).toBeNull();
    }
  });
});

describe('formatting', () => {
  it('writes the canonical store format', () => {
    expect(formatCanonical(8 * 60 + 15)).toBe('8:15 am');
    expect(formatCanonical(13 * 60)).toBe('1:00 pm');
    expect(formatCanonical(0)).toBe('12:00 am');
    expect(formatCanonical(12 * 60)).toBe('12:00 pm');
  });

  it('writes the legacy format the shipped app can parse', () => {
    // Extensions.swift:251 parses "hh:mma" only: zero-padded, no space.
    expect(formatLegacy(8 * 60 + 15)).toBe('08:15am');
    expect(formatLegacy(13 * 60)).toBe('01:00pm');
    expect(formatLegacy(12 * 60 + 5)).toBe('12:05pm');
    for (const legacy of [formatLegacy(8 * 60 + 15), formatLegacy(13 * 60)]) {
      expect(legacy).toMatch(/^\d{2}:\d{2}(am|pm)$/);
    }
  });

  it('normalizes both directions from any accepted input', () => {
    expect(normalizeTime12('08:15am')).toBe('8:15 am');
    expect(toLegacyTime('1:00 pm')).toBe('01:00pm');
    expect(normalizeTime12('nope')).toBeNull();
    expect(toLegacyTime('nope')).toBeNull();
  });
});
