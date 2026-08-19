/**
 * Source in, candidate days out. This route reads nothing from Firestore and writes
 * nothing anywhere. Publishing is a separate route and a separate deliberate act.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';
import { IngestError, extractSchedule } from '@/lib/ingest/extract';
import { ingestBodySchema } from '@/lib/ingest/requestBody';
import { dayWarnings } from '@/lib/schedule/warnings';
import { daysBetween, displayDate } from '@/lib/schedule/dates';

export const runtime = 'nodejs';
export const maxDuration = 120;

export async function POST(request: Request) {
  try {
    await requireAdmin(request);

    const parsed = ingestBodySchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.issues.map((i) => i.message).join('; ') }, { status: 400 });
    }

    const result = await extractSchedule(parsed.data);
    return NextResponse.json({
      // `display` is here so a client in another package never formats a date itself.
      // One builder, every consumer. Two copies of this would drift the moment one of
      // them reached for toLocaleDateString.
      days: result.days.map((day) => ({
        ...day,
        display: displayDate(day.date),
        warnings: dayWarnings(day.day),
      })),
      // Spans carry their own day count so the review card can say "16 days" without
      // recomputing a date difference in the browser.
      ranges: result.ranges.map((range) => ({
        ...range,
        dayCount: daysBetween(range.startDate, range.endDate),
      })),
      message: result.message,
      rejected: result.rejected,
      attempts: result.attempts,
    });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    if (error instanceof IngestError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    console.error('[ingest]', error);
    return NextResponse.json({ error: 'The ingest call failed. Try again, or paste the text instead.' }, { status: 500 });
  }
}
