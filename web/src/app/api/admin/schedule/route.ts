/**
 * What is published for a date. Read-only, and the only read route in the app.
 *
 * The browser tool does not need this: it publishes and shows the result. An agent
 * does, because "is there already something on that day?" is the question that stops
 * it from overwriting a schedule somebody else posted an hour ago.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';
import { adminDb } from '@/lib/firebase/admin';
import { FirestoreScheduleStore } from '@/lib/firebase/firestoreStore';
import { displayDate, isValidIsoDate } from '@/lib/schedule/dates';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    await requireAdmin(request);

    const date = new URL(request.url).searchParams.get('date') ?? '';
    if (!isValidIsoDate(date)) {
      return NextResponse.json({ error: 'date must be YYYY-MM-DD' }, { status: 400 });
    }

    const day = await new FirestoreScheduleStore(adminDb()).readDay(date);
    return NextResponse.json({ date, display: displayDate(date), day, published: day !== null });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    console.error('[schedule]', error);
    return NextResponse.json({ error: 'Could not read that day.' }, { status: 500 });
  }
}
