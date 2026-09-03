/**
 * HQ-656: a student's own schedule photo in, candidate classes out. Reads nothing from
 * Firestore beyond the student's own budget fields, and writes nothing to their A-G
 * classes - same rule as the admin ingest route: the model proposes, a person confirms.
 * Saving a confirmed class goes through the app's existing class-picker write path,
 * unchanged by this route.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError } from '@/lib/firebase/requireAdmin';
import { requireStudent } from '@/lib/firebase/requireStudent';
import { refundClassSetupAttempt, spendClassSetupAttempt } from '@/lib/firebase/studentBudget';
import { IngestError } from '@/lib/ingest/extract';
import { extractStudentClasses } from '@/lib/ingest/extractStudentClasses';
import { studentClassesBodySchema } from '@/lib/ingest/requestBody';

export const runtime = 'nodejs';
export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    const student = await requireStudent(request);

    const parsed = studentClassesBodySchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.issues.map((i) => i.message).join('; ') }, { status: 400 });
    }

    // Spent before the model call, not after - the cost is the attempt, not the result.
    const budget = await spendClassSetupAttempt(student.uid);
    if (!budget) {
      return NextResponse.json(
        {
          error:
            'You are out of schedule scans for this year. You can still set your classes by hand in Settings, same as always.',
          budgetExhausted: true,
        },
        { status: 429 },
      );
    }

    // A scan the STUDENT could not have prevented does not cost them one of their five.
    //
    // The budget is spent up front on purpose - the Anthropic call is what costs money, so it
    // has to be paid for before it is made rather than after it succeeds. But that reasoning
    // only covers failures the student caused, like an unreadable photo. A 529 Overloaded is
    // our capacity problem, and the first week of school is exactly when hundreds of students
    // scan within the same hour and exactly when that response shows up. Burning a fifth of a
    // student's yearly allowance because the API was busy is the wrong answer, so it is
    // refunded and they are told to try again.
    let result;
    try {
      result = await extractStudentClasses(parsed.data);
    } catch (error) {
      if (!(error instanceof IngestError)) {
        await refundClassSetupAttempt(student.uid).catch((refundError) => {
          // Report the original failure, not this one. A failed refund costs the student one
          // scan; swallowing the real error would cost us the ability to diagnose it.
          console.error('[student-classes] refund failed', refundError);
        });
      }
      throw error;
    }

    return NextResponse.json({
      classes: result.classes,
      // Which lunch wave on which weekday, read off the same photo. This is why a student no
      // longer has to set five lunch preferences by hand in Settings.
      lunch: result.lunch,
      // Non-course rows the model tried to save as classes. The app never shows these; they
      // are returned so a prompt starting to drift is visible in a log rather than only in
      // some student's schedule.
      skipped: result.skipped,
      message: result.message,
      rejected: result.rejected,
      attempts: result.attempts,
      remainingScans: budget.remaining,
    });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    if (error instanceof IngestError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    console.error('[student-classes]', error);
    return NextResponse.json(
      { error: 'That scan failed. Try again, or enter your classes by hand in Settings.' },
      { status: 500 },
    );
  }
}
