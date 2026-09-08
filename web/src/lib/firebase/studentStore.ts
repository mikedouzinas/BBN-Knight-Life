/**
 * Everything the student viewer reads, server side.
 *
 * All of it goes through the Admin SDK, which means `firebase/firestore.rules` is not
 * involved and does not need to change. That matters: the rules were tightened in HQ-601
 * after the whole database was readable by any signed-in account, and a student viewer is
 * not a reason to loosen them again.
 *
 * The one document this writes is `users/{uid}`, and only ever the uid of the person whose
 * ID token was verified on the request.
 */
import 'server-only';
import { adminDb } from './admin';
import { CANONICAL_DOC, BREAK_DOC } from './firestoreStore';
import {
  parseBreaks,
  specialDaysByIso,
  type SchoolYearInput,
  toIsoTerm,
  type WeekdayId,
} from '@/lib/schedule/schoolDay';
import type { ScheduleDay } from '@/lib/schedule/types';
import { profileFromUserDoc, type StudentProfile, BLOCK_LETTERS, type BlockLetter } from '@/lib/student/profile';

export const CATALOGUE_YEAR = '2026-2027';

export interface CatalogueEntry {
  id: string;
  name: string;
  block: BlockLetter;
  teacher: string;
  room: string;
  period: string;
}

const WEEKDAYS: WeekdayId[] = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];


/**
 * The whole school year in one read set.
 *
 * Four documents, fetched together. The shipped app makes the same four reads on every
 * launch; doing them in parallel here is the difference between a page that paints in one
 * round trip and one that paints in four.
 */
export async function readSchoolYear(): Promise<SchoolYearInput> {
  const db = adminDb();
  const [specialSnap, regularSnap, breakSnap, termSnap] = await Promise.all([
    db.doc(CANONICAL_DOC).get(),
    db.doc('schedules/regular').get(),
    db.doc(BREAK_DOC).get(),
    db.doc('schedules/term').get(),
  ]);

  const regularRaw = (regularSnap.data() ?? {}) as Record<string, ScheduleDay['blocks']>;
  const regularWeek: SchoolYearInput['regularWeek'] = {};
  for (const day of WEEKDAYS) {
    const blocks = regularRaw[day];
    if (Array.isArray(blocks) && blocks.length) regularWeek[day] = blocks;
  }

  // The term document is optional. Absent means "unknown", and unknown never closes a day:
  // a missing document must not tell 640 students there is no school.
  const term = termSnap.exists ? (termSnap.data() as { start?: string; end?: string }) : null;

  return {
    specialDays: specialDaysByIso(specialSnap.data() ?? {}),
    regularWeek,
    breaks: parseBreaks((breakSnap.data() ?? {}) as Record<string, { reason?: string }>),
    term: toIsoTerm(term),
  };
}

export async function readProfile(uid: string): Promise<StudentProfile> {
  const snap = await adminDb().collection('users').doc(uid).get();
  return profileFromUserDoc(snap.data() as Record<string, unknown> | undefined);
}

export async function readCatalogue(): Promise<CatalogueEntry[]> {
  const snap = await adminDb().doc(`catalogue/${CATALOGUE_YEAR}`).get();
  const classes = (snap.data()?.classes ?? []) as CatalogueEntry[];
  return Array.isArray(classes) ? classes : [];
}

/**
 * Save this student's classes.
 *
 * `merge`, never `set`. The user document holds fields this app does not know about
 * (notifications, locker number, the Google photo flag) and the iOS app writes the whole
 * dictionary back. Replacing the document from here would silently drop whatever the app
 * added since, which is the same class of bug as the special-day document in
 * firestoreStore.
 *
 * Only the seven block letters, the rooms for them, and grade are writable. A field the
 * caller sends that is not in that set is ignored rather than trusted.
 *
 * That allowlist is what keeps this route away from `classSetupSubmissionsRemaining` and
 * `classSetupBudgetResetsAt`, the scan-budget fields HQ-656 had to move off this document.
 * The Firestore rules exclude them from client writes, but this runs through the Admin SDK
 * and the rules do not apply, so the allowlist is the only thing standing between a request
 * body and a student granting themselves unlimited Anthropic calls. Build the patch from a
 * fixed list of keys; never spread the caller's object.
 */
export async function saveClasses(
  uid: string,
  input: { classes: Partial<Record<BlockLetter, string>>; rooms: Partial<Record<BlockLetter, string>>; grade: string | null },
): Promise<void> {
  const patch: Record<string, string> = {};
  for (const letter of BLOCK_LETTERS) {
    patch[letter] = (input.classes[letter] ?? '').toString().slice(0, 120).trim();
    const room = (input.rooms[letter] ?? '').toString().slice(0, 40).trim();
    if (room) patch[`room-${letter.toLowerCase()}`] = room;
  }
  if (input.grade) patch.grade = input.grade.toString().slice(0, 10).trim();
  patch.uid = uid;

  await adminDb().collection('users').doc(uid).set(patch, { merge: true });
}
