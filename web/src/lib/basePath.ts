/**
 * The one place the base path is written.
 *
 * This app is served at mikeveson.com/knight-life through a rewrite, so it carries a Next
 * `basePath`. Next prefixes what it controls: page routes, `next/link`, `next/image`, and
 * everything under `_next`. It does NOT prefix a raw `<img src>`, a plain `<a href>`, a
 * `fetch` to a string path, or `metadata.icons`. Those are the ones that break, and they
 * break only in production, because in development the prefix is in the URL you typed.
 *
 * That is exactly what happened on 2026-08-19: the masthead icon 404'd on the live site
 * while working locally, and the wordmark linked to the portfolio's homepage rather than
 * back to this tool.
 *
 * `next.config.ts` reads this too, so the value cannot drift between the framework's idea
 * of the prefix and the hand-written ones.
 */
export const BASE_PATH = '/knight-life';

/** A path under this app, prefixed. Use for anything Next does not prefix itself. */
export function asset(path: string): string {
  return `${BASE_PATH}${path.startsWith('/') ? path : `/${path}`}`;
}
