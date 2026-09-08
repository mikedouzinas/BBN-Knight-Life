/**
 * The student's classes as a calendar file.
 *
 * **Concrete events, not RRULE, and that is the whole design.** A recurrence rule needs a
 * pattern to repeat, and this schedule does not have one: the day a block meets comes from
 * a rotating weekly pattern that special days override 90 times a year, breaks close for
 * weeks at a time, and lunch splits a different block on different days. Expressing that as
 * RRULE plus EXDATE means encoding every one of those exceptions correctly and re-encoding
 * them whenever an admin publishes a change.
 *
 * Expanding the real schedule day by day removes that entire class of bug. Each event is
 * the block as this student will actually see it, on a date the schedule says it happens.
 * The cost is file size, which for a school year is a few hundred kilobytes, and staleness:
 * a schedule published after the download is not in the file. That is a real limit and the
 * page says so rather than pretending the export is live.
 *
 * HQ-949 does the same job through EventKit on the phone. It should import this module for
 * the expansion and keep only the writing part native, so the two surfaces cannot disagree
 * about which days a class meets.
 */
import { parseTime12 } from '@/lib/schedule/time';
import { resolveDay, type SchoolYearInput } from '@/lib/schedule/schoolDay';
import { renderForStudent, type StudentProfile, type StudentRow } from './profile';

const PRODID = '-//Knight Life//Schedule Export//EN';

/** RFC 5545 escaping. Order matters: backslash first, or the others get double-escaped. */
function escapeText(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
}

/**
 * Fold to 75 octets per RFC 5545. Measured in BYTES, not characters: a class name with an
 * accent or an em dash in it is multi-byte, and folding by character length produces a line
 * that some parsers reject.
 */
function fold(line: string): string {
  const bytes = Buffer.from(line, 'utf8');
  if (bytes.length <= 75) return line;
  const out: string[] = [];
  let start = 0;
  let limit = 75;
  while (start < bytes.length) {
    let end = Math.min(start + limit, bytes.length);
    // Never split a UTF-8 sequence: back up off any continuation byte.
    while (end > start && end < bytes.length && (bytes[end] & 0xc0) === 0x80) end--;
    out.push((out.length ? ' ' : '') + bytes.subarray(start, end).toString('utf8'));
    start = end;
    limit = 74;
  }
  return out.join('\r\n');
}

/** `2026-09-08` + 495 minutes -> `20260908T081500`, floating local time. */
function stamp(iso: string, minutes: number): string {
  const [y, m, d] = iso.split('-');
  const hh = String(Math.floor(minutes / 60)).padStart(2, '0');
  const mm = String(minutes % 60).padStart(2, '0');
  return `${y}${m}${d}T${hh}${mm}00`;
}

export interface IcsOptions {
  /** Inclusive ISO range to expand. */
  from: string;
  to: string;
  /** Only these blocks. Default: every row that is a lettered block the student has. */
  includeUnnamedBlocks?: boolean;
  /** Stable per-export, so re-importing replaces rather than duplicates. */
  uidNamespace?: string;
  now?: Date;
}

function eachDay(from: string, to: string): string[] {
  const out: string[] = [];
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  for (let t = start; t <= end; t += 86_400_000) out.push(new Date(t).toISOString().slice(0, 10));
  return out;
}

function summaryFor(row: StudentRow): string {
  if (row.className) return row.block ? `${row.className} (${row.block})` : row.className;
  return row.name || row.block || 'Class';
}

export function buildIcs(
  year: SchoolYearInput,
  profile: StudentProfile,
  options: IcsOptions,
): { text: string; events: number } {
  const namespace = options.uidNamespace ?? 'knightlife';
  const dtstamp = (options.now ?? new Date()).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');

  const lines: string[] = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    `PRODID:${PRODID}`,
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Knight Life',
  ];

  let events = 0;
  for (const iso of eachDay(options.from, options.to)) {
    const resolved = resolveDay(iso, year);
    if (resolved.day.type !== 'blocks') continue;

    for (const row of renderForStudent(resolved.day, profile)) {
      const start = parseTime12(row.startTime);
      const end = parseTime12(row.endTime);
      if (start === null || end === null || end <= start) continue;

      // A lettered block the student never named is "B" and nothing else. Exporting it
      // fills a calendar with single letters, so it is off unless asked for.
      const named = Boolean(row.className);
      const isLetterBlock = Boolean(row.block);
      if (isLetterBlock && !named && !options.includeUnnamedBlocks) continue;

      const uid = `${namespace}-${iso}-${row.block ?? row.name}-${start}@knightlife`;
      const description = [row.audienceLabel, row.block ? `Block ${row.block}` : null]
        .filter(Boolean)
        .join(' · ');

      lines.push(
        'BEGIN:VEVENT',
        fold(`UID:${escapeText(uid)}`),
        `DTSTAMP:${dtstamp}`,
        `DTSTART:${stamp(iso, start)}`,
        `DTEND:${stamp(iso, end)}`,
        fold(`SUMMARY:${escapeText(summaryFor(row))}`),
        ...(row.room ? [fold(`LOCATION:${escapeText(row.room)}`)] : []),
        ...(description ? [fold(`DESCRIPTION:${escapeText(description)}`)] : []),
        'END:VEVENT',
      );
      events++;
    }
  }

  lines.push('END:VCALENDAR');
  return { text: lines.join('\r\n') + '\r\n', events };
}
