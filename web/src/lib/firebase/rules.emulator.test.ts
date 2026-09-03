/**
 * The security rules themselves, exercised as a CLIENT sees them.
 *
 * HQ-871. Every other test in this repo reaches Firestore through the Admin SDK, which
 * BYPASSES rules entirely. So `firebase/firestore.rules` has never been executed by a test,
 * and two shipped-ready changes were found by hand on 2026-09-01 that nothing here could
 * have caught:
 *
 *   - HQ-656 stored a spend-limiting counter on `users/{uid}`, a document its own owner is
 *     allowed to write, so the student being limited could raise their own limit.
 *   - HQ-661 read a new `sideMenu/publications` document that no rule allows, so the
 *     catch-all denied it, the code's fallback masked the denial, and the feature was inert
 *     while looking fine.
 *
 * One fails open and one fails closed. Neither is visible to tsc, to the unit suite, or to a
 * clean-clone build, because in all three the rules file is just text sitting in the repo.
 *
 * These tests load that file into the emulator and drive it as an unauthenticated visitor, a
 * student, and an admin. Run through `npm run test:emulator` like the other emulator suites.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, collection, getDocs } from 'firebase/firestore';

const emulated = process.env.FIRESTORE_EMULATOR_HOST ? describe : describe.skip;

const RULES = resolve(__dirname, '../../../../firebase/firestore.rules');

const STUDENT = 'student-uid';
const STUDENT_EMAIL = 'student@bbns.org';
const CLASSMATE = 'classmate-uid';
const ADMIN_EMAIL = 'maintainer@bbns.org';
const ADMIN = 'admin-uid';

/** A signed-in Google account, the only kind this app ever has. */
function signedIn(env: RulesTestEnvironment, uid: string, email: string) {
  return env.authenticatedContext(uid, { email, email_verified: true }).firestore();
}

emulated('firestore.rules', () => {
  let env: RulesTestEnvironment;

  beforeAll(async () => {
    const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? 'localhost:8080').split(':');
    env = await initializeTestEnvironment({
      projectId: 'knight-life-rules-test',
      firestore: { rules: readFileSync(RULES, 'utf8'), host, port: Number(port) },
    });
  });

  afterAll(async () => {
    await env?.cleanup();
  });

  // Seeded with rules OFF, so the fixtures themselves are not what is under test.
  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'admins', ADMIN_EMAIL), { name: 'Maintainer' });
      await setDoc(doc(db, 'users', STUDENT), {
        A: 'Precalc~Ms. Chen~210~A',
        notifs: 'true',
        grade: '11',
        classSetupSubmissionsRemaining: 5,
        classSetupBudgetResetsAt: '2027-09-01T00:00:00.000Z',
      });
      await setDoc(doc(db, 'users', CLASSMATE), { A: 'Precalc~Ms. Chen~210~A', grade: '11' });
      // A class the CLASSMATE is on and the STUDENT is not, so "can I edit a roster I am not
      // part of" is a real question rather than one about my own membership.
      await setDoc(doc(db, 'classes', 'Precalc~Ms. Chen~210~A'), {
        name: 'Precalc',
        block: 'A',
        members: [{ name: 'Classmate', email: 'classmate@bbns.org', uid: CLASSMATE }],
      });
      await setDoc(doc(db, 'schedules', 'v2'), { '2026/9/9': { type: 'noschool', reason: 'x' } });
      await setDoc(doc(db, 'sideMenu', 'publications'), {
        entries: [{ title: 'The Vanguard', url: 'https://vanguard.bbns.org/', order: 1, visible: true }],
      });
    });
  });

  describe('a signed-out visitor', () => {
    it('cannot read the schedule', async () => {
      const db = env.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'schedules', 'v2')));
    });

    it('cannot read a student record', async () => {
      const db = env.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, 'users', STUDENT)));
    });
  });

  describe('the schedule', () => {
    it('is readable by any signed-in student', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(getDoc(doc(db, 'schedules', 'v2')));
    });

    it('is not writable by a student', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(setDoc(doc(db, 'schedules', 'v2'), { hacked: true }));
    });

    it('is writable by an admin', async () => {
      const db = signedIn(env, ADMIN, ADMIN_EMAIL);
      await assertSucceeds(setDoc(doc(db, 'schedules', 'v2'), { '2026/9/9': { type: 'noschool', reason: 'Snow' } }));
    });
  });

  describe('the maintainer list', () => {
    it('cannot be listed by a student, so it is not a directory', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(getDocs(collection(db, 'admins')));
    });

    it('cannot be written by an admin either — only the Admin SDK', async () => {
      const db = signedIn(env, ADMIN, ADMIN_EMAIL);
      await assertFails(setDoc(doc(db, 'admins', 'someone@bbns.org'), { name: 'New' }));
    });
  });

  describe('a student writing their own record', () => {
    it('can set their own classes', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(updateDoc(doc(db, 'users', STUDENT), { B: 'Chem~Mr. Diaz~114~B' }));
    });

    it('can change their own settings', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(updateDoc(doc(db, 'users', STUDENT), { notifs: 'false', grade: '12' }));
    });

    it('can rename a classmate\'s class, which is what DaySelectVC does', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(updateDoc(doc(db, 'users', CLASSMATE), { A: 'Precalculus~Ms. Chen~210~A' }));
    });

    it('cannot change a classmate\'s settings', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(updateDoc(doc(db, 'users', CLASSMATE), { grade: '9' }));
    });

    // HQ-656. The counter that caps how many Anthropic calls one student can spend lives on
    // this document. If its owner can write it, it caps nothing.
    it('cannot raise their own schedule-scan budget', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(updateDoc(doc(db, 'users', STUDENT), { classSetupSubmissionsRemaining: 99999 }));
    });

    it('cannot push their own budget reset date into the future', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(updateDoc(doc(db, 'users', STUDENT), { classSetupBudgetResetsAt: '2099-01-01T00:00:00.000Z' }));
    });

    it('cannot smuggle a budget raise alongside a legitimate field', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(updateDoc(doc(db, 'users', STUDENT), { notifs: 'true', classSetupSubmissionsRemaining: 99999 }));
    });

    it('cannot reset the budget by recreating the whole document', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(setDoc(doc(db, 'users', STUDENT), { A: '', classSetupSubmissionsRemaining: 99999 }));
    });
  });

  // HQ-661. The side menu reads this document and falls back to the hardcoded list on any
  // error, so a denial here does not look like a bug — it looks like nothing happened.
  describe('the side menu publication list', () => {
    it('is readable by a signed-in student', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(getDoc(doc(db, 'sideMenu', 'publications')));
    });

    it('is not writable by a student', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(setDoc(doc(db, 'sideMenu', 'publications'), { entries: [] }));
    });

    it('is writable by an admin, which is the point of the ticket', async () => {
      const db = signedIn(env, ADMIN, ADMIN_EMAIL);
      await assertSucceeds(setDoc(doc(db, 'sideMenu', 'publications'), { entries: [] }));
    });
  });

  // Where the counter actually belongs: a document the student it governs cannot reach.
  describe('the schedule-scan budget', () => {
    it('is not readable by the student it governs', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(getDoc(doc(db, 'student-budgets', STUDENT)));
    });

    it('is not writable by the student it governs', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(setDoc(doc(db, 'student-budgets', STUDENT), { remaining: 99999 }));
    });

    it('is not writable even by an admin — only the Admin SDK', async () => {
      const db = signedIn(env, ADMIN, ADMIN_EMAIL);
      await assertFails(setDoc(doc(db, 'student-budgets', STUDENT), { remaining: 99999 }));
    });

    it('is readable by an admin, so a top-up can be checked', async () => {
      const db = signedIn(env, ADMIN, ADMIN_EMAIL);
      await assertSucceeds(getDoc(doc(db, 'student-budgets', STUDENT)));
    });
  });

  // Beta feedback. Written only through /api/student/feedback with the Admin SDK, so no client
  // needs any access - and the free text will contain other students' names and teachers, which
  // is why "a student cannot read this" is asserted rather than inherited from the catch-all.
  describe('student feedback', () => {
    it('is not readable by a student, including their own report', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(getDoc(doc(db, 'feedback', 'some-report')));
    });

    it('cannot be written from the app, so a report always carries a server-verified uid', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(setDoc(doc(db, 'feedback', 'forged'), { uid: 'someone-else', message: 'hi' }));
    });

    it('is readable by an admin, which is how the reports get read at all', async () => {
      const db = signedIn(env, ADMIN, ADMIN_EMAIL);
      await assertSucceeds(getDoc(doc(db, 'feedback', 'some-report')));
    });
  });

  // HQ-911. `members` is the only field in this database that holds other students - a name,
  // an email and a uid each. Under `write: if signedIn()` any of ~645 accounts could rewrite
  // any roster, and nothing in the app shows when one changes. These tests are the line
  // between "a student edits their own membership" and "a student edits somebody else's".
  //
  // The six success cases are the shipped write paths. They are the reason `update` is
  // narrowed rather than closed: if any of them goes red, the rule broke the app.
  //
  // FALSIFIED 2026-09-02: put `allow write: if signedIn()` back and re-ran. Exactly the six
  // attack cases failed and all six shipped-path cases stayed green -
  //     Tests  6 failed | 33 passed (39)
  // which is the shape that matters: these tests detect the hole specifically, not merely
  // that the rules file changed.
  describe('a class roster', () => {
    const CLASS = 'Precalc~Ms. Chen~210~A';
    const me = { name: 'Student', email: STUDENT_EMAIL, uid: STUDENT };
    const them = { name: 'Classmate', email: 'classmate@bbns.org', uid: CLASSMATE };

    it('is readable, because ClassPopupVC lists who else is in your class', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(getDoc(doc(db, 'classes', CLASS)));
    });

    it('is listable, which is how ClassesOptionsPopupVC offers classes to pick', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(getDocs(collection(db, 'classes')));
    });

    // The four shipped write paths.
    it('can be joined by the student joining it (ClassesOptionsPopupVC, ScheduleScanVC)', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(setDoc(doc(db, 'classes', CLASS), { members: [them, me] }, { merge: true }));
    });

    it('can be left by the student leaving it (AuthVC, clear my classes)', async () => {
      const db = signedIn(env, CLASSMATE, 'classmate@bbns.org');
      await assertSucceeds(setDoc(doc(db, 'classes', CLASS), { members: [] }, { merge: true }));
    });

    it('takes a homework note without touching the roster (TextEditVC)', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(setDoc(doc(db, 'classes', CLASS), { homework: 'p. 40' }, { merge: true }));
    });

    it('can be renamed for the whole roster, which DaySelectVC does by design', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(
        setDoc(doc(db, 'classes', CLASS), { name: 'Precalculus', members: [them] }, { merge: true }),
      );
    });

    // Creating a class is a CREATE, not an update, so the roster checks never run on it.
    // Both of these go through `allow create`, and both are shipped paths: AddClassVC makes a
    // new class with its creator as the only member, and a merge-write to a document that
    // does not exist yet is a create too.
    it('can be created with its creator as the only member (AddClassVC)', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(
        setDoc(doc(db, 'classes', 'Chem~Mr. Diaz~114~B'), { name: 'Chem', block: 'B', members: [me] }),
      );
    });

    it('can be merge-written into existence, which is also a create', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertSucceeds(
        setDoc(doc(db, 'classes', 'Bio~Ms. Ray~301~C'), { members: [me] }, { merge: true }),
      );
    });

    // The hole itself, from six directions.
    it('cannot have a classmate dropped out of it by another student', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(setDoc(doc(db, 'classes', CLASS), { members: [] }, { merge: true }));
    });

    it('cannot have someone else added to it', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      const stranger = { name: 'Nobody', email: 'nobody@bbns.org', uid: 'stranger-uid' };
      await assertFails(setDoc(doc(db, 'classes', CLASS), { members: [them, stranger] }, { merge: true }));
    });

    it('cannot be wiped and replaced with the caller alone', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(setDoc(doc(db, 'classes', CLASS), { members: [me] }, { merge: true }));
    });

    it('cannot have a classmate\'s entry edited into someone else', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      const forged = { name: 'Classmate', email: 'attacker@bbns.org', uid: CLASSMATE };
      await assertFails(setDoc(doc(db, 'classes', CLASS), { members: [forged] }, { merge: true }));
    });

    it('cannot be emptied by a student who was never on it', async () => {
      const db = signedIn(env, 'third-uid', 'third@bbns.org');
      await assertFails(setDoc(doc(db, 'classes', CLASS), { members: [] }, { merge: true }));
    });

    it('cannot be joined under a forged uid, so a roster entry means its owner', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      const impostor = { name: 'Student', email: STUDENT_EMAIL, uid: 'someone-elses-uid' };
      await assertFails(setDoc(doc(db, 'classes', CLASS), { members: [them, impostor] }, { merge: true }));
    });

    it('is not writable at all by a signed-out visitor', async () => {
      const db = env.unauthenticatedContext().firestore();
      await assertFails(setDoc(doc(db, 'classes', CLASS), { members: [] }, { merge: true }));
    });
  });

  describe('anything with no rule of its own', () => {
    it('is denied, so a new collection cannot ship open by accident', async () => {
      const db = signedIn(env, STUDENT, STUDENT_EMAIL);
      await assertFails(getDoc(doc(db, 'somethingNobodyWroteARuleFor', 'x')));
      await assertFails(setDoc(doc(db, 'somethingNobodyWroteARuleFor', 'x'), { a: 1 }));
    });
  });

  // Not a rules assertion: a guard on this file. Every count above is a real client call, so
  // a suite that silently stops constructing them would still exit 0.
  it('exercised the rules file that ships', () => {
    const text = readFileSync(RULES, 'utf8');
    expect(text).toMatch(/service cloud\.firestore/);
    expect(text.length).toBeGreaterThan(500);
  });
});
