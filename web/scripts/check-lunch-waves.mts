/**
 * Both lunch waves are complete and correctly shaped, on every weekday.
 *
 * A student is either 1st lunch or 2nd lunch, and the two see genuinely different days: 1st eats
 * 11:25-11:55 and has the block after, 2nd has the block 11:25-12:10 and eats after. The schedule
 * expresses that as two `specific` variants per day, filtered on "L1" and "L2", and the app picks
 * one by the student's `l-<block>` preference.
 *
 * If either variant is missing, malformed, or points at a different block from its twin, that half
 * of the school gets a broken day and the other half is fine - which is the hardest kind of bug to
 * notice, because whoever checks is only ever in one wave.
 *
 * Run after ANY edit to schedules/regular. The 2026-27 change moved Thursday's lunch from A block
 * to B, touching both variants, which is exactly when a pair can be left half-migrated.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     npx tsx --conditions=react-server scripts/check-lunch-waves.mts
 *
 * FALSIFIED 2026-09-03: set Thursday's L2 variant back to lunchBlock "a" while L1 stayed on "b",
 * and re-ran.
 *     thursday
 *       X the two variants point at different blocks: b and a - a half-finished migration
 *     1 problem(s). One wave of the school would see a wrong day.
 *   exit 1
 * Restored: "Both waves are complete and correctly shaped on every day", exit 0.
 */
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

interface Ev {
  type?: string; block?: string; name?: string; startTime?: string; endTime?: string;
  filter?: string[]; lunchBlock?: string; contents?: Ev[];
}

const DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'] as const;

/** From the 2026-27 sheet. Identical on all five days. */
const EXPECTED = {
  L1: { lunch: ['11:25 am', '11:55 am'], block: ['12:00 pm', '12:45 pm'], suffix: '2', lunchFirst: true },
  L2: { block: ['11:25 am', '12:10 pm'], lunch: ['12:15 pm', '12:45 pm'], suffix: '1', lunchFirst: false },
} as const;

if (!getApps().length) {
  initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS!, 'utf8'))) });
}
const doc = await getFirestore().collection('schedules').doc('regular').get();
if (!doc.exists) { console.error('schedules/regular does not exist.'); process.exit(1); }
const data = doc.data() as Record<string, Ev[]>;

let problems = 0;
let checked = 0;
const fail = (msg: string) => { console.log(`  ✗ ${msg}`); problems += 1; };

for (const day of DAYS) {
  const events = data[day] ?? [];
  const waves = events.filter((e) => e.type === 'specific' && e.lunchBlock);
  console.log(`\n${day}`);

  if (waves.length !== 2) { fail(`${waves.length} lunch variant(s), expected exactly 2 (L1 and L2)`); continue; }

  const tags = waves.map((w) => (w.filter ?? []).join(','));
  if (!tags.includes('L1') || !tags.includes('L2')) { fail(`variants are filtered [${tags}], expected L1 and L2`); continue; }

  const blocks = new Set(waves.map((w) => w.lunchBlock));
  if (blocks.size !== 1) { fail(`the two variants point at different blocks: ${[...blocks].join(' and ')} - a half-finished migration`); continue; }
  const block = [...blocks][0]!;

  for (const wave of waves) {
    const tag = (wave.filter ?? []).join(',') as 'L1' | 'L2';
    const want = EXPECTED[tag];
    const contents = wave.contents ?? [];
    checked += 1;

    const lunch = contents.find((c) => c.type === 'lunch');
    const blk = contents.find((c) => c.type === 'block');
    if (!lunch) { fail(`${tag}: no lunch entry`); continue; }
    if (!blk) { fail(`${tag}: no class block alongside lunch`); continue; }

    if (lunch.startTime !== want.lunch[0] || lunch.endTime !== want.lunch[1]) {
      fail(`${tag}: lunch is ${lunch.startTime}-${lunch.endTime}, sheet says ${want.lunch[0]}-${want.lunch[1]}`);
    }
    if (blk.startTime !== want.block[0] || blk.endTime !== want.block[1]) {
      fail(`${tag}: ${blk.name} is ${blk.startTime}-${blk.endTime}, sheet says ${want.block[0]}-${want.block[1]}`);
    }
    if (blk.block !== block) {
      fail(`${tag}: the class is block ${blk.block} but the variant says lunchBlock ${block}`);
    }
    const wantName = `${block.toUpperCase()}${want.suffix}`;
    if (blk.name !== wantName) fail(`${tag}: class is named "${blk.name}", expected "${wantName}"`);

    // Ordering is what actually distinguishes the two waves.
    const lunchIdx = contents.indexOf(lunch);
    const blkIdx = contents.indexOf(blk);
    if (want.lunchFirst !== lunchIdx < blkIdx) {
      fail(`${tag}: ${want.lunchFirst ? 'lunch should come before' : 'the class should come before'} the other, order is wrong`);
    }
  }

  if (problems === 0 || true) {
    console.log(`  lunch block ${block.toUpperCase()}  ·  L1 eats 11:25, has ${block.toUpperCase()}2 after  ·  L2 has ${block.toUpperCase()}1, eats 12:15`);
  }
}

console.log(`\nCHECKED ${DAYS.length} weekday(s), ${checked} lunch variant(s).`);
if (problems) { console.log(`${problems} problem(s). One wave of the school would see a wrong day.`); process.exit(1); }
console.log('Both waves are complete and correctly shaped on every day.');
