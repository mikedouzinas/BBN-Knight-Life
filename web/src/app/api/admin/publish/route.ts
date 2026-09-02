/**
 * The only route in this app that writes a schedule.
 *
 * It re-validates from scratch. The client already validated, the model layer already
 * validated, and neither is trusted here: the body arriving at this handler is
 * arbitrary JSON from a browser, and `publishDay` is where "unvalidated output never
 * reaches Firestore" is actually enforced.
 *
 * `updatedBy` comes from the verified ID token, never from the body.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';
import { adminDb, adminMessaging } from '@/lib/firebase/admin';
import { FirestoreScheduleStore } from '@/lib/firebase/firestoreStore';
import { ScheduleValidationError, publishDay } from '@/lib/schedule/publish';
import type { ScheduleDay } from '@/lib/schedule/types';
import { publishBodySchema } from '@/lib/ingest/requestBody';
import { FcmNotifier } from '@/lib/notify/fcmNotifier';
import { notifyDayPublished } from '@/lib/notify/scheduleNotify';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const identity = await requireAdmin(request);

    const parsed = publishBodySchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.issues.map((i) => i.message).join('; ') }, { status: 400 });
    }

    const store = new FirestoreScheduleStore(adminDb());
    const plan = await publishDay(store, {
      date: parsed.data.date,
      day: parsed.data.day as ScheduleDay,
      updatedBy: identity.email,
      source: 'ingest',
    });

    await notifyDayPublished(new FcmNotifier(adminMessaging()), plan);

    return NextResponse.json({
      published: {
        date: plan.isoDate,
        canonicalKey: plan.canonicalKey,
        legacyId: plan.legacyId,
        updatedBy: plan.provenance.updatedBy,
        updatedAt: plan.provenance.updatedAt,
      },
    });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    if (error instanceof ScheduleValidationError) {
      return NextResponse.json({ error: 'That schedule did not validate, so nothing was published.', issues: error.issues }, { status: 400 });
    }
    console.error('[publish]', error);
    return NextResponse.json({ error: 'The publish failed. Nothing was written.' }, { status: 500 });
  }
}
