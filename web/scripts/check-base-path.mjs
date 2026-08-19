#!/usr/bin/env node
/**
 * Fail on any root-relative URL this app writes by hand without the base path.
 *
 * The app is served under `/knight-life`. Next prefixes what it controls -- routes,
 * next/link, next/image, `_next` -- and nothing else. A hand-written `/...` string is
 * therefore a request to whatever else lives at the origin, which here is the portfolio.
 *
 * This has now happened twice in one day, in two different disguises:
 *   - `<img src="/knight-life-icon.png">`, which 404'd and showed no icon.
 *   - `fetch('/api/admin/session')`, which 404'd immediately after a successful Google
 *     sign-in and looked like a broken login.
 *
 * check-assets.mjs catches the first kind, because those URLs appear in the served HTML.
 * It cannot catch the second: a fetch happens later, from JavaScript, in response to a user
 * action, and nothing about the page's markup reveals it. So this reads the source instead.
 *
 * A comment or a doc string mentioning the pattern is not a violation; only real code is.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = new URL('../src', import.meta.url).pathname;

/** Strip // line comments, block comments, and JSX comments before matching. */
function withoutComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/^\s*\*.*$/gm, '');
}

/**
 * Only LOWERCASE tags are violations. `next/link` and `next/image` apply the base path
 * themselves, so `<Link href="/admin">` is correct and wrapping it would double the prefix
 * and produce /knight-life/knight-life/admin. The first version of this check flagged three
 * such Links; treating those as bugs would have broken every internal link in the app.
 *
 * So the attribute rules match `<a`, `<img`, `<form` and `<script` specifically, rather than
 * matching an attribute anywhere.
 */
const PATTERNS = [
  { re: /\bfetch\(\s*['"`]\//g, what: "fetch() with a root-relative path" },
  { re: /<a\s[^>]*\bhref\s*=\s*["']\/(?!\/)/g, what: "a plain <a href> with a root-relative path" },
  { re: /<img\s[^>]*\bsrc\s*=\s*["']\/(?!\/)/g, what: "a plain <img src> with a root-relative path" },
  { re: /<(?:form|script)\s[^>]*\b(?:action|src)\s*=\s*["']\/(?!\/)/g, what: "a root-relative form action or script src" },
  { re: /\bingestUrl\s*:\s*['"`]\//g, what: "a root-relative API url" },
];

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else if (/\.(ts|tsx|js|jsx)$/.test(entry) && !/\.test\./.test(entry)) out.push(full);
  }
  return out;
}

const files = walk(ROOT);
console.log(`CHECKED ${files.length} source files under src/`);
if (files.length === 0) {
  console.error('FAIL: found no source files. That is a broken walk, not a clean result.');
  process.exit(1);
}

let violations = 0;
for (const file of files) {
  const source = withoutComments(readFileSync(file, 'utf8'));
  const lines = source.split('\n');
  for (const { re, what } of PATTERNS) {
    for (const match of source.matchAll(re)) {
      const line = source.slice(0, match.index).split('\n').length;
      console.error(`FAIL  ${file.replace(ROOT, 'src')}:${line}  ${what}`);
      console.error(`      ${lines[line - 1]?.trim()}`);
      console.error('      Wrap it in withBasePath() from @/lib/basePath.');
      violations += 1;
    }
  }
}

if (violations > 0) {
  console.error(`\nRESULT: ${violations} unprefixed root-relative URL(s)`);
  process.exit(1);
}
console.log('RESULT: every hand-written URL carries the base path');
