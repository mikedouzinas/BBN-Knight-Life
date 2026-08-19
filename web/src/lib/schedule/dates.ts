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
