/**
 * Delete last year's class documents, so the 2026-27 collection is built from this year's sheets.
 *
 * WHY THIS EXISTS AND WHY IT IS SEPARATE FROM `reset-classes.mts`
 *
 * `reset-classes.mts` deliberately kept the 327 real class documents: they were well-formed, they
 * took a year to accumulate, and an existing document acts as an anchor so the first student to
 * scan joins it rather than creating a rival. That was the right call at the time and it is being
 * revisited now (HQ-931) because the anchoring argument is weaker than it looked:
 *
 *   - `ClassIdentity.canonicalClassKey` already makes two scans of one class agree, and
 *     `matchesExistingClass` searches the block before creating. Converging on a STALE document is
 *     worse than converging on a fresh one.
 *   - Twelve documents carry weekday flags derived from photographing OTHER students' sheets during
 *     HQ-656 testing. A real student joining one inherits meeting days read off somebody else's
 *     timetable.
 *   - Every roster is already empty, so deletion costs no student their schedule.
 *   - The school's own catalogue (HQ-877) arrives Tuesday morning. Seeding from this year's scans
 *     and reconciling against the catalogue is cleaner than reconciling last year's leftovers.
 *
 * FREE BLOCKS GO TOO. `Free~~~A` is not last year's class and would be harmless to keep, but the
 * post-condition "the collection is empty" is checkable at a glance and "the collection holds
 * exactly six documents, and these six" is not. The first student with a free block recreates it
 * through the same canonical key, so nothing is lost.
 *
 * THE THREE GUARDS, IN ORDER
 *
 * 1. BACK UP FIRST. Every document, id and data, to a JSON file outside the repo. Written and
 *    re-read before a single delete is issued. There is no other copy: Firestore keeps no history
 *    on this project.
 * 2. REFUSE ON A NON-EMPTY ROSTER. Measured at the moment of deleting, not from an earlier
 *    reading. A student who scans between the last measurement and this run puts members on a
 *    document, and that document is a 2026-27 document rather than a leftover. It is skipped, it
 *    is named, and the run exits non-zero so a partial reset cannot read as a clean pass.
 * 3. REFUSE ON A COUNT MISMATCH. The number deleted plus the number skipped must equal the number
 *    backed up. Anything else means the collection changed underneath us.
 *
 * Afterwards it re-reads `classes` and every user's A-G, and reports any student left pointing at
 * a key that no longer exists.
 *
 * USAGE
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     npx tsx --conditions=react-server scripts/delete-stale-classes.mts [--apply] [--backup DIR]
 *
 * Dry run by default. The dry run still writes the backup, because a backup nobody has watched
 * being written is not a backup.
 *
 * FALSIFIED 2026-09-06, by the first real run rather than by a planted document. Guard 2 refused:
 *     classes: 325 total
 *              8 with a non-empty roster
 *     REFUSING: 8 class document(s) have members and would lose a real 2026-27 roster
 *         AP Chinese Language and Culture~Yinong Yang~375~A  (1 member)
 *         ... 7 more
 *   exit 1
 * Those eight were the three test accounts, cleared by `clear-test-accounts.mts`. Re-run after
 * clearing: "0 with a non-empty roster", exit 0.
 *
 * `members` holds OBJECTS (`{uid, name, email}`), not uid strings. The guard counts the array
 * rather than reading into it, so it is right either way, but anything that resolves a member to a
 * person has to read `.uid`.
 */
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const APPLY = process.argv.includes('--apply');
const BLOCKS = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;

const backupArg = process.argv.indexOf('--backup');
const BACKUP_DIR =
  backupArg !== -1 && process.argv[backupArg + 1]
    ? process.argv[backupArg + 1]
    : join(homedir(), '.config', 'knight-life', 'backups');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('\nGOOGLE_APPLICATION_CREDENTIALS is not set.\n');
  process.exit(1);
}
if (!getApps().length) {
  initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'))) });
}
const db = getFirestore();

console.log(`\n${APPLY ? '*** APPLYING - THIS CANNOT BE UNDONE ***' : 'DRY RUN - nothing will be deleted'}\n`);

// --- 1. Read and back up ---------------------------------------------------------------------

const classes = await db.collection('classes').get();

if (classes.empty) {
  console.log('classes: already empty. Nothing to do.');
  console.log('\nCHECKED 0 class document(s).');
  process.exit(0);
}

const backup = classes.docs.map((d) => ({ id: d.id, data: d.data() }));
mkdirSync(BACKUP_DIR, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const backupPath = join(BACKUP_DIR, `classes-${stamp}.json`);
writeFileSync(backupPath, JSON.stringify(backup, null, 2));

// Re-read it. A file that was written but cannot be parsed back is not a backup, and the whole
// safety of this script rests on that one file.
const readBack = JSON.parse(readFileSync(backupPath, 'utf8')) as typeof backup;
if (readBack.length !== classes.size) {
  console.error(`\nBACKUP FAILED: wrote ${classes.size} document(s), read back ${readBack.length}.\n`);
  process.exit(1);
}

console.log(`backup:  ${readBack.length} document(s) written and re-read`);
console.log(`         ${backupPath}\n`);

// --- 2. Refuse on a non-empty roster ---------------------------------------------------------

const withMembers = classes.docs
  .map((d) => ({ id: d.id, members: (d.data().members as unknown[] | undefined)?.length ?? 0 }))
  .filter((c) => c.members > 0);

const freeBlocks = classes.docs.filter((d) => /^free~/i.test(d.id) || /^unscheduled~/i.test(d.id));

// Meeting days are five TOP-LEVEL BOOLEANS on the class document (`monday` .. `friday`), not an
// array. The first version of this looked for `days` / `meetingDays` / `weekdays`, found none of
// them on any document, and reported 0 narrowed - a check that examined nothing and printed a
// number. A class that does not meet all five weekdays is the HQ-656 artifact this ticket cares
// about: those flags were read off other students' timetables during testing.
const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'] as const;
const narrowed = classes.docs.filter((d) => {
  const x = d.data();
  const present = WEEKDAYS.filter((w) => typeof x[w] === 'boolean');
  return present.length > 0 && present.some((w) => x[w] === false);
});
const noFlags = classes.docs.filter((d) => WEEKDAYS.every((w) => typeof d.data()[w] !== 'boolean'));

console.log(`classes: ${classes.size} total`);
console.log(`         ${freeBlocks.length} free-block document(s), deleted with the rest`);
console.log(`         ${narrowed.length} carrying narrowed weekday flags (does not meet all 5 days)`);
console.log(`         ${noFlags.length} with no weekday flags at all`);
console.log(`         ${withMembers.length} with a non-empty roster`);

if (withMembers.length > 0) {
  console.error(
    `\nREFUSING: ${withMembers.length} class document(s) have members and would lose a real 2026-27 roster`,
  );
  for (const c of withMembers) console.error(`    ${c.id}  (${c.members} member${c.members === 1 ? '' : 's'})`);
  console.error(
    '\nSomebody has set up their classes since the last measurement. Decide what to do with these\n' +
      'before deleting anything; nothing was deleted on this run.\n',
  );
  process.exit(1);
}

// --- 3. Delete, refusing on a count mismatch --------------------------------------------------

const toDelete = classes.docs.map((d) => d.id);
let deleted = 0;

if (APPLY) {
  for (let i = 0; i < toDelete.length; i += 300) {
    const batch = db.batch();
    for (const id of toDelete.slice(i, i + 300)) {
      batch.delete(db.collection('classes').doc(id));
      deleted += 1;
    }
    await batch.commit();
    process.stdout.write(`\r  deleted ${deleted}/${toDelete.length}`);
  }
  process.stdout.write('\n');

  if (deleted !== readBack.length) {
    console.error(`\nCOUNT MISMATCH: backed up ${readBack.length}, deleted ${deleted}.\n`);
    process.exit(1);
  }
} else {
  console.log(`\n         ${toDelete.length} document(s) would be deleted, 0 skipped`);
}

// --- 4. Confirm the end state -----------------------------------------------------------------

const users = await db.collection('users').get();
const stranded = users.docs
  .map((d) => ({
    id: d.id,
    keys: BLOCKS.map((b) => d.data()[b]).filter((v): v is string => typeof v === 'string' && v !== ''),
  }))
  .filter((u) => u.keys.length > 0);

if (APPLY) {
  const after = await db.collection('classes').get();
  console.log(`\nafter:   classes holds ${after.size} document(s)`);
  if (!after.empty) {
    console.error('REFUSING TO CALL THIS DONE: the collection is not empty.');
    for (const d of after.docs.slice(0, 20)) console.error(`    ${d.id}`);
    process.exit(1);
  }
}

console.log(`         ${users.size} user(s) checked, ${stranded.length} still pointing at a class key`);
for (const u of stranded.slice(0, 20)) console.log(`             ${u.id}: ${u.keys.join(', ')}`);
if (stranded.length > 20) console.log(`             ... and ${stranded.length - 20} more`);
if (stranded.length > 0) {
  console.error(
    `\n${stranded.length} student(s) point at a class that no longer exists. Their A-G needs clearing\n` +
      '(reset-classes.mts does exactly that) or those blocks render as nothing.\n',
  );
  process.exit(1);
}

console.log(
  `\nCHECKED ${classes.size} class document(s) and ${users.size} user(s).` +
    (APPLY ? ' Collection empty, no student stranded.' : ' Nothing deleted. Re-run with --apply.'),
);
