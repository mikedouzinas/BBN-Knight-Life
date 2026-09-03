/**
 * Run every real schedule in a folder through the actual scan pipeline and print what came back.
 *
 * WHY THIS EXISTS
 *
 * Until 2026-09-03 exactly ONE sheet had ever been through this feature, and it was the sheet the
 * prompt was written against. That is the worst possible evidence: it cannot distinguish "the
 * prompt reads BB&N schedules" from "the prompt reads this schedule". School starts Tuesday for
 * ~645 students, each with a different sheet.
 *
 * Tapping through scans on a phone is the wrong instrument for this. It costs one of five scans
 * per attempt, it tests the UI rather than the reading, and it gives you one sheet at a time with
 * no way to compare. This calls `extractStudentClasses` directly, which is the same function the
 * route calls, so what it prints is exactly what a student's phone would receive.
 *
 * USAGE
 *
 *   ANTHROPIC_API_KEY=... npx tsx --conditions=react-server scripts/scan-sheets.mts <folder>
 *
 * `--conditions=react-server` is REQUIRED and is not optional tidiness. `extractStudentClasses`
 * begins with `import 'server-only'`, whose default export throws on purpose to stop server code
 * being pulled into a client bundle. That condition resolves the same package to its empty build
 * instead, which is exactly what `vitest.config.ts` does with an alias for the test suite. Without
 * it the script dies inside the import, before any of its own checks run, with a stack trace
 * pointing at extractStudentClasses.ts:19 rather than at anything you did wrong.
 *
 * Optional: `--json out.json` for the full result of every sheet.
 *
 * Takes .pdf, .png, .jpg, .jpeg, .heic. Costs roughly $0.06 per sheet on Opus 5.
 *
 * FALSIFIED 2026-09-03: pointed at an empty folder and it refused rather than reporting a clean
 * run -- "No .pdf/.png/.jpg/.jpeg/.heic files in <dir>. That is a broken discovery step, not a
 * pass." A batch checker that examines nothing must never look like a pass.
 *
 * PRIVACY: point it at a folder OUTSIDE this repository. These are identifiable students'
 * timetables and this repo is public. Nothing here writes into the repo unless --json says so.
 */
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { extractStudentClasses } from '../src/lib/ingest/extractStudentClasses';

const MEDIA: Record<string, string> = {
  '.pdf': 'application/pdf',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.heic': 'image/heic',
};

const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'] as const;
const BLOCKS = ['a', 'b', 'c', 'd', 'e', 'f', 'g'] as const;

function fail(msg: string): never {
  console.error(`\n${msg}\n`);
  process.exit(1);
}

const args = process.argv.slice(2);
const folder = args.find((a) => !a.startsWith('--'));
if (!folder) fail('Usage: npx tsx scripts/scan-sheets.mts <folder> [--json out.json]');
if (!process.env.ANTHROPIC_API_KEY) fail('ANTHROPIC_API_KEY is not set. This makes real model calls.');

const jsonFlag = args.indexOf('--json');
const jsonOut = jsonFlag >= 0 ? args[jsonFlag + 1] : undefined;

const dir = resolve(folder);
const files = readdirSync(dir)
  .filter((f) => MEDIA[extname(f).toLowerCase()])
  .sort();

// A run over zero sheets must not look like a clean run. Same reason every checker in this repo
// refuses to print a tick without saying what it examined.
if (files.length === 0) {
  fail(`No .pdf/.png/.jpg/.jpeg/.heic files in ${dir}. That is a broken discovery step, not a pass.`);
}

console.log(`\nCHECKING ${files.length} sheet(s) in ${dir}\n`);

interface Row {
  file: string;
  ok: boolean;
  blocks: string;
  missingBlocks: string[];
  courses: number;
  frees: number;
  grade: string | null;
  lunchMissing: string[];
  lunch: Record<string, number | undefined>;
  skipped: { block: string; subject: string }[];
  rejected: number;
  attempts: number;
  seconds: number;
  message: string;
  classes: { block: string; subject: string; teacher?: string; room?: string }[];
  error?: string;
}

const rows: Row[] = [];

for (const file of files) {
  const path = join(dir, file);
  const started = Date.now();
  process.stdout.write(`  ${file} ... `);

  try {
    const result = await extractStudentClasses({
      attachments: [
        { mediaType: MEDIA[extname(file).toLowerCase()] as never, data: readFileSync(path).toString('base64') },
      ],
    });

    const found = new Set(result.classes.map((c) => c.block.toLowerCase()));
    const isFree = (s: string) => s.trim().toLowerCase() === 'free';

    const row: Row = {
      file,
      ok: true,
      blocks: BLOCKS.map((b) => (found.has(b) ? b.toUpperCase() : '·')).join(''),
      missingBlocks: BLOCKS.filter((b) => !found.has(b)).map((b) => b.toUpperCase()),
      courses: result.classes.filter((c) => !isFree(c.subject)).length,
      frees: result.classes.filter((c) => isFree(c.subject)).length,
      grade: result.details.grade ?? null,
      lunchMissing: WEEKDAYS.filter((d) => result.lunch[d] !== 1 && result.lunch[d] !== 2),
      lunch: Object.fromEntries(WEEKDAYS.map((d) => [d, result.lunch[d]])),
      skipped: result.skipped,
      rejected: result.rejected.length,
      attempts: result.attempts,
      seconds: Math.round((Date.now() - started) / 100) / 10,
      message: (result.message ?? '').trim(),
      classes: result.classes.map((c) => ({ block: c.block.toUpperCase(), subject: c.subject, teacher: c.teacher, room: c.room })),
    };
    rows.push(row);
    console.log(`${row.seconds}s  blocks=${row.blocks}  grade=${row.grade ?? '—'}  lunchMissing=${row.lunchMissing.length}`);
  } catch (e) {
    rows.push({
      file, ok: false, blocks: '', missingBlocks: [], courses: 0, frees: 0, grade: null,
      lunchMissing: [...WEEKDAYS], lunch: {}, skipped: [], rejected: 0, attempts: 0,
      seconds: Math.round((Date.now() - started) / 100) / 10, message: '', classes: [],
      error: (e as Error).message,
    });
    console.log(`FAILED: ${(e as Error).message}`);
  }
}

// ---- Report -----------------------------------------------------------------

console.log(`\n${'='.repeat(78)}\nPER SHEET\n${'='.repeat(78)}`);
for (const r of rows) {
  console.log(`\n${r.file}`);
  if (!r.ok) {
    console.log(`  ERROR: ${r.error}`);
    continue;
  }
  console.log(`  ${r.courses} course(s), ${r.frees} free, grade ${r.grade ?? 'NOT READ'}, ${r.attempts} attempt(s), ${r.seconds}s`);
  for (const c of r.classes) {
    console.log(`    ${c.block}  ${c.subject}${c.teacher ? `  ·  ${c.teacher}` : ''}${c.room ? `  ·  ${c.room}` : ''}`);
  }
  if (r.missingBlocks.length) console.log(`    blocks not on the sheet: ${r.missingBlocks.join(', ')}`);
  console.log(`    lunch: ${WEEKDAYS.map((d) => `${d.slice(0, 3)}=${r.lunch[d] ?? '—'}`).join(' ')}`);
  if (r.skipped.length) console.log(`    SKIPPED non-course rows: ${r.skipped.map((s) => `${s.block}:${s.subject}`).join(', ')}`);
  if (r.rejected) console.log(`    ${r.rejected} rejected then corrected`);
  if (r.message) console.log(`    model said: ${r.message.replace(/\s+/g, ' ').slice(0, 300)}`);
}

// What actually needs a person's attention, rather than a wall of green.
console.log(`\n${'='.repeat(78)}\nWHAT TO LOOK AT\n${'='.repeat(78)}`);

const flag = (label: string, hits: string[]) => {
  if (hits.length) console.log(`\n${label}\n${hits.map((h) => `  - ${h}`).join('\n')}`);
};

flag('FAILED OUTRIGHT', rows.filter((r) => !r.ok).map((r) => `${r.file}: ${r.error}`));
flag('NO GRADE READ', rows.filter((r) => r.ok && !r.grade).map((r) => r.file));
flag(
  'LUNCH DAYS MISSING (a student has to set these by hand)',
  rows.filter((r) => r.ok && r.lunchMissing.length).map((r) => `${r.file}: ${r.lunchMissing.join(', ')}`),
);
flag(
  'NON-COURSE ROWS THE MODEL TRIED TO SAVE (prompt drift)',
  rows.filter((r) => r.skipped.length).map((r) => `${r.file}: ${r.skipped.map((s) => s.subject).join(', ')}`),
);
flag(
  'FEWER THAN 4 COURSES (suspicious for a full sheet)',
  rows.filter((r) => r.ok && r.courses < 4).map((r) => `${r.file}: ${r.courses}`),
);
flag(
  'TEACHER AND ROOM STILL FUSED (a digit in the teacher field)',
  rows.flatMap((r) => r.classes.filter((c) => c.teacher && /\d/.test(c.teacher)).map((c) => `${r.file} ${c.block}: "${c.teacher}"`)),
);
flag(
  'SHEET WORDING SURVIVED INSTEAD OF "Free"',
  rows.flatMap((r) =>
    r.classes.filter((c) => /unscheduled|study hall|open|free period/i.test(c.subject)).map((c) => `${r.file} ${c.block}: "${c.subject}"`),
  ),
);
flag('NEEDED A CORRECTION ROUND', rows.filter((r) => r.attempts > 1).map((r) => `${r.file}: ${r.attempts} attempts`));

const good = rows.filter((r) => r.ok).length;
const clean = rows.filter((r) => r.ok && r.grade && !r.lunchMissing.length && !r.skipped.length && r.courses >= 4).length;
console.log(`\n${'='.repeat(78)}`);
console.log(`CHECKED ${rows.length} sheet(s): ${good} read without error, ${clean} with nothing at all to look at.`);
console.log(`Total model time ${rows.reduce((n, r) => n + r.seconds, 0).toFixed(1)}s, roughly $${(rows.length * 0.0624).toFixed(2)} on Opus 5.`);

if (jsonOut) {
  writeFileSync(jsonOut, JSON.stringify(rows, null, 2));
  console.log(`Full output written to ${jsonOut}`);
}
