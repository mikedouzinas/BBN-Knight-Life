/**
 * Will the new-school-year prompt actually appear on the first day?
 *
 * The prompt is what tells ~639 students their classes need setting up and that they can
 * photograph their schedule instead of typing seven blocks. Every student's A-G was cleared on
 * 2026-09-03, so on the first morning the app is empty for everyone - if this prompt does not
 * fire, they open Knight Life to seven blank blocks with nothing explaining why.
 *
 * It is gated on `schedules/term`, which is data an admin edits, so it can be silently wrong in a
 * way no code review or app test would catch. AuthVC.checkNewYearSetup requires all of:
 *
 *   - `start` parses as yyyy/M/d
 *   - today >= rolloverPromptFrom (defaults to `start`)
 *   - today <= rolloverPromptUntil (defaults to 30 days after it opens)
 *   - the student's `classesSetForTermStart` != start
 *
 * This checks the first three against the live document for a given day.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     npx tsx --conditions=react-server scripts/check-rollover-prompt.mts [yyyy/M/d ...]
 *
 * With no arguments it checks the first day of the term. Pass dates to ask about specific days.
 */
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

function parse(s: string): Date | null {
  const m = /^(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(s.trim());
  if (!m) return null;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Number.isNaN(d.getTime()) ? null : d;
}
const fmt = (d: Date) => `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`;

if (!getApps().length) {
  initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS!, 'utf8'))) });
}
const snap = await getFirestore().collection('schedules').doc('term').get();
if (!snap.exists) { console.error('\nschedules/term does not exist. The prompt can never fire.\n'); process.exit(1); }
const data = snap.data() ?? {};

console.log('\nschedules/term');
for (const k of ['start', 'end', 'rolloverPromptFrom', 'rolloverPromptUntil']) {
  console.log(`  ${k.padEnd(20)} ${data[k] === undefined ? '(not set)' : JSON.stringify(data[k])}`);
}

const start = typeof data.start === 'string' ? parse(data.start) : null;
if (!start) {
  console.error(`\n"start" is ${JSON.stringify(data.start)}, which does not parse as yyyy/M/d. rolloverWindow returns nil and the prompt NEVER fires.\n`);
  process.exit(1);
}

const opens = (typeof data.rolloverPromptFrom === 'string' ? parse(data.rolloverPromptFrom) : null) ?? start;
const defaultClose = new Date(opens); defaultClose.setDate(defaultClose.getDate() + 30);
const closes = (typeof data.rolloverPromptUntil === 'string' ? parse(data.rolloverPromptUntil) : null) ?? defaultClose;

console.log(`\nwindow: ${fmt(opens)} .. ${fmt(closes)}`);
if (opens > closes) {
  console.error('\nThe window closes before it opens. rolloverWindow treats that as a typo and returns nil - the prompt NEVER fires.\n');
  process.exit(1);
}

const days = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const targets = days.length ? days : [fmt(start)];

let bad = 0;
console.log('');
for (const day of targets) {
  const d = parse(day);
  if (!d) { console.log(`  ${day.padEnd(12)} UNPARSEABLE`); bad += 1; continue; }
  if (d < opens) { console.log(`  ${day.padEnd(12)} NO  - before the window opens (${fmt(opens)})`); bad += 1; continue; }
  if (d > closes) { console.log(`  ${day.padEnd(12)} NO  - after the window closes (${fmt(closes)}); the app records setup silently instead`); bad += 1; continue; }
  console.log(`  ${day.padEnd(12)} YES - prompt appears`);
}

console.log(`\nCHECKED ${targets.length} day(s) against the live schedules/term.`);
if (bad) { console.log(`${bad} would NOT prompt.`); process.exit(1); }
console.log('Every day checked would show the prompt to a student who has not set up this term.');
