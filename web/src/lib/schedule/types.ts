/**
 * The CURRENT live schedule shape, verified against production on 2026-08-19.
 *
 * This is deliberately not the ISO-keyed schema in design doc section 3. That schema
 * is HQ-603 and does not exist yet. Everything here describes what the shipped 2.4.1
 * app actually reads, so that publishing from this tool is a no-op for students.
 *
 * Canonical store: `schedules/special`, one document whose ~79 FIELDS are days keyed
 * `2024/10/11` (yyyy/M/d, not zero-padded).
 * Legacy store: `special-schedules`, one document per day keyed by a full date string.
 * The legacy store is DERIVED, never authored. See derive.ts.
 */

/** Times as the canonical store holds them: 12-hour, lowercase meridiem, e.g. "8:15 am". */
export type Time12 = string;

export type EventType = 'block' | 'lunch' | 'specific';

/** The letter blocks a class can sit in, plus the two non-class values in production. */
export const BLOCK_VALUES = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'advisory', 'lunch', 'other'] as const;
export type BlockValue = (typeof BLOCK_VALUES)[number];

/** Every filter value present in production. Grades, faculty, and the two lunch waves. */
export const FILTER_VALUES = ['9', '10', '11', '12', 'teacher', 'L1', 'L2'] as const;
export type FilterValue = (typeof FILTER_VALUES)[number];

export interface ScheduleEvent {
  type: EventType;
  /** Present on `block`. Which letter block, or `other` / `advisory` for non-class time. */
  block?: string;
  /** Present on `block`. The label a student sees, e.g. "Extended B". */
  name?: string;
  startTime?: Time12;
  endTime?: Time12;
  /** Rare, two events in production carry it. Passed through untouched. */
  room?: string;
  /** Present on `specific`. Who the contents apply to. */
  filter?: string[];
  /** Present on `specific`. Production only ever uses "any". */
  matchMode?: 'any' | 'all';
  /** Present on `specific` when the filter is a lunch wave: which block lunch splits. */
  lunchBlock?: string;
  /** Present on `specific`. Production nests exactly one level deep. */
  contents?: ScheduleEvent[];
}

export interface ScheduleDay {
  type: 'blocks' | 'noschool' | 'image';
  /** "Snow day", "Labor Day". Empty string when there is nothing to say. */
  reason?: string;
  imageUrl?: string;
  blocks?: ScheduleEvent[];
}

/** One published day: an ISO date plus the day itself. ISO is the tool's internal key. */
export interface DatedScheduleDay {
  /** YYYY-MM-DD. Zero-padded, sortable, locale-free. */
  date: string;
  day: ScheduleDay;
}

/** A row in a legacy `special-schedules` document. Every value is a string. */
export interface LegacyBlock {
  name: string;
  /** "A".."G" for a letter block, "N/A" for everything else. */
  block: string;
  /** 12-hour, zero-padded, no space: "08:15am". See time.ts for why. */
  startTime: string;
  endTime: string;
}

export interface LegacyDayDoc {
  date: string;
  reason: string;
  imageUrl: string;
  /** The second lunch wave. This is what `blocks` means in the shipped app. */
  blocks: LegacyBlock[];
  /** The first lunch wave. */
  'blocks-l1': LegacyBlock[];
}
