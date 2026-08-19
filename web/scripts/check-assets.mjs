#!/usr/bin/env node
/**
 * Fetch a page and assert every asset it references actually resolves.
 *
 * This exists because of a bug that no unit test and no build could catch. The app carries a
 * Next `basePath`, and Next prefixes what it controls but not a raw `<img src>`, a plain
 * `<a href>`, or `metadata.icons`. On 2026-08-19 the masthead icon 404'd on the live site
 * while working perfectly in development, because in development the prefix is already in
 * the URL you typed. The build was green. The types were fine. The page was broken.
 *
 * Anything that references a URL the server will not serve is this same bug, so the check is
 * written against the class rather than against the icon.
 *
 *   node scripts/check-assets.mjs http://localhost:3000/knight-life/admin
 *
 * Exits non-zero on any reference that does not return 2xx.
 */

const pages = process.argv.slice(2);
if (pages.length === 0) {
  console.error('usage: check-assets.mjs <url> [url...]');
  process.exit(2);
}

/** Pull every URL the browser would go on to request. */
function references(html, pageUrl) {
  const found = new Set();
  const patterns = [
    /<(?:img|script)[^>]+src="([^"]+)"/g,
    /<link[^>]+href="([^"]+)"/g,
    /<a[^>]+href="([^"]+)"/g,
  ];
  for (const re of patterns) {
    for (const [, raw] of html.matchAll(re)) {
      // Skip things that are not a request to this origin.
      if (!raw || raw.startsWith('data:') || raw.startsWith('#') || raw.startsWith('mailto:')) continue;
      try {
        const url = new URL(raw, pageUrl);
        // External hosts are somebody else's uptime, not this app's correctness.
        if (url.origin !== new URL(pageUrl).origin) continue;
        found.add(url.toString());
      } catch {
        // An unparseable href is itself a defect worth surfacing.
        found.add(`UNPARSEABLE:${raw}`);
      }
    }
  }
  return [...found];
}

let failures = 0;
let checked = 0;

for (const page of pages) {
  const response = await fetch(page);
  if (!response.ok) {
    console.error(`FAIL  ${page} -> HTTP ${response.status}`);
    failures += 1;
    continue;
  }
  const html = await response.text();
  const refs = references(html, page);

  console.log(`\n${page}`);
  console.log(`  CHECKED ${refs.length} referenced URLs`);
  // A page that references nothing is a broken extraction, not a clean page. Every page in
  // this app loads at least a stylesheet.
  if (refs.length === 0) {
    console.error('  FAIL  extracted 0 references. That is a broken check, not a clean page.');
    failures += 1;
    continue;
  }

  for (const ref of refs) {
    checked += 1;
    if (ref.startsWith('UNPARSEABLE:')) {
      console.error(`  FAIL  ${ref}`);
      failures += 1;
      continue;
    }
    const assetResponse = await fetch(ref, { method: 'GET' });
    if (assetResponse.ok) {
      console.log(`  ok    ${assetResponse.status}  ${new URL(ref).pathname}`);
    } else {
      console.error(`  FAIL  ${assetResponse.status}  ${new URL(ref).pathname}`);
      failures += 1;
    }
  }
}

console.log(`\nCHECKED ${checked} URLs across ${pages.length} page(s)`);
if (failures > 0) {
  console.error(`RESULT: ${failures} unreachable reference(s)`);
  process.exit(1);
}
console.log('RESULT: every referenced URL resolves');
