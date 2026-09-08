import { describe, expect, it } from 'vitest';
import { parseBreaks, resolveDay, specialDaysByIso, toIsoTerm, weekOf, weekdayOf, type SchoolYearInput } from './schoolDay';
import type { ScheduleDay } from './types';

const A_BLOCK = { type: 'block' as const, block: 'a', name: 'A', startTime: '8:15 am', endTime: '9:00 am' };

function input(overrides: Partial<SchoolYearInput> = {}): SchoolYearInput {
  return {
    specialDays: {},
    regularWeek: { monday: [A_BLOCK], tuesday: [A_BLOCK], wednesday: [A_BLOCK], thursday: [A_BLOCK], friday: [A_BLOCK] },
    breaks: [],
    term: null,
    ...overrides,
  };
}

describe('weekdayOf', () => {
  it('reads the weekday in UTC, not local time', () => {
    // 2026-09-08 is a Tuesday. Parsed as local time in a negative-offset zone this lands
    // on the Monday, which is how a schedule shows the wrong day for a whole timezone.
    expect(weekdayOf('2026-09-08')).toBe('tuesday');
    expect(weekdayOf('2026-09-06')).toBe('sunday');
    expect(weekdayOf('2026-09-12')).toBe('saturday');
  });
});

describe('resolveDay', () => {
  it('uses the regular weekly pattern on an ordinary weekday', () => {
    const got = resolveDay('2026-09-08', input());
    expect(got.source).toBe('regular');
    expect(got.day.blocks).toHaveLength(1);
  });

  it('closes the weekend', () => {
    expect(resolveDay('2026-09-12', input()).source).toBe('weekend');
    expect(resolveDay('2026-09-13', input()).source).toBe('weekend');
  });

  it('prefers a published special day over the weekly pattern', () => {
    const special: ScheduleDay = { type: 'blocks', reason: 'Assembly', blocks: [] };
    const got = resolveDay('2026-09-08', input({ specialDays: { '2026-09-08': special } }));
    expect(got.source).toBe('special');
    expect(got.day.reason).toBe('Assembly');
  });

  it('lets a break beat a stale special day', () => {
    // 90 day documents live in schedules/special and nothing prunes them. A break is the
    // more recent statement about a date, so a leftover day must not reopen school.
    const got = resolveDay('2026-12-22', input({
      specialDays: { '2026-12-22': { type: 'blocks', blocks: [A_BLOCK] } },
      breaks: [{ start: '2026-12-19', end: '2027-01-03', reason: 'Winter Break' }],
    }));
    expect(got.source).toBe('break');
    expect(got.reason).toBe('Winter Break');
  });

  it('includes both endpoints of a break', () => {
    const breaks = [{ start: '2026-12-19', end: '2027-01-03', reason: 'Winter Break' }];
    expect(resolveDay('2026-12-19', input({ breaks })).source).toBe('break');
    expect(resolveDay('2027-01-03', input({ breaks })).source).toBe('break');
    expect(resolveDay('2027-01-04', input({ breaks })).source).toBe('regular');
  });

  it('refuses to call a date outside the term a school day', () => {
    // HQ-928: before term started, the calendar named a summer day as the next day of
    // classes. Term is checked before anything else for that reason.
    const got = resolveDay('2026-07-14', input({ term: { start: '2026-09-08', end: '2027-06-08' } }));
    expect(got.source).toBe('outside-term');
    expect(got.day.type).toBe('noschool');
  });

  it('says so rather than inventing a day when nothing is published', () => {
    const got = resolveDay('2026-09-08', input({ regularWeek: {} }));
    expect(got.day.type).toBe('noschool');
    expect(got.reason).toMatch(/No schedule/);
  });
});

describe('parseBreaks', () => {
  it('reads the production key format', () => {
    const spans = parseBreaks({ '2026/12/19-2027/1/3': { reason: 'Winter Break' } });
    expect(spans).toEqual([{ start: '2026-12-19', end: '2027-01-03', reason: 'Winter Break' }]);
  });

  it('skips a malformed key instead of closing the school', () => {
    const spans = parseBreaks({ 'nonsense': { reason: 'x' }, '2026/12/19-2027/1/3': { reason: 'ok' } });
    expect(spans).toHaveLength(1);
    expect(spans[0].reason).toBe('ok');
  });
});

describe('specialDaysByIso', () => {
  it('re-keys yyyy/M/d to ISO', () => {
    const got = specialDaysByIso({ '2026/9/8': { type: 'blocks', blocks: [] } });
    expect(Object.keys(got)).toEqual(['2026-09-08']);
  });

  it('drops keys that are not canonical', () => {
    // A zero-padded key round-trips to a different string, which means whatever wrote it
    // was not this tool. Skipping it beats guessing what date it meant.
    const got = specialDaysByIso({ '2026/09/08': { type: 'blocks', blocks: [] }, 'junk': {} });
    expect(Object.keys(got)).toEqual([]);
  });
});

describe('toIsoTerm', () => {
  it('reads the canonical format the term document actually uses', () => {
    // Production `schedules/term` is {start: "2026/9/8", end: "2027/6/8"}. Passing those
    // through as ISO makes every string comparison false, because '-' sorts before '/',
    // and every date in the year reads as outside the term. Caught by a smoke test against
    // real data on the first day of school, when the whole site said "no school".
    expect(toIsoTerm({ start: '2026/9/8', end: '2027/6/8' })).toEqual({
      start: '2026-09-08',
      end: '2027-06-08',
    });
  });

  it('is the identity on dates already in ISO', () => {
    expect(toIsoTerm({ start: '2026-09-08', end: '2027-06-08' })).toEqual({
      start: '2026-09-08',
      end: '2027-06-08',
    });
  });

  it('treats an unreadable or partial term as no term at all', () => {
    expect(toIsoTerm(null)).toBeNull();
    expect(toIsoTerm({ start: '2026/9/8' })).toBeNull();
    expect(toIsoTerm({ start: 'sometime', end: 'later' })).toBeNull();
  });

  it('puts the real school year around the real first day', () => {
    const year = input({ term: toIsoTerm({ start: '2026/9/8', end: '2027/6/8' }) });
    expect(resolveDay('2026-09-08', year).source).toBe('regular');
    expect(resolveDay('2026-09-07', year).source).toBe('outside-term');
    expect(resolveDay('2027-06-09', year).source).toBe('outside-term');
  });
});

describe('weekOf', () => {
  it('returns Monday through Friday of the containing week', () => {
    expect(weekOf('2026-09-08')).toEqual(['2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10', '2026-09-11']);
  });

  it('counts Sunday as the start of the coming week, not the end of the last', () => {
    expect(weekOf('2026-09-13')[0]).toBe('2026-09-14');
  });
});
