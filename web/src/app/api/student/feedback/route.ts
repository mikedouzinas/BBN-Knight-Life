/**
 * A student says something went wrong, in their own words.
 *
 * WHY THIS EXISTS AND WHY IT IS SMALL
 *
 * The schedule scan ships as beta into the first week of the school year, and that week is the
 * only time ~645 students will each photograph a sheet nobody here has seen. Whatever it gets
 * wrong, it gets wrong then. A report that is not captured in that window is gone: the student
 * fixes their schedule by hand, never mentions it, and the failure is invisible.
 *
 * So this is deliberately the CAPTURE half only, with no admin UI yet (HQ-923). The perishable
 * thing is the report; a page to read them on is not perishable and can follow.
 *
 * Written with the Admin SDK, which bypasses security rules, so `feedback` needs no rule opening
 * it to students - and one student cannot read another's report, which matters because the free
 * text will contain names, teachers, and whatever else they type.
 */
import { NextResponse } from 'next/server';
import { z } from 'zod';
import { adminDb } from '@/lib/firebase/admin';
import { UnauthorizedError } from '@/lib/firebase/requireAdmin';
import { requireStudent } from '@/lib/firebase/requireStudent';

export const runtime = 'nodejs';

const bodySchema = z.object({
  /**
   * Capped at 2000 characters. Long enough for a real description of what a sheet looked like and
   * what came back; short enough that one student cannot write a document into the collection.
   */
  message: z.string().trim().min(1, 'Say what went wrong.').max(2000, 'That is too long - 2000 characters at most.'),
  /** Where they were when they sent it, e.g. "schedule-scan". Free-form and untrusted. */
  context: z.string().trim().max(120).optional(),
  /** App version, so a report can be tied to a build rather than guessed at. */
  appVersion: z.string().trim().max(40).optional(),
});

export async function POST(request: Request) {
  try {
    const student = await requireStudent(request);

    const parsed = bodySchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.issues.map((i) => i.message).join('; ') }, { status: 400 });
    }

    // Auto-id rather than keyed on uid: a student who hits two different problems in one week has
    // two reports, and keying on uid would silently replace the first with the second.
    await adminDb()
      .collection('feedback')
      .add({
        uid: student.uid,
        email: student.email,
        message: parsed.data.message,
        context: parsed.data.context ?? null,
        appVersion: parsed.data.appVersion ?? null,
        createdAt: new Date().toISOString(),
        // Unread until somebody says otherwise. Set now so the field exists to query on from the
        // first report rather than being added later, when the early ones would be missing it.
        handled: false,
      });

    return NextResponse.json({ ok: true });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    console.error('[student-feedback]', error);
    return NextResponse.json({ error: "Couldn't send that. Try again." }, { status: 500 });
  }
}
