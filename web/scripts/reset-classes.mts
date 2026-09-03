/**
 * Clear last year's classes before a new school year.
 *
 * WHY
 *
 * `classes/*` accumulates a document per distinct class text anyone ever typed or scanned. After a
 * year that collection describes last year: teachers moved, rooms changed, seniors graduated, and
 * `AuthVC` already records 374 documents carrying stale membership. A student searching the picker
 * in September finds a plausible-looking WRONG class and joins it, which is worse than finding
 * nothing and creating the right one - a wrong class is invisible, a missing one is obvious.
 *
 * WHAT IT KEEPS
 *
 * The seven canonical free blocks, `Free~~~A` through `Free~~~G`, emptied of members. Mike:
 * "the only ones I think we want to maintain are the free blocks, but I do want to clear all
 * people from being in them." They carry no year-specific information - a free B block is a free
 * B block - so keeping them costs nothing and means the first student to scan a free block joins
 * an existing roster rather than racing to create one.
 *
 * A free-block document in any OTHER spelling (`Free~N/A~N/A~G`, `Unscheduled~~~F`) is deleted.
 * Those are exactly the duplicates this is meant to remove.
 *
 * BOTH HALVES OR NEITHER
 *
 * It clears `classes/*` AND the A-G fields on every `users/*` document. Doing only the first
 * leaves ~645 students pointing at documents that no longer exist; doing only the second leaves
 * the wrong classes in the picker. The users pass runs FIRST, so an interruption leaves students
 * with no classes (recoverable, they scan) rather than pointing at deleted ones.
 *
 * USAGE
 *
 *   # Dry run. Prints exactly what it would do and changes nothing. This is the default.
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
 *     npx tsx --conditions=react-server scripts/reset-classes.mts
 *
 *   # For real.
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
 *     npx tsx --conditions=react-server scripts/reset-classes.mts --apply
 *
 * Get the credentials from Firebase console -> Project Settings -> Service Accounts ->
 * Generate new private key. Delete the file afterwards.
 *
 * There is no undo. The dry run is not a formality - read its counts and check they match what
 * you expect the database to contain before passing --apply.
 */
import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const APPLY = process.argv.includes('--apply');
const BLOCKS = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;
/** The only documents that survive, and only after their rosters are emptied. */
const KEEP = new Set(BLOCKS.map((b) => `Free~~~${b}`));

function fail(msg: string): never {
  console.error(`\n${msg}\n`);
  process.exit(1);
}

const credsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!credsPath) fail('GOOGLE_APPLICATION_CREDENTIALS is not set. Point it at a service-account JSON.');

if (!getApps().length) {
  try {
    initializeApp({ credential: cert(JSON.parse(readFileSync(credsPath, 'utf8'))) });
  } catch {
    initializeApp({ credential: applicationDefault() });
  }
}
const db = getFirestore();

console.log(`\n${APPLY ? '*** APPLYING - THIS CANNOT BE UNDONE ***' : 'DRY RUN - nothing will change'}\n`);

// --- 1. Students first. See "both halves or neither" above. --------------------------------

const users = await db.collection('users').get();
let usersWithClasses = 0;
let userWrites = 0;

for (const doc of users.docs) {
  const data = doc.data();
  const setBlocks = BLOCKS.filter((b) => typeof data[b] === 'string' && data[b] !== '');
  if (setBlocks.length === 0) continue;
  usersWithClasses += 1;
  if (APPLY) {
    await doc.ref.set(Object.fromEntries(BLOCKS.map((b) => [b, ''])), { merge: true });
    userWrites += 1;
  }
}

console.log(`users:   ${users.size} total, ${usersWithClasses} with at least one class set`);
console.log(`         ${APPLY ? `${userWrites} cleared` : 'would clear A-G on those'}`);

// --- 2. Then the class documents. ----------------------------------------------------------

const classes = await db.collection('classes').get();
const keep: string[] = [];
const remove: string[] = [];

for (const doc of classes.docs) {
  (KEEP.has(doc.id) ? keep : remove).push(doc.id);
}

console.log(`\nclasses: ${classes.size} total`);
console.log(`         ${keep.length} canonical free block(s) kept, rosters emptied: ${keep.sort().join(', ') || '(none)'}`);
console.log(`         ${remove.length} deleted`);

// A sample rather than all of them, so the dry run stays readable on a collection of hundreds.
if (remove.length) {
  console.log(`\n  first 25 to be deleted:`);
  for (const id of remove.slice(0, 25)) console.log(`    ${id}`);
  if (remove.length > 25) console.log(`    ... and ${remove.length - 25} more`);
}

// Any canonical free block that does not exist yet is created empty, so all seven are present
// and the first student to scan a free block joins rather than creates.
const missingFree = [...KEEP].filter((id) => !keep.includes(id));
if (missingFree.length) {
  console.log(`\n  ${missingFree.length} canonical free block(s) missing, will be created empty: ${missingFree.sort().join(', ')}`);
}

if (APPLY) {
  // Batched, 400 at a time - Firestore's limit is 500 operations per batch.
  let done = 0;
  for (let i = 0; i < remove.length; i += 400) {
    const batch = db.batch();
    for (const id of remove.slice(i, i + 400)) batch.delete(db.collection('classes').doc(id));
    await batch.commit();
    done += Math.min(400, remove.length - i);
    process.stdout.write(`\r  deleted ${done}/${remove.length}`);
  }
  if (remove.length) process.stdout.write('\n');

  for (const id of KEEP) {
    await db.collection('classes').doc(id).set(
      { name: id, block: id.split('~')[3], members: [], monday: true, tuesday: true, wednesday: true, thursday: true, friday: true },
      { merge: true },
    );
  }
  console.log(`  ${KEEP.size} canonical free block(s) present and empty`);
}

console.log(
  `\nCHECKED ${users.size} user(s) and ${classes.size} class document(s).` +
    (APPLY ? ' Done.' : ' Nothing changed. Re-run with --apply to do it.'),
);
