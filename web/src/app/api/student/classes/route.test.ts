/**
 * The scan route's response CONTRACT.
 *
 * This exists because of a bug that sixty-odd passing tests could not see. `extractStudentClasses`
 * read the student's grade off the sheet, validated it, and returned it as `details`; this route
 * built its JSON field by field and never included that key. So the model spent tokens on a value
 * that stopped at the server, and the app - which reads `details.grade` - rendered nothing. On a
 * device it looked like a missing UI section, and the review screen's Grade row was hunted for
 * hours before anybody suspected the wire format.
 *
 * Every test next door in `extractStudentClasses.test.ts` still passed, and always would have,
 * because they test the extractor's return value. Nothing tested what the route does with it.
 *
 * So the load-bearing test here is `forwards every field the extractor returns`, which fails for
 * ANY key added to `ExtractStudentClassesResult` and not forwarded - not just for `details`.
 * Asserting `details` alone would have fixed the instance and left the next one to be found on a
 * phone.
 */
import { NextRequest } from 'next/server';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { ExtractStudentClassesResult } from '@/lib/ingest/extractStudentClasses';

const requireStudent = vi.fn();
const spendClassSetupAttempt = vi.fn();
const refundClassSetupAttempt = vi.fn();
const extractStudentClasses = vi.fn();

vi.mock('@/lib/firebase/requireStudent', () => ({ requireStudent: (r: Request) => requireStudent(r) }));
vi.mock('@/lib/firebase/studentBudget', () => ({
  spendClassSetupAttempt: (uid: string) => spendClassSetupAttempt(uid),
  refundClassSetupAttempt: (uid: string) => refundClassSetupAttempt(uid),
}));
vi.mock('@/lib/ingest/extractStudentClasses', () => ({
  extractStudentClasses: (body: unknown) => extractStudentClasses(body),
}));

const { POST } = await import('./route');

/**
 * A complete extractor result. Written out in full rather than with `Partial<>` on purpose: the
 * type annotation is what makes a newly added field a COMPILE error here, which is the first of
 * the two guards. The runtime key comparison below is the second, for a field added without the
 * type being tightened.
 */
const FULL_RESULT: ExtractStudentClassesResult = {
  classes: [{ block: 'a', subject: 'AP English Masks', teacher: 'Ms. Lieberman', room: '285' }],
  lunch: { monday: 2, tuesday: 2, wednesday: 1, thursday: 2, friday: 1 },
  details: { grade: '11' },
  message: 'Read five courses and two free blocks.',
  rejected: [],
  skipped: [],
  attempts: 1,
};

function scanRequest() {
  return new NextRequest('https://www.mikeveson.com/knight-life/api/student/classes', {
    method: 'POST',
    body: JSON.stringify({ attachments: [{ mediaType: 'image/jpeg', data: 'abc' }] }),
    headers: { 'Content-Type': 'application/json' },
  });
}

beforeEach(() => {
  vi.clearAllMocks();
  requireStudent.mockResolvedValue({ uid: 'student-1' });
  spendClassSetupAttempt.mockResolvedValue({ remaining: 4, resetsAt: '2027-09-01T00:00:00.000Z' });
  // Must RESOLVE, not return undefined. The route does `refundClassSetupAttempt(uid).catch(...)`,
  // so a bare `vi.fn()` throws a TypeError inside the route's own error handler - and the refund
  // assertion below still passed, because the spy had been called before the throw. A green test
  // over a throwing route is worse than no test.
  refundClassSetupAttempt.mockResolvedValue(undefined);
  extractStudentClasses.mockResolvedValue(FULL_RESULT);
});

describe('POST /api/student/classes response contract', () => {
  it('forwards every field the extractor returns', async () => {
    const body = await (await POST(scanRequest())).json();

    // The whole point. A key present on the extractor's result and absent from the response is
    // work the server did and threw away - which is what happened to `details`.
    for (const key of Object.keys(FULL_RESULT) as (keyof ExtractStudentClassesResult)[]) {
      expect(body, `the route dropped "${key}" from its response`).toHaveProperty(key);
      expect(body[key], `the route changed the value of "${key}"`).toEqual(FULL_RESULT[key]);
    }
  });

  it('sends the grade the app actually reads', async () => {
    const body = await (await POST(scanRequest())).json();

    // The app's own read, spelled the way ScheduleScanVC spells it. Keeping this alongside the
    // general test states the shape the client depends on, so a future reshuffle of `details`
    // into something flatter fails here rather than on a phone.
    expect(body.details.grade).toBe('11');
  });

  it('reports how many scans the student has left, not the extractor result', async () => {
    const body = await (await POST(scanRequest())).json();
    expect(body.remainingScans).toBe(4);
  });

  it('refuses without spending anything when the budget is gone', async () => {
    spendClassSetupAttempt.mockResolvedValue(null);

    const response = await POST(scanRequest());
    const body = await response.json();

    expect(response.status).toBe(429);
    expect(body.budgetExhausted).toBe(true);
    // The expensive call must not happen once the budget says no.
    expect(extractStudentClasses).not.toHaveBeenCalled();
  });

  it('refunds the attempt when the failure was not the student fault', async () => {
    extractStudentClasses.mockRejectedValue(Object.assign(new Error('Overloaded'), { status: 529 }));

    const response = await POST(scanRequest());

    expect(response.status).toBe(500);
    expect(refundClassSetupAttempt).toHaveBeenCalledWith('student-1');
  });
});
