/**
 * The student-facing render, reimplemented from the shipped app so the confirmation
 * screen shows what a student will actually see.
 *
 * Traced from `Extensions.swift`: `getNextBlock` (line 878) flattens events, and
 * `checkFilter` (line 924) decides who sees a `specific` group. Two rules from there
 * matter and are kept exactly:
 *   - A student with no grade set sees every grade-filtered group ("show it to them
 *     just in case").
 *   - A student with no lunch wave set sees both waves.
 * Both mean the safe default in this preview is "show more", never "hide".
 */
import type { ScheduleDay, ScheduleEvent } from './types';
import { parseTime12 } from './time';

export type Grade = '9' | '10' | '11' | '12' | 'teacher';
export type LunchWave = 'L1' | 'L2';

export interface Audience {
  /** null means "no grade set", which in the app shows everything. */
  grade: Grade | null;
  /** null means "no lunch wave set", which in the app shows both waves. */
  lunchWave: LunchWave | null;
}

export interface RenderedRow {
  name: string;
  /** "A".."G" when it is a letter block, null otherwise. */
  block: string | null;
  startTime: string;
  endTime: string;
  room?: string;
  /** Set when the row came out of a `specific` group, so the preview can label it. */
  audienceLabel?: string;
}

/** `checkFilter`, ported. `matchMode` is "any" in all production data. */
function groupApplies(group: ScheduleEvent, audience: Audience): boolean {
  const filters = group.filter ?? [];
  const matches = (filter: string): boolean => {
    if (filter === 'L1' || filter === 'L2') {
      return audience.lunchWave === null || audience.lunchWave === filter;
    }
    return audience.grade === null || audience.grade === filter;
  };
  return group.matchMode === 'all' ? filters.every(matches) : filters.some(matches);
}

/** Human label for who a group is for: "Gr. 10-12", "Faculty", "1st lunch". */
export function audienceLabel(filter: string[]): string {
  const waves = filter.filter((f) => f === 'L1' || f === 'L2');
  if (waves.length) return waves.includes('L1') ? '1st lunch' : '2nd lunch';

  const grades = filter
    .filter((f) => /^\d+$/.test(f))
    .map(Number)
    .sort((a, b) => a - b);
  const hasTeacher = filter.includes('teacher');
  if (!grades.length) return hasTeacher ? 'Faculty' : filter.join(', ');
  if (grades.length === 4) return 'All grades';

  const runs: string[] = [];
  let start = grades[0];
  let prev = grades[0];
  for (const g of grades.slice(1)) {
    if (g === prev + 1) { prev = g; continue; }
    runs.push(start === prev ? `${start}` : `${start}-${prev}`);
    start = g;
    prev = g;
  }
  runs.push(start === prev ? `${start}` : `${start}-${prev}`);
  return `Gr. ${runs.join('/')}`;
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

/** Sort by start time, keeping the authored order for rows that start together. */
export function sortRows<T extends { startTime: string }>(rows: T[]): T[] {
  return rows
    .map((row, index) => ({ row, index, minutes: parseTime12(row.startTime) ?? Number.MAX_SAFE_INTEGER }))
    .sort((a, b) => (a.minutes === b.minutes ? a.index - b.index : a.minutes - b.minutes))
    .map((entry) => entry.row);
}

/** The day as one audience sees it. */
export function renderForAudience(day: ScheduleDay, audience: Audience): RenderedRow[] {
  const rows: RenderedRow[] = [];
  for (const event of day.blocks ?? []) {
    if (event.type === 'specific') {
      if (!groupApplies(event, audience)) continue;
      const label = audienceLabel(event.filter ?? []);
      for (const child of event.contents ?? []) rows.push(leafRow(child, label));
    } else {
      rows.push(leafRow(event));
    }
  }
  return sortRows(rows);
}
