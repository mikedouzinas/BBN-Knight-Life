/**
 * What kind of day is it, for one date.
 *
 * The shipped app answers this across three places: `AuthVC.updateSpecialSchedules` reads
 * the special days and the breaks, `Extensions.swift` falls back to the weekly pattern,
 * and `Term` decides whether the date is inside the school year at all. This is that
 * decision in one pure function, so the web can answer it without a second data layer and
 * so the answer can be tested against dates that have already caused trouble.
 *
 * Order matters and is not arbitrary:
 *
 *   1. Outside the term        -> nothing to show. The app must not claim a summer
 *                                 Tuesday is a school day (HQ-928).
 *   2. Inside a break span     -> no school, named by the break.
 *   3. A published special day -> that day, exactly as published. A special day inside a
 *                                 break is still a break, because breaks are authored as
 *                                 spans and a stale day document must not reopen school.
 *   4. A weekday               -> the regular weekly pattern.
 *   5. A weekend               -> no school.
 *
 * Breaks beat special days on purpose. `schedules/special` holds 90 day documents going
 * back two years and nothing prunes them; a break is the more recent and more deliberate
 * statement about a date.
 */
import { ISO_DATE_RE, fromBreakKey, fromCanonicalKey, toCanonicalKey } from './dates';
import type { ScheduleDay } from './types';

export const WEEKDAY_IDS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'] as const;
export type WeekdayId = (typeof WEEKDAY_IDS)[number];

/** Every span in `schedules/break`, as ISO pairs. */
export interface BreakSpan {
  start: string;
  end: string;
  /** Whatever the break document said, e.g. "Winter Break". Empty when it said nothing. */
  reason: string;
}

export interface SchoolYearInput {
  /** `schedules/special`, already keyed by ISO date. */
  specialDays: Record<string, ScheduleDay>;
  /** `schedules/regular`, keyed by lowercase weekday name. */
  regularWeek: Partial<Record<WeekdayId, ScheduleDay['blocks']>>;
  breaks: BreakSpan[];
  /** The school year, inclusive. Null means unknown, and unknown never blocks a day. */
  term: { start: string; end: string } | null;
}

export type DaySource = 'special' | 'regular' | 'break' | 'weekend' | 'outside-term';

export interface ResolvedDay {
  date: string;
  day: ScheduleDay;
  source: DaySource;
  /** Set when the day is closed, so the page can say why rather than showing nothing. */
  reason?: string;
}

/** UTC-safe weekday for an ISO date. Local time crosses DST and lands on the wrong day. */
export function weekdayOf(iso: string): WeekdayId {
  const [y, m, d] = iso.split('-').map(Number);
  return WEEKDAY_IDS[new Date(Date.UTC(y, m - 1, d)).getUTCDay()];
}

/** ISO dates compare correctly as strings. Zero-padded, fixed width, no timezone. */
function within(iso: string, start: string, end: string): boolean {
  return iso >= start && iso <= end;
}

/**
 * Parse `schedules/break` into spans.
 *
 * A malformed key is skipped rather than thrown, because one bad key must not close the
 * whole school. `fromBreakKey` already refuses anything that is not exactly two canonical
 * keys joined by one hyphen.
 */
export function parseBreaks(raw: Record<string, { reason?: string } | undefined>): BreakSpan[] {
  const spans: BreakSpan[] = [];
  for (const [key, value] of Object.entries(raw ?? {})) {
    try {
      const { start, end } = fromBreakKey(key);
      spans.push({ start, end, reason: value?.reason ?? '' });
    } catch {
      continue;
    }
  }
  return spans;
}

/**
 * `schedules/term` writes its dates as canonical keys (`2026/9/8`), not ISO.
 *
 * This is not cosmetic and it fails silently in the worst possible direction. Day
 * resolution compares ISO dates as strings, which is valid only when both sides are ISO.
 * `'-'` (0x2D) sorts before `'/'` (0x2F), so `'2026-09-08' >= '2026/9/8'` is false and
 * EVERY date reads as outside the school year: 640 students told there is no school, on
 * the first day of school, by a document that was perfectly correct.
 *
 * Both formats are accepted because the document is hand-edited and the next person to
 * touch it may reasonably write either one.
 */
export function toIsoTerm(
  raw: { start?: string; end?: string } | null,
): { start: string; end: string } | null {
  if (!raw?.start || !raw?.end) return null;
  const iso = (value: string): string | null => {
    if (ISO_DATE_RE.test(value)) return value;
    try {
      return fromCanonicalKey(value);
    } catch {
      return null;
    }
  };
  const start = iso(raw.start);
  const end = iso(raw.end);
  // An unreadable term is the same as no term: unknown, and unknown never closes a day.
  return start && end ? { start, end } : null;
}

const CLOSED: ScheduleDay = { type: 'noschool', blocks: [] };

export function resolveDay(iso: string, input: SchoolYearInput): ResolvedDay {
  const { term, breaks, specialDays, regularWeek } = input;

  if (term && !within(iso, term.start, term.end)) {
    return { date: iso, day: CLOSED, source: 'outside-term', reason: 'Outside the school year' };
  }

  const hit = breaks.find((span) => within(iso, span.start, span.end));
  if (hit) {
    return { date: iso, day: { ...CLOSED, reason: hit.reason }, source: 'break', reason: hit.reason || 'Break' };
  }

  const special = specialDays[iso];
  if (special) {
    return {
      date: iso,
      day: special,
      source: 'special',
      ...(special.type === 'noschool' ? { reason: special.reason || 'No school' } : {}),
    };
  }

  const weekday = weekdayOf(iso);
  if (weekday === 'saturday' || weekday === 'sunday') {
    return { date: iso, day: CLOSED, source: 'weekend', reason: 'Weekend' };
  }

  const blocks = regularWeek[weekday];
  if (!blocks || blocks.length === 0) {
    return { date: iso, day: CLOSED, source: 'regular', reason: 'No schedule published for this day' };
  }
  return { date: iso, day: { type: 'blocks', blocks }, source: 'regular' };
}

/** `schedules/special` keyed by `2026/9/8` re-keyed to ISO, skipping anything unreadable. */
export function specialDaysByIso(raw: Record<string, unknown>): Record<string, ScheduleDay> {
  const out: Record<string, ScheduleDay> = {};
  for (const [key, value] of Object.entries(raw ?? {})) {
    if (!value || typeof value !== 'object') continue;
    // Round-trip through the canonical key rather than parsing by hand, so this agrees
    // with how the admin tool writes it by construction.
    const m = /^(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(key);
    if (!m) continue;
    const iso = `${m[1]}-${m[2].padStart(2, '0')}-${m[3].padStart(2, '0')}`;
    if (toCanonicalKey(iso) !== key) continue;
    out[iso] = value as ScheduleDay;
  }
  return out;
}

/** The five weekdays of the week containing `iso`, Monday first. */
export function weekOf(iso: string): string[] {
  const [y, m, d] = iso.split('-').map(Number);
  const base = Date.UTC(y, m - 1, d);
  const dow = new Date(base).getUTCDay();
  // Sunday (0) belongs to the week that is about to start, not the one that just ended.
  const offsetToMonday = dow === 0 ? 1 : 1 - dow;
  return Array.from({ length: 5 }, (_, i) => {
    const t = new Date(base + (offsetToMonday + i) * 86_400_000);
    return t.toISOString().slice(0, 10);
  });
}
