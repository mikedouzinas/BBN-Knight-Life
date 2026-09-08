/**
 * One student's schedule, for a date and for the week around it.
 *
 * The date arrives from the browser rather than being read off the server clock. The
 * server runs in UTC on Vercel, so at 9pm in Massachusetts `new Date()` is already
 * tomorrow there, and a student checking tonight's homework would be shown the wrong day.
 * The client knows what day it is where the student is standing; it is the only thing that
 * does.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError } from '@/lib/firebase/requireAdmin';
import { requireStudent } from '@/lib/firebase/requireStudent';
import { readProfile, readSchoolYear } from '@/lib/firebase/studentStore';
import { resolveDay, weekOf } from '@/lib/schedule/schoolDay';
import { ISO_DATE_RE, displayDate } from '@/lib/schedule/dates';
import { isEmptyProfile, renderForStudent } from '@/lib/student/profile';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const identity = await requireStudent(request);

    const date = new URL(request.url).searchParams.get('date') ?? '';
    if (!ISO_DATE_RE.test(date)) {
      return NextResponse.json({ error: 'Pass ?date=YYYY-MM-DD.' }, { status: 400 });
    }

    const [year, profile] = await Promise.all([readSchoolYear(), readProfile(identity.uid)]);

    const day = (iso: string) => {
      const resolved = resolveDay(iso, year);
      return {
        date: iso,
        label: displayDate(iso),
        source: resolved.source,
        closed: resolved.day.type === 'noschool',
        reason: resolved.reason ?? resolved.day.reason ?? null,
        imageUrl: resolved.day.type === 'image' ? resolved.day.imageUrl ?? null : null,
        rows: renderForStudent(resolved.day, profile),
      };
    };

    return NextResponse.json({
      setUp: !isEmptyProfile(profile),
      grade: profile.grade,
      today: day(date),
      week: weekOf(date).map(day),
    });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    return NextResponse.json({ error: (error as Error).message }, { status: 500 });
  }
}
