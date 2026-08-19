/**
 * The second route in this app that writes, and the one with the widest blast radius.
 *
 * A day affects a day. A range can silence months: a span written to `schedules/break` is
 * what the app checks before falling back to any schedule at all, so a wrong one takes school
 * off the calendar for every student for as long as it lasts.
 *
 * It re-validates from scratch for the same reason the day route does, and additionally
 * refuses a span that overlaps one already published, because two breaks covering one day
 * disagree and the app shows whichever it happens to read first.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';
import { adminDb } from '@/lib/firebase/admin';
import { FirestoreRangeStore } from '@/lib/firebase/firestoreStore';
import { ScheduleValidationError, publishRange } from '@/lib/schedule/publish';
import { rangeBodySchema } from '@/lib/ingest/requestBody';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const identity = await requireAdmin(request);

    const parsed = rangeBodySchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.issues.map((i) => i.message).join('; ') }, { status: 400 });
    }

    const plan = await publishRange(new FirestoreRangeStore(adminDb()), {
      range: parsed.data,
      updatedBy: identity.email,
      source: 'ingest',
    });

    return NextResponse.json({
      published: {
        breakKey: plan.breakKey,
        startDate: plan.range.startDate,
        endDate: plan.range.endDate,
        reason: plan.range.reason,
        dayCount: plan.dayCount,
        updatedBy: plan.provenance.updatedBy,
        updatedAt: plan.provenance.updatedAt,
      },
    });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    if (error instanceof ScheduleValidationError) {
      return NextResponse.json(
        { error: 'That break did not validate, so nothing was published.', issues: error.issues },
        { status: 400 },
      );
    }
    console.error('[publish-range]', error);
    return NextResponse.json({ error: 'The publish failed. Nothing was written.' }, { status: 500 });
  }
}
