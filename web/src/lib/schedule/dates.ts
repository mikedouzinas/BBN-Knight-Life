/**
 * Date keys. Three of them, and none may come from a locale-dependent formatter.
 *
 * `SecretSchedule.swift:147` sets `dateStyle = .full` to build the legacy document ID,
 * so on a non-US locale the app writes a key nothing else can find, and
 * `Extensions.swift:752` force-unwraps `firstIndex(of: ",")` on the same string, which
 * crashes on any locale that renders no comma. The month and weekday names below are
 * literals for exactly that reason: the key is data, not display text.
 */

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

export const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isValidIsoDate(iso: string): boolean {
  if (!ISO_DATE_RE.test(iso)) return false;
  const [y, m, d] = iso.split('-').map(Number);
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  const probe = new Date(Date.UTC(y, m - 1, d));
  return probe.getUTCFullYear() === y && probe.getUTCMonth() === m - 1 && probe.getUTCDate() === d;
}

function parts(iso: string): { y: number; m: number; d: number; weekday: number } {
  if (!isValidIsoDate(iso)) throw new Error(`not a valid YYYY-MM-DD date: ${iso}`);
  const [y, m, d] = iso.split('-').map(Number);
  return { y, m, d, weekday: new Date(Date.UTC(y, m - 1, d)).getUTCDay() };
}

/** The canonical store's field key: `2024/9/4`. yyyy/M/d, not zero-padded. */
export function toCanonicalKey(iso: string): string {
  const { y, m, d } = parts(iso);
  return `${y}/${m}/${d}`;
}

/** The legacy store's document ID: `Wednesday, September 4, 2024`. */
export function toLegacyKey(iso: string): string {
  const { y, m, d, weekday } = parts(iso);
  return `${WEEKDAYS[weekday]}, ${MONTHS[m - 1]} ${d}, ${y}`;
}

/** HQ-644: Saturday or Sunday, computed the same UTC-safe way toLegacyKey already does. */
export function isWeekend(iso: string): boolean {
  const { weekday } = parts(iso);
  return weekday === 0 || weekday === 6;
}

/**
 * The break document's field key: `2026/12/19-2027/1/3`.
 *
 * Two canonical keys joined by a hyphen, which works only because `yyyy/M/d` contains no
 * hyphen of its own. The shipped 2.4.1 app splits this key on "-" and indexes `[1]` without
 * checking, so a key with any other number of hyphens is an index-out-of-range crash on
 * launch for every student.
 */
export function toBreakKey(startIso: string, endIso: string): string {
  const key = `${toCanonicalKey(startIso)}-${toCanonicalKey(endIso)}`;
  // Belt and braces. If this ever fires, the canonical key format changed and the shipped
  // app cannot read what we are about to write.
  if (key.split('-').length !== 2) {
    throw new Error(`break key must contain exactly one hyphen: ${key}`);
  }
  return key;
}

/**
 * The LEGACY through-date document id: `Monday, June 15, 2026-Monday, September 7, 2026`.
 *
 * Two full date strings joined by a hyphen, which is what the shipped 2.4.1 app looks for when
 * it works out NOTIFICATIONS. That build resolves alerts through `getScheduleFor`, which scans
 * `special-schedules` for an id whose two halves bracket the date. It does NOT read
 * `schedules/break`, so writing only the modern span fixes the calendar and leaves the alarms
 * firing.
 *
 * Found on 2026-08-19 the hard way: the calendar correctly said "No Class - Summer break" for
 * every student while 2.4.1 was still scheduling class notifications through August, because
 * the last summer through-date anyone wrote was June 2025.
 */
export function toLegacyBreakId(startIso: string, endIso: string): string {
  return `${toLegacyKey(startIso)}-${toLegacyKey(endIso)}`;
}

/** `2026/12/19-2027/1/3` back to a pair of ISO dates. */
export function fromBreakKey(key: string): { start: string; end: string } {
  const parts = key.split('-');
  if (parts.length !== 2) throw new Error(`not a break key: ${key}`);
  return { start: fromCanonicalKey(parts[0]), end: fromCanonicalKey(parts[1]) };
}

/**
 * Inclusive day count between two ISO dates, so a range can say how long it is.
 *
 * Built through `parts`, which validates and returns real components, rather than by
 * spreading the split string into `Date.UTC`. That shortcut is off by one on the month and
 * silently wrong: it type-checks, and the error only shows as a range that reports the wrong
 * length. UTC throughout, because a local-time midnight crosses a DST boundary twice a year
 * and turns an exact day count into 20.958333.
 */
export function daysBetween(startIso: string, endIso: string): number {
  const a = parts(startIso);
  const b = parts(endIso);
  const start = Date.UTC(a.y, a.m - 1, a.d);
  const end = Date.UTC(b.y, b.m - 1, b.d);
  return Math.round((end - start) / 86_400_000) + 1;
}

/** `2024/9/4` back to `2024-09-04`. */
export function fromCanonicalKey(key: string): string {
  const m = /^(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(key);
  if (!m) throw new Error(`not a canonical schedule key: ${key}`);
  return `${m[1]}-${m[2].padStart(2, '0')}-${m[3].padStart(2, '0')}`;
}

/** "Wednesday, September 4, 2024" for display. Same builder, so it cannot drift. */
export function displayDate(iso: string): string {
  return toLegacyKey(iso);
}
