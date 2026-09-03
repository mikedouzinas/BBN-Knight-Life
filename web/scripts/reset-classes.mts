/**
 * Start the 2026-27 year: everyone's classes cleared, the duplicates removed, nothing else lost.
 *
 * WHAT IT DOES, AND WHY EACH PART
 *
 * 1. CLEARS A-G ON EVERY STUDENT. Who is in what is a fact about last year and all of it is now
 *    wrong. Everyone re-scans or re-picks.
 *
 * 2. EMPTIES EVERY CLASS ROSTER. The other half of the same fact. Clearing only the student side
 *    leaves 639 people listed in classes they are no longer in, and `members` is what
 *    ClassPopupVC renders as "who else is in your class".
 *
 * 3. MIGRATES `l-a` TO `l-b`. The 2026-27 schedule moved Thursday's lunch from A block to B
 *    block. A student's Thursday lunch WAVE has not changed - only the block letter carrying it -
 *    so the value moves rather than being thrown away. Without this, every student's Thursday
 *    lunch silently falls back to the "2nd Lunch" default and every 1st-lunch student has a wrong
 *    Thursday until they rescan. No other day's lunch block changed, so this is the only
 *    migration needed, and A is no longer a lunch block at all.
 *
 * 4. DELETES DUPLICATE CLASS DOCUMENTS. Four of them, all free blocks written before the prompt
 *    normalised every wording onto "Free": `Free~NA~NA~G`, `Unscheduled~Free~Free~A`,
 *    `Unscheduled~None~0~B`, `Unscheduled~None~None~F`. Each sits beside a canonical
 *    `Free~~~X` holding far more people. Chosen by CANONICAL KEY rather than by a hardcoded
 *    list, so a fifth spelling is caught too, and the survivor is whichever document has the
 *    most members.
 *
 * 5. BACKFILLS A MISSING `name`. Twelve documents have none, and `ClassesOptionsPopupVC` builds
 *    every picker row from that field alone - so a class with no name renders as "N/A" and is
 *    unpickable. The document id IS the key, so it is the correct value.
 *
 * WHAT IT DELIBERATELY DOES NOT DO
 *
 * It does not delete the 327 real class documents. They are well-formed and correct
 * (`AP Calculus AB~Thomas Randall~385~A`), they took a year to accumulate, and the school's own
 * catalogue does not arrive until Tuesday morning. Deleting them means every student types their
 * classes into an empty picker on the first day and there is nothing for HQ-877 to reconcile
 * against.
 *
 * USAGE
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     npx tsx --conditions=react-server scripts/reset-classes.mts [--apply]
 *
 * Dry run by default. There is no undo; read the counts before passing --apply.
 */
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const APPLY = process.argv.includes('--apply');
const BLOCKS = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;

/** Thursday's lunch moved from A block to B block for 2026-27. The wave itself is unchanged. */
const LUNCH_MIGRATION = { from: 'l-a', to: 'l-b' } as const;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('\nGOOGLE_APPLICATION_CREDENTIALS is not set.\n');
  process.exit(1);
}
if (!getApps().length) {
  initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'))) });
}
const db = getFirestore();

const FREE_WORDS = ['free', 'unscheduled', 'study hall', 'open', 'free period', 'study or free'];
function canon(part: string): string {
  return part.trim().replace(/\s+/g, ' ').replace(/^n\/?a$/i, '').toLowerCase();
}
/** Two documents describing one real class produce one key. Mirrors ClassIdentity in the app. */
function canonKey(id: string): string {
  const p = id.split('~');
  if (p.length !== 4) return `MALFORMED:${id}`;
  const subject = canon(p[0]);
  return FREE_WORDS.includes(subject)
    ? `free~~~${canon(p[3])}`
    : `${subject}~${canon(p[1])}~${canon(p[2])}~${canon(p[3])}`;
}

console.log(`\n${APPLY ? '*** APPLYING - THIS CANNOT BE UNDONE ***' : 'DRY RUN - nothing will change'}\n`);

// --- Students -------------------------------------------------------------------------------
// First, so an interruption leaves students with no classes (recoverable: they scan) rather than
// pointing at rosters that no longer contain them.

const users = await db.collection('users').get();
let hadClasses = 0;
let lunchMigrated = 0;
let userWrites = 0;

for (const doc of users.docs) {
  const data = doc.data();
  const patch: Record<string, unknown> = {};

  if (BLOCKS.some((b) => typeof data[b] === 'string' && data[b] !== '')) {
    hadClasses += 1;
    for (const b of BLOCKS) patch[b] = '';
  }

  const thursdayWave = data[LUNCH_MIGRATION.from];
  if (typeof thursdayWave === 'string' && thursdayWave !== '') {
    // Overwrites `l-b` unconditionally, and that is deliberate rather than careless.
    //
    // B was NOT a lunch block in 2025-26 - the five were D, C, G, A, F - so nothing the schedule
    // ever read lived in `l-b`, and any value sitting there predates B carrying lunch and cannot
    // be a Thursday preference. `l-a` is, by definition, exactly that.
    //
    // Preserving the existing `l-b` would look like the cautious choice and would leave a third
    // of students with a stale value standing in for their real Thursday answer.
    patch[LUNCH_MIGRATION.to] = thursdayWave;
    patch[LUNCH_MIGRATION.from] = '';
    lunchMigrated += 1;
  }

  if (Object.keys(patch).length === 0) continue;
  if (APPLY) {
    await doc.ref.set(patch, { merge: true });
    userWrites += 1;
  }
}

console.log(`users:   ${users.size} total`);
console.log(`         ${hadClasses} had at least one class set -> A-G cleared`);
console.log(`         ${lunchMigrated} had a Thursday lunch wave -> moved ${LUNCH_MIGRATION.from} to ${LUNCH_MIGRATION.to}`);
if (APPLY) console.log(`         ${userWrites} document(s) written`);

// --- Class documents ------------------------------------------------------------------------

const classes = await db.collection('classes').get();
const groups = new Map<string, { id: string; members: number; hasName: boolean }[]>();

for (const d of classes.docs) {
  const data = d.data();
  const entry = {
    id: d.id,
    members: Array.isArray(data.members) ? data.members.length : 0,
    hasName: typeof data.name === 'string' && data.name !== '',
  };
  const k = canonKey(d.id);
  if (!groups.has(k)) groups.set(k, []);
  groups.get(k)!.push(entry);
}

const toDelete: string[] = [];
for (const [, entries] of groups) {
  if (entries.length < 2) continue;
  // The survivor is the one the most people are already on, so the smallest number of students
  // is affected by the merge.
  const sorted = [...entries].sort((a, b) => b.members - a.members);
  for (const loser of sorted.slice(1)) toDelete.push(loser.id);
}

const needName = classes.docs
  .filter((d) => !toDelete.includes(d.id))
  .filter((d) => typeof d.data().name !== 'string' || d.data().name === '')
  .map((d) => d.id);

const withRosters = classes.docs.filter((d) => (d.data().members as unknown[] | undefined)?.length);

console.log(`\nclasses: ${classes.size} total, ${classes.size - toDelete.length} kept`);
console.log(`         ${toDelete.length} duplicate(s) deleted:`);
for (const id of toDelete) console.log(`             ${id}`);
console.log(`         ${withRosters.length} roster(s) emptied`);
console.log(`         ${needName.length} missing \`name\` backfilled from the document id:`);
for (const id of needName.slice(0, 15)) console.log(`             ${id}`);
if (needName.length > 15) console.log(`             ... and ${needName.length - 15} more`);

if (APPLY) {
  let n = 0;
  for (let i = 0; i < classes.docs.length; i += 300) {
    const batch = db.batch();
    for (const d of classes.docs.slice(i, i + 300)) {
      const ref = db.collection('classes').doc(d.id);
      if (toDelete.includes(d.id)) {
        batch.delete(ref);
      } else {
        const patch: Record<string, unknown> = { members: [] };
        if (needName.includes(d.id)) patch.name = d.id;
        batch.set(ref, patch, { merge: true });
      }
      n += 1;
    }
    await batch.commit();
    process.stdout.write(`\r  processed ${n}/${classes.size}`);
  }
  process.stdout.write('\n');
}

console.log(
  `\nCHECKED ${users.size} user(s) and ${classes.size} class document(s).` +
    (APPLY ? ' Done.' : ' Nothing changed. Re-run with --apply.'),
);
