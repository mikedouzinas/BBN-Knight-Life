/**
 * The web viewer's setup screen: which classes does this student have, and what could they
 * have.
 *
 * NOT `/api/student/classes`. That route is HQ-656's schedule-photo scanner, it costs an
 * Anthropic call, and it is rate-limited to five attempts a year per student. This one is a
 * plain read and a plain write of the seven block fields, so it has to be a different
 * endpoint or every save would spend a scan.
 *
 * GET also returns the school's class catalogue, which is what makes this usable on the
 * first day: the end-of-year cleanup cleared everyone's classes, so nearly every account
 * arrives empty, and picking from a real list beats typing seven names and seven rooms.
 *
 * The write is scoped to the uid on the verified token and never to anything in the body.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError } from '@/lib/firebase/requireAdmin';
import { requireStudent } from '@/lib/firebase/requireStudent';
import { readCatalogue, readProfile, saveClasses } from '@/lib/firebase/studentStore';
import { BLOCK_LETTERS, type BlockLetter } from '@/lib/student/profile';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const GRADES = new Set(['9', '10', '11', '12', 'teacher']);

export async function GET(request: Request) {
  try {
    const identity = await requireStudent(request);
    const [profile, catalogue] = await Promise.all([readProfile(identity.uid), readCatalogue()]);
    return NextResponse.json({
      classes: profile.classes,
      rooms: profile.rooms,
      grade: profile.grade,
      catalogue,
    });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    return NextResponse.json({ error: (error as Error).message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const identity = await requireStudent(request);
    const body = (await request.json().catch(() => null)) as {
      classes?: Record<string, string>;
      rooms?: Record<string, string>;
      grade?: string | null;
    } | null;
    if (!body) return NextResponse.json({ error: 'Send a JSON body.' }, { status: 400 });

    const classes: Partial<Record<BlockLetter, string>> = {};
    const rooms: Partial<Record<BlockLetter, string>> = {};
    for (const letter of BLOCK_LETTERS) {
      const name = body.classes?.[letter];
      if (typeof name === 'string') classes[letter] = name;
      const room = body.rooms?.[letter];
      if (typeof room === 'string') rooms[letter] = room;
    }

    const grade = typeof body.grade === 'string' && body.grade ? body.grade.toLowerCase() : null;
    if (grade !== null && !GRADES.has(grade)) {
      return NextResponse.json({ error: `Not a grade: ${grade}` }, { status: 400 });
    }

    await saveClasses(identity.uid, { classes, rooms, grade });
    return NextResponse.json({ ok: true });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    return NextResponse.json({ error: (error as Error).message }, { status: 500 });
  }
}
