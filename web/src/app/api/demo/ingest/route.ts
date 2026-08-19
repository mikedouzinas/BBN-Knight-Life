/**
 * The sandbox planner. A separate route, not the real one behind a flag.
 *
 * It imports no Firestore client, holds no admin check because it has nothing to guard,
 * and there is no code path from here to a write. Text only, no uploads, and off unless
 * DEMO_ENABLED is exactly "true", because it still spends Anthropic tokens, and it has no
 * sign-in in front of it.
 */
import { NextResponse } from 'next/server';
import { IngestError, extractSchedule } from '@/lib/ingest/extract';
import { ingestBodySchema } from '@/lib/ingest/requestBody';
import { dayWarnings } from '@/lib/schedule/warnings';

export const runtime = 'nodejs';
export const maxDuration = 120;

export async function POST(request: Request) {
  if (process.env.DEMO_ENABLED !== 'true') {
    return NextResponse.json({ error: 'The demo is switched off.' }, { status: 404 });
  }
  try {
    const parsed = ingestBodySchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.issues.map((i) => i.message).join('; ') }, { status: 400 });
    }
    if (parsed.data.attachments?.length) {
      return NextResponse.json({ error: 'The demo takes pasted text only. The real tool takes PDFs and photos.' }, { status: 400 });
    }
    if ((parsed.data.text ?? '').length > 6000) {
      return NextResponse.json({ error: 'That is longer than the demo accepts. Try one day of a schedule.' }, { status: 400 });
    }

    const result = await extractSchedule(parsed.data);
    return NextResponse.json({
      days: result.days.map((day) => ({ ...day, warnings: dayWarnings(day.day) })),
      ranges: result.ranges,
      message: result.message,
      rejected: result.rejected,
      attempts: result.attempts,
    });
  } catch (error) {
    if (error instanceof IngestError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    console.error('[demo ingest]', error);
    return NextResponse.json({ error: 'That did not work. Try again.' }, { status: 500 });
  }
}
