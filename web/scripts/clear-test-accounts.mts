/**
 * Put the development accounts back to where a real student stands on the first morning.
 *
 * WHY THIS IS ITS OWN SCRIPT
 *
 * Three accounts carry data that no student's account carries. They were used to build and test the
 * scan (HQ-656, HQ-839, HQ-939), which means photographing OTHER students' timetables, and they
 * hold a scan budget in the thousands rather than five. Left alone they are the only three accounts
 * that begin the year already wrong:
 *
 *   - `classesSetForTermStart` equals the current term start, so the app believes the account is
 *     already set up and NEVER shows the rollover prompt. That is the flag doing exactly what it is
 *     supposed to do, and it is why a half-finished test session is worse than no session: one
 *     block set, six blank, and no prompt offering to fix it.
 *   - A-G point at last year's class documents, which `delete-stale-classes.mts` is about to remove.
 *   - Those class documents list the account in `members`, which is what blocks the delete.
 *
 * WHAT IT CLEARS, AND WHAT IT DELIBERATELY DOES NOT
 *
 * Clears A-G, clears `classesSetForTermStart`, and removes the account from every class roster. That
 * is the complete set of state the setup flow reads, so the account becomes indistinguishable from a
 * student who has never set up.
 *
 * It does NOT touch `l-<block>` lunch preferences, `grade`, `lockerNum`, `notifs` or the scan
 * budget. The scan reads lunch wave and grade off the photo and overwrites both, the budget is
 * deliberately large so testing can continue, and the rest is real preference. Clearing more than
 * the setup flow reads would be tidying rather than fixing.
 *
 * USAGE
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     npx tsx --conditions=react-server scripts/clear-test-accounts.mts [--apply] [--backup DIR]
 *
 * Dry run by default. Backs up each user document before writing.
 *
 * FALSIFIED 2026-09-06 by the first real run, which found something nobody had listed: one of the
 * three grants has NO user document.
 *     SKIPPED 1 orphaned grant(s) - a budget with no user document:
 *         CAISOSZD8MQrlipaHoUPrq0DHyN2
 * Confirmed by hand against `users`, `admins` and every roster: absent from all three. A testing
 * account that was deleted, leaving its 9999-scan budget behind. That was the first version's bug
 * as well - it refused the whole run over a uid with nothing on it to clear.
 *
 * The drift guard was falsified separately by removing Kai's uid from TEST_UIDS and re-running:
 *     REFUSING: 1 account(s) hold a testing budget but are not in TEST_UIDS
 *         hc03qRdZGLhfsQI2B7RoN3YAE4a2
 *   exit 1
 * Restored, and the run proceeded.
 */
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const APPLY = process.argv.includes('--apply');
const BLOCKS = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;

/**
 * The three accounts that hold a `student-budgets` document with a testing grant rather than the
 * five scans a student gets. That collection is the definition of "development account" here, and
 * it is checked at run time rather than trusted, so a fourth grant cannot be missed silently.
 */
const TEST_UIDS = [
  'yCLV5D5yyOWyGM1C0WiyQ1GXTWb2', // Mike
  'CAISOSZD8MQrlipaHoUPrq0DHyN2', // Mike, second uid
  'hc03qRdZGLhfsQI2B7RoN3YAE4a2', // Kai
] as const;

/** A student gets five. Anything above this is a testing grant. */
const STUDENT_BUDGET = 5;

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

console.log(`\n${APPLY ? '*** APPLYING ***' : 'DRY RUN - nothing will change'}\n`);

// --- The list is checked against the budgets, not trusted ---------------------------------------

const budgets = await db.collection('student-budgets').get();
const granted = budgets.docs
  .filter((d) => ((d.data().classSetupSubmissionsRemaining as number) ?? 0) > STUDENT_BUDGET)
  .map((d) => d.id);

const unlisted = granted.filter((u) => !TEST_UIDS.includes(u as (typeof TEST_UIDS)[number]));
if (unlisted.length > 0) {
  console.error(`\nREFUSING: ${unlisted.length} account(s) hold a testing budget but are not in TEST_UIDS`);
  for (const u of unlisted) console.error(`    ${u}`);
  console.error('\nAdd them deliberately or revoke the grant; do not let the two lists drift.\n');
  process.exit(1);
}

// A uid with a budget but no user document is an ORPHANED GRANT, not an error. It is a testing
// account that was signed out of or deleted, leaving its budget behind. Firebase never reuses a
// uid, so nobody can ever claim the grant and it cannot be exploited. It is skipped and named
// rather than refused, because there is genuinely nothing on it to clear.
const orphaned: string[] = [];
const docs = [];
for (const uid of TEST_UIDS) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) orphaned.push(uid);
  else docs.push(snap);
}

console.log(`budgets: ${budgets.size} total, ${granted.length} above the ${STUDENT_BUDGET}-scan student cap`);
console.log(`         all ${granted.length} are listed in TEST_UIDS`);
if (orphaned.length > 0) {
  console.log(`\nSKIPPED ${orphaned.length} orphaned grant(s) - a budget with no user document:`);
  for (const u of orphaned) console.log(`    ${u}`);
  console.log('    Nothing to clear on these. The grant is unclaimable; a uid is never reissued.');
}
console.log('');

if (docs.length === 0) {
  console.error('\nREFUSING: every uid in TEST_UIDS is orphaned. Nothing was examined.\n');
  process.exit(1);
}

// --- Back up before writing ---------------------------------------------------------------------

mkdirSync(BACKUP_DIR, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const backupPath = join(BACKUP_DIR, `test-accounts-${stamp}.json`);
writeFileSync(backupPath, JSON.stringify(docs.map((d) => ({ id: d.id, data: d.data() })), null, 2));
const readBack = JSON.parse(readFileSync(backupPath, 'utf8')) as unknown[];
if (readBack.length !== docs.length) {
  console.error(`\nBACKUP FAILED: wrote ${docs.length}, read back ${readBack.length}.\n`);
  process.exit(1);
}
console.log(`backup:  ${readBack.length} user document(s) written and re-read`);
console.log(`         ${backupPath}\n`);

// --- Clear the student side ---------------------------------------------------------------------

console.log(`${docs.length} account(s) to clear:`);
for (const d of docs) {
  const x = d.data()!;
  const set = BLOCKS.filter((b) => typeof x[b] === 'string' && x[b] !== '');
  console.log(`  ${d.id}  grade ${x.grade ?? '?'}  ${set.length} block(s) set  ` +
    `classesSetForTermStart=${JSON.stringify(x.classesSetForTermStart ?? '')}`);
  for (const b of set) console.log(`      ${b}: ${x[b]}`);

  if (APPLY) {
    const patch: Record<string, unknown> = { classesSetForTermStart: '' };
    for (const b of BLOCKS) patch[b] = '';
    await d.ref.set(patch, { merge: true });
  }
}

// --- Clear the class side -----------------------------------------------------------------------

const classes = await db.collection('classes').get();
const touched: { id: string; before: number; after: number }[] = [];

for (const d of classes.docs) {
  const members = d.data().members as { uid?: string }[] | string[] | undefined;
  if (!Array.isArray(members) || members.length === 0) continue;
  const kept = (members as unknown[]).filter((m) => {
    const uid = typeof m === 'string' ? m : (m as { uid?: string })?.uid;
    return !TEST_UIDS.includes(uid as (typeof TEST_UIDS)[number]);
  });
  if (kept.length === members.length) continue;
  touched.push({ id: d.id, before: members.length, after: kept.length });
  if (APPLY) await d.ref.set({ members: kept }, { merge: true });
}

console.log(`\nclasses: ${classes.size} total, ${touched.length} roster(s) hold a test account`);
for (const t of touched) console.log(`      ${t.id}  ${t.before} -> ${t.after}`);

// --- Confirm --------------------------------------------------------------------------------------

if (APPLY) {
  const after = await db.collection('classes').get();
  const stillHeld = after.docs.filter((d) => {
    const m = d.data().members as unknown[] | undefined;
    return (m ?? []).some((x) => TEST_UIDS.includes(((typeof x === 'string' ? x : (x as { uid?: string })?.uid) ?? '') as (typeof TEST_UIDS)[number]));
  });
  const usersAfter = await Promise.all(TEST_UIDS.map((u) => db.collection('users').doc(u).get()));
  const stillSet = usersAfter.filter((d) => BLOCKS.some((b) => d.data()?.[b]) || d.data()?.classesSetForTermStart);

  console.log(`\nafter:   ${stillHeld.length} roster(s) still hold a test account`);
  console.log(`         ${stillSet.length} account(s) still have a block or the term flag set`);
  if (stillHeld.length > 0 || stillSet.length > 0) {
    console.error('\nREFUSING TO CALL THIS DONE: something did not clear.\n');
    process.exit(1);
  }
}

console.log(
  `\nCHECKED ${TEST_UIDS.length} account(s) and ${classes.size} class document(s).` +
    (APPLY ? ' Cleared.' : ' Nothing changed. Re-run with --apply.'),
);
