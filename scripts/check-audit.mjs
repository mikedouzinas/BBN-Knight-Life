// The dependency audit gate. HQ-1043.
//
// WHAT WAS WRONG WITH `npm audit --audit-level=moderate`.
//
// It fails on the CALENDAR, not on a diff. Nothing in this repository has to change for it to
// go red: somebody publishes an advisory against a dependency that was already there, and the
// next push fails on a tree that passed the day before. That happened between 2026-09-08 and
// 2026-09-10 and it blocked an unrelated ticket's merge.
//
// The vulnerability is not the damage. The damage is that everyone learns to merge past red,
// and then the gate is not a gate on the day an advisory actually matters. It is the mirror of
// a vacuous checker: that one examines nothing and always passes, this one examines something
// real but fires on something nobody did. Both end as a signal nobody reads.
//
// SO THIS GATE FIRES ON CHANGE INSTEAD.
//
// Every advisory currently outstanding is listed in scripts/audit-baseline.json with a date and
// a reason. A NEW advisory is not in that file, so it fails the build and someone has to look at
// it. A known, accepted one does not. Fixing a dependency and leaving its entry behind is
// reported, not fatal, because stale cruft should not block a merge.
//
// Usage: node scripts/check-audit.mjs <package-dir>
//
// FALSIFIED 2026-09-10, all four paths:
//   - injected a fake advisory id into the parsed set    -> "FAIL: 1 advisory not in the baseline", exit 1
//   - pointed it at a directory with no node_modules     -> "FAIL: audit examined 0 dependencies", exit 1
//   - fed it unparseable audit output                    -> "FAIL: could not parse npm audit output", exit 1
//   - added a baseline entry for an advisory not present -> reported as stale, exit 0

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const BASELINE = join(HERE, 'audit-baseline.json');

const pkgDir = process.argv[2];
if (!pkgDir) {
  console.error('Usage: node scripts/check-audit.mjs <package-dir>');
  process.exit(1);
}
const dir = resolve(pkgDir);
const key = pkgDir.replace(/^\.\//, '').replace(/\/$/, '');

// npm audit exits non-zero when it finds anything, which is the whole behaviour being replaced,
// so a non-zero exit here is expected and the output is what matters.
let raw;
try {
  raw = execFileSync('npm', ['audit', '--json'], { cwd: dir, encoding: 'utf8', maxBuffer: 32e6 });
} catch (err) {
  raw = err.stdout ?? '';
}

let report;
try {
  report = JSON.parse(raw);
} catch {
  console.error(`FAIL: could not parse npm audit output in ${key}/. Got ${raw.length} bytes.`);
  process.exit(1);
}

// The discovery check. An audit that resolved no dependencies examined nothing, and would
// report "no vulnerabilities" for exactly the same reason a broken install would.
const deps = report.metadata?.dependencies?.total ?? 0;
if (deps === 0) {
  console.error(
    `FAIL: audit examined 0 dependencies in ${key}/. That is a broken install, not a clean audit.`,
  );
  process.exit(1);
}

// Collect every distinct advisory id. npm nests them under each vulnerable package, and one
// advisory can appear under several, so this dedupes by id.
const found = new Map();
for (const vuln of Object.values(report.vulnerabilities ?? {})) {
  for (const via of vuln.via ?? []) {
    if (typeof via === 'object' && via.url) {
      const id = via.url.split('/').pop();
      if (id) found.set(id, { severity: via.severity ?? vuln.severity, title: via.title ?? '' });
    }
  }
}

let baseline = {};
try {
  baseline = JSON.parse(readFileSync(BASELINE, 'utf8'));
} catch {
  console.error(`FAIL: cannot read ${BASELINE}`);
  process.exit(1);
}
const accepted = baseline[key] ?? {};

console.log(`CHECKED ${deps} dependencies in ${key}/, ${found.size} advisory/advisories outstanding`);

const unaccepted = [...found.entries()].filter(([id]) => !(id in accepted));
const stale = Object.keys(accepted).filter((id) => !found.has(id));

for (const [id, info] of found) {
  const mark = id in accepted ? 'accepted' : 'NEW';
  console.log(`  ${mark.padEnd(8)} ${info.severity.padEnd(8)} ${id}  ${info.title}`);
}
if (stale.length) {
  console.log(
    `NOTE: ${stale.length} baseline entr${stale.length === 1 ? 'y is' : 'ies are'} no longer ` +
      `reported and can be deleted from audit-baseline.json: ${stale.join(', ')}`,
  );
}

if (unaccepted.length) {
  console.error(
    `\nFAIL: ${unaccepted.length} advisory/advisories not in the baseline.\n` +
      'Fix them, or if the exposure genuinely does not apply here, add each id to\n' +
      `scripts/audit-baseline.json under "${key}" with a date and a reason a person can check.`,
  );
  process.exit(1);
}

console.log(`OK: every outstanding advisory in ${key}/ is accounted for.`);
