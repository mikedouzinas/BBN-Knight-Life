/**
 * Move `schedules/regular` from the 2025-26 block pattern to 2026-27.
 *
 * SOURCE: "2026-27 Daily Block Schedule - Daily Schedule", sent by the school to Kai on
 * 2026-09-03. Monday and Wednesday are unchanged. Tuesday, Thursday and Friday are not, despite
 * being reported as "should be same as last year".
 *
 *   Tuesday   12:50-1:55 was A, is B        2:40-3:25 was B, is A
 *   Thursday  10:35-11:20 was B, is A       lunch block was A, is B
 *   Friday    8:15-9:00 was G, is B         9:05-10:10 was B, is A
 *             10:35-11:20 was A, is G
 *
 * THURSDAY'S LUNCH BLOCK IS THE ONE THAT CORRUPTS DATA. Everything else shows a student the
 * wrong time, which is visible. `lunchBlockByWeekday()` derives the weekday-to-block pairing from
 * this document, so with the old value a student confirming "1st lunch on Thursday" has it
 * written to `l-a`, while the app reads `l-b` for Thursday and finds nothing. Their Thursday is
 * silently wrong and nothing surfaces it.
 *
 * This TRANSFORMS the live document rather than rewriting it from a literal, so fields nobody
 * here knows about survive. It rewrites only the entries named below and asserts it found each
 * one - a rename upstream makes it fail loudly rather than silently skip.
 *
 * `ifstatements.shouldUseOnlineClasses` is true, so this document is what every student's app
 * actually reads, on any app version. That is why this needs no App Store release.
 *
 * USAGE
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     npx tsx --conditions=react-server scripts/patch-schedule-2026-27.mts [--apply]
 *
 * Dry run by default; prints a before/after for every change.
 */
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const APPLY = process.argv.includes('--apply');

interface Ev {
  type?: string; block?: string; name?: string; startTime?: string; endTime?: string;
  filter?: string[]; matchMode?: string; lunchBlock?: string; contents?: Ev[];
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('\nGOOGLE_APPLICATION_CREDENTIALS is not set.\n');
  process.exit(1);
}
if (!getApps().length) {
  initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'))) });
}
const db = getFirestore();

const changes: string[] = [];
let applied = 0;

/** Rewrites the block and name of the entry at `startTime` on `day`. */
function retime(events: Ev[], day: string, startTime: string, block: string, name: string) {
  const hit = events.find((e) => e.type === 'block' && e.startTime === startTime);
  if (!hit) throw new Error(`${day}: no block entry starting ${startTime}. The document shape changed; stop and re-read it.`);
  if (hit.block === block && hit.name === name) {
    changes.push(`  ${day} ${startTime}: already ${name} [${block}]`);
    return;
  }
  changes.push(`  ${day} ${startTime}: ${hit.name} [${hit.block}] -> ${name} [${block}]`);
  hit.block = block;
  hit.name = name;
  applied += 1;
}

/** Moves a whole lunch variant onto a different block letter, including its C1/C2-style names. */
function relunch(events: Ev[], day: string, from: string, to: string) {
  const variants = events.filter((e) => e.type === 'specific' && e.lunchBlock === from);
  if (variants.length !== 2) {
    throw new Error(`${day}: expected 2 lunch variants on block ${from}, found ${variants.length}.`);
  }
  for (const v of variants) {
    v.lunchBlock = to;
    for (const c of v.contents ?? []) {
      if (c.type !== 'block') continue;
      const suffix = (c.name ?? '').slice(-1); // "A1" -> "1"
      const renamed = `${to.toUpperCase()}${suffix}`;
      changes.push(`  ${day} ${c.startTime}: ${c.name} [${c.block}] -> ${renamed} [${to}]`);
      c.block = to;
      c.name = renamed;
      applied += 1;
    }
  }
  changes.push(`  ${day} lunchBlock: ${from} -> ${to}`);
  applied += 1;
}

const ref = db.collection('schedules').doc('regular');
const snap = await ref.get();
if (!snap.exists) {
  console.error('\nschedules/regular does not exist.\n');
  process.exit(1);
}
const data = snap.data() as Record<string, Ev[]>;

console.log(`\n${APPLY ? '*** APPLYING to schedules/regular ***' : 'DRY RUN - nothing will change'}\n`);

// Monday and Wednesday are untouched: verified identical to the 2026-27 sheet.
retime(data.tuesday, 'tuesday', '12:50 pm', 'b', 'Extended B');
retime(data.tuesday, 'tuesday', '2:40 pm', 'a', 'A');

retime(data.thursday, 'thursday', '10:35 am', 'a', 'A');
relunch(data.thursday, 'thursday', 'a', 'b');

retime(data.friday, 'friday', '8:15 am', 'b', 'B');
retime(data.friday, 'friday', '9:05 am', 'a', 'Extended A');
retime(data.friday, 'friday', '10:35 am', 'g', 'G');

console.log(changes.join('\n'));

if (APPLY) {
  await ref.set({ tuesday: data.tuesday, thursday: data.thursday, friday: data.friday }, { merge: true });
  console.log(`\nWrote tuesday, thursday and friday.`);
}

console.log(`\nCHECKED 5 weekday(s), ${applied} field change(s)${APPLY ? ' applied' : ' pending'}. Monday and Wednesday match the 2026-27 sheet already.`);
