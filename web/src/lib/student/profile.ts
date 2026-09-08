/**
 * One student's day.
 *
 * This is NOT `renderForAudience`. That function takes a single lunch wave for the whole
 * day, which is right for the admin preview, where a maintainer picks an audience and asks
 * "what does this look like". It is wrong for a real student, because the shipped app does
 * not have one wave per student.
 *
 * `Extensions.swift:checkFilter` (line 1055) reads `l-{lunchBlock}` off the user document,
 * where `lunchBlock` comes from the event being filtered. A student can be 1st lunch on the
 * day lunch splits D and 2nd lunch on the day it splits E. Collapsing that to one wave
 * shows roughly half of them the wrong lunch, and the wrong class during the split block,
 * on the days the two disagree.
 *
 * The three "show it anyway" defaults are ported exactly, and they all fail open:
 *   - no grade set        -> every grade-filtered group is shown
 *   - no wave for a block -> both waves are shown
 *   - "Not Set"           -> the same as unset, because that is the literal string the app
 *                            writes and it is not the same as an empty one
 */
import type { ScheduleDay, ScheduleEvent } from '@/lib/schedule/types';
import { audienceLabel, sortRows, type RenderedRow } from '@/lib/schedule/render';

export const BLOCK_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;
export type BlockLetter = (typeof BLOCK_LETTERS)[number];

/** The fields of `users/{uid}` this app reads. Everything else there is left alone. */
export interface StudentProfile {
  /** Class name per block letter. Empty string means "not set up yet". */
  classes: Partial<Record<BlockLetter, string>>;
  /** Room per block letter, when known. The app stores only `room-advisory` today. */
  rooms: Partial<Record<BlockLetter, string>>;
  advisoryRoom: string;
  /** "9".."12", "teacher", or null when unset. Lowercased on read. */
  grade: string | null;
  /** `l-a`..`l-g`, normalized to L1/L2/null. Null means unset, which shows both. */
  lunchByBlock: Partial<Record<string, 'L1' | 'L2' | null>>;
}

const UNSET = new Set(['', 'not set']);

/** "1st Lunch" -> L1. Anything unrecognised is null, which shows both waves. */
export function normalizeWave(raw: unknown): 'L1' | 'L2' | null {
  const v = (typeof raw === 'string' ? raw : '').trim().toLowerCase();
  if (UNSET.has(v)) return null;
  if (v.startsWith('1st')) return 'L1';
  if (v.startsWith('2nd')) return 'L2';
  return null;
}

export function profileFromUserDoc(data: Record<string, unknown> | undefined): StudentProfile {
  const d = data ?? {};
  const str = (k: string): string => (typeof d[k] === 'string' ? (d[k] as string).trim() : '');

  const classes: Partial<Record<BlockLetter, string>> = {};
  const rooms: Partial<Record<BlockLetter, string>> = {};
  const lunchByBlock: Partial<Record<string, 'L1' | 'L2' | null>> = {};
  for (const letter of BLOCK_LETTERS) {
    const name = str(letter);
    if (name) classes[letter] = name;
    const room = str(`room-${letter.toLowerCase()}`);
    if (room) rooms[letter] = room;
    lunchByBlock[letter.toLowerCase()] = normalizeWave(d[`l-${letter.toLowerCase()}`]);
  }

  const gradeRaw = str('grade').toLowerCase();
  return {
    classes,
    rooms,
    advisoryRoom: str('room-advisory'),
    grade: UNSET.has(gradeRaw) ? null : gradeRaw,
    lunchByBlock,
  };
}

/** True when this student has not set up any class yet. */
export function isEmptyProfile(profile: StudentProfile): boolean {
  return BLOCK_LETTERS.every((letter) => !profile.classes[letter]);
}

/** `checkFilter`, ported. One filter string against one student. */
function filterApplies(filter: string, group: ScheduleEvent, profile: StudentProfile): boolean {
  const f = filter.toLowerCase();

  if (f === 'l1' || f === 'l2') {
    // The wave is looked up by the block lunch splits, which lives on the group. When the
    // group does not say, no lookup is possible and the app shows the row.
    const lunchBlock = group.lunchBlock?.toLowerCase();
    if (!lunchBlock) return true;
    const wave = profile.lunchByBlock[lunchBlock] ?? null;
    if (wave === null) return true;
    return wave.toLowerCase() === f;
  }

  if (profile.grade === null) return true;
  return profile.grade === f;
}

function groupApplies(group: ScheduleEvent, profile: StudentProfile): boolean {
  const filters = group.filter ?? [];
  if (filters.length === 0) return true;
  const test = (f: string) => filterApplies(f, group, profile);
  return group.matchMode === 'all' ? filters.every(test) : filters.some(test);
}

export interface StudentRow extends RenderedRow {
  /** The student's own class name, when they have one for this block. */
  className?: string;
}

function leafRow(event: ScheduleEvent, label?: string): RenderedRow {
  const block = event.block && event.block.length === 1 ? event.block.toUpperCase() : null;
  return {
    name: event.type === 'lunch' ? 'Lunch' : event.name ?? block ?? '',
    block,
    startTime: event.startTime ?? '',
    endTime: event.endTime ?? '',
    ...(event.room ? { room: event.room } : {}),
    ...(label ? { audienceLabel: label } : {}),
  };
}

/** The day as this student sees it, with their own class names attached. */
export function renderForStudent(day: ScheduleDay, profile: StudentProfile): StudentRow[] {
  const rows: RenderedRow[] = [];
  for (const event of day.blocks ?? []) {
    if (event.type === 'specific') {
      if (!groupApplies(event, profile)) continue;
      const label = audienceLabel(event.filter ?? []);
      for (const child of event.contents ?? []) rows.push(leafRow(child, label));
    } else {
      rows.push(leafRow(event));
    }
  }

  return sortRows(rows).map((row) => {
    const letter = row.block as BlockLetter | null;
    if (!letter || !BLOCK_LETTERS.includes(letter)) return row;
    const className = profile.classes[letter];
    const room = row.room ?? profile.rooms[letter];
    return {
      ...row,
      ...(className ? { className } : {}),
      ...(room ? { room } : {}),
    };
  });
}

/** Which row is happening at `minutes` past midnight, and which is next. */
export function nowAndNext(
  rows: StudentRow[],
  minutes: number,
  parse: (t: string) => number | null,
): { current: StudentRow | null; next: StudentRow | null } {
  let current: StudentRow | null = null;
  let next: StudentRow | null = null;
  for (const row of rows) {
    const start = parse(row.startTime);
    const end = parse(row.endTime);
    if (start === null || end === null) continue;
    if (minutes >= start && minutes < end) current = current ?? row;
    else if (minutes < start && next === null) next = row;
  }
  return { current, next };
}
