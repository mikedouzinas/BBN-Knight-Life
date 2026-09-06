/**
 * Clear `classesSetForTermStart` for any student the app has marked as set up who has no classes.
 *
 * THE STATE THIS REPAIRS, AND WHY THE APP CREATES IT
 *
 * `AuthVC.startNewYearSetup` records the term as set up at the moment last year's classes are
 * CLEARED, not at the moment new ones are saved:
 *
 *     case .success:
 *         Self.recordTermSetup(termStart)          // stamped here
 *         if thenScan { self.presentScheduleScan() }
 *         else { ProgressHUD.succeed("Classes cleared - head to Settings...") }
 *
 * So a student who taps "Scan My Schedule" and backs out of the scanner, or taps "Set Up by Hand"
 * and never opens Settings, ends with zero classes AND the flag stamped. `AuthVC` then reads
 * `recordedFor == start` on every future launch and returns before prompting. They are stranded:
 * seven blank blocks, for the rest of the term, with nothing offering to fix it.
 *
 * Two real students were found in exactly this state on 2026-09-06, two days before the term
 * starts, from a population where only two accounts had ever reached the prompt. Once ~640 students
 * meet that prompt on the first morning, this is the failure most likely to happen at scale.
 *
 * WHY THIS IS A SERVER-SIDE SWEEP RATHER THAN THE FIX
 *
 * The fix is in the app: record the term after classes are actually set, not after they are
 * cleared. That is an App Store release, and it cannot land before the first morning. This clears
 * the flag so the app asks again on the student's next launch, which is what it would have done
 * had it never been stamped. It is idempotent and safe to run repeatedly - run it through Tuesday
 * as students meet the prompt.
 *
 * WHY CLEARING IS THE RIGHT REPAIR
 *
 * Being re-prompted is the correct behaviour for a student with no classes: the prompt itself is
 * how they set up, and "Not Now" is a real answer that deliberately records nothing. A student who
 * wants to stay empty taps it and is asked again next launch, which costs them one tap and is far
 * cheaper than a term of blank blocks.
 *
 * USAGE
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     npx tsx --conditions=react-server scripts/unstrand-students.mts [--apply]
 *
 * Dry run by default.
 *
 * FALSIFIED 2026-09-06: inverted the class test to `hasAnyClass` (select students who DO have
 * classes) and ran the dry run against a database where 0 students had any class set.
 *     stranded: 0 student(s)
 *     CHECKED 640 user(s). Nothing to repair.
 *   exit 0
 * Restored, and the real run found the two.
 */
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const APPLY = process.argv.includes('--apply');
const BLOCKS = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('\nGOOGLE_APPLICATION_CREDENTIALS is not set.\n');
  process.exit(1);
}
if (!getApps().length) {
  initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'))) });
}
const db = getFirestore();

console.log(`\n${APPLY ? '*** APPLYING ***' : 'DRY RUN - nothing will change'}\n`);

const term = await db.collection('schedules').doc('term').get();
const start = term.data()?.start as string | undefined;
if (!start) {
  console.error('\nREFUSING: schedules/term has no `start`. Nothing can be judged against it.\n');
  process.exit(1);
}
console.log(`term:     start ${start}`);

const users = await db.collection('users').get();

// Stamped for the CURRENT term specifically. A flag left over from a previous year is not a
// stranded student - the app compares against the current start and prompts them anyway.
const stranded = users.docs.filter((d) => {
  const x = d.data();
  const hasAnyClass = BLOCKS.some((b) => typeof x[b] === 'string' && (x[b] as string).includes('~'));
  return x.classesSetForTermStart === start && !hasAnyClass;
});

const stale = users.docs.filter((d) => {
  const v = d.data().classesSetForTermStart;
  return typeof v === 'string' && v !== '' && v !== start;
});

console.log(`users:    ${users.size} total`);
console.log(`          ${stale.length} stamped for a DIFFERENT term (left alone - they get prompted anyway)`);
console.log(`\nstranded: ${stranded.length} student(s) marked set up for ${start} with no classes`);
for (const d of stranded) {
  const x = d.data();
  console.log(`    ${d.id}  grade=${x.grade ?? '?'}  locker=${x.lockerNum ?? ''}`);
}

if (APPLY && stranded.length > 0) {
  for (const d of stranded) await d.ref.set({ classesSetForTermStart: '' }, { merge: true });

  const after = await db.collection('users').get();
  const remaining = after.docs.filter((d) => {
    const x = d.data();
    const hasAnyClass = BLOCKS.some((b) => typeof x[b] === 'string' && (x[b] as string).includes('~'));
    return x.classesSetForTermStart === start && !hasAnyClass;
  });
  console.log(`\nafter:    ${remaining.length} still stranded`);
  if (remaining.length > 0) {
    console.error('\nREFUSING TO CALL THIS DONE: some flags did not clear.\n');
    process.exit(1);
  }
}

console.log(
  `\nCHECKED ${users.size} user(s).` +
    (stranded.length === 0
      ? ' Nothing to repair.'
      : APPLY
        ? ` ${stranded.length} student(s) will be prompted on their next launch.`
        : ' Nothing changed. Re-run with --apply.'),
);
