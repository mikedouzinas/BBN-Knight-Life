/**
 * Time strings, and why there are two formats.
 *
 * The canonical store holds "8:15 am". The legacy store is read by
 * `String.dateFromMultipleFormats()` (Extensions.swift:228), whose 12-hour formats are
 * exactly "hh:mma" and "hh:mm" with `en_US_POSIX` and amSymbol "am". A space before the
 * meridiem does not parse, and a failed parse silently becomes `Date()`, which is a notification
 * fired at the wrong time with no error anywhere. So the legacy projection zero-pads and
 * drops the space: "08:15am".
 *
 * Production strings are hand-entered and inconsistent ("8:15 am", "08:15am", "01:00 pm",
 * and some with U+202F narrow no-break spaces). `normalizeTime12` is the funnel: every
 * time entering the system goes through it, so neither format is ever written by hand.
 */

const TIME_RE = /^(\d{1,2}):(\d{2})\s*([ap])\.?m\.?$/i;

/** Minutes since midnight, or null if the string is not a time we accept. */
export function parseTime12(raw: string): number | null {
  if (typeof raw !== 'string') return null;
  // U+00A0 no-break space, U+202F narrow no-break space, U+2009 thin space.
  const cleaned = raw.replace(/[   ]/g, ' ').trim();
  const m = TIME_RE.exec(cleaned);
  if (!m) return null;
  const hour12 = Number(m[1]);
  const minute = Number(m[2]);
  if (hour12 < 1 || hour12 > 12 || minute > 59) return null;
  const pm = m[3].toLowerCase() === 'p';
  const hour24 = hour12 === 12 ? (pm ? 12 : 0) : pm ? hour12 + 12 : hour12;
  return hour24 * 60 + minute;
}

function split(minutes: number): { hour12: number; minute: number; meridiem: 'am' | 'pm' } {
  const hour24 = Math.floor(minutes / 60);
  const minute = minutes % 60;
  const meridiem = hour24 >= 12 ? 'pm' : 'am';
  const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;
  return { hour12, minute, meridiem };
}

/** Canonical store format: "8:15 am". */
export function formatCanonical(minutes: number): string {
  const { hour12, minute, meridiem } = split(minutes);
  return `${hour12}:${String(minute).padStart(2, '0')} ${meridiem}`;
}

/** Legacy store format: "08:15am". Zero-padded, no space. The only shape 2.4.1 parses. */
export function formatLegacy(minutes: number): string {
  const { hour12, minute, meridiem } = split(minutes);
  return `${String(hour12).padStart(2, '0')}:${String(minute).padStart(2, '0')}${meridiem}`;
}

/** Any accepted spelling to the canonical one. Returns null when it is not a time. */
export function normalizeTime12(raw: string): string | null {
  const minutes = parseTime12(raw);
  return minutes === null ? null : formatCanonical(minutes);
}

/** Any accepted spelling to the legacy one. Returns null when it is not a time. */
export function toLegacyTime(raw: string): string | null {
  const minutes = parseTime12(raw);
  return minutes === null ? null : formatLegacy(minutes);
}
