/**
 * Source in, candidate days out. This route reads nothing from Firestore and writes
 * nothing anywhere. Publishing is a separate route and a separate deliberate act.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';
import { IngestError, extractSchedule } from '@/lib/ingest/extract';
import { ingestBodySchema } from '@/lib/ingest/requestBody';
import { dayWarnings } from '@/lib/schedule/warnings';

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
      days: result.days.map((day) => ({ ...day, warnings: dayWarnings(day.day) })),
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
