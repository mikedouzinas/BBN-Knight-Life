/**
 * Push notifications for a published schedule change. HQ-112.
 *
 * Every device that wants these subscribes to one FCM topic, `SCHEDULE_TOPIC` — there is
 * no per-user targeting, because every student is affected the same way by a snow day.
 * That also means there is nothing to store in Firestore for this: no device-token
 * collection, no security rules to write.
 *
 * `Notifier` is the same seam `ScheduleStore` uses: production sends through FCM,
 * tests use a fake that records what would have been sent. Nothing here writes a
 * schedule, so it is deliberately not on the path `publish.ts` guards — a failed send
 * must never undo, block, or retry a publish that already happened.
 */
import type { PublishPlan, RangePublishPlan } from '@/lib/schedule/publish';
import { displayDate } from '@/lib/schedule/dates';

export const SCHEDULE_TOPIC = 'schedule-updates';

export interface PushMessage {
  topic: string;
  title: string;
  body: string;
}

export interface Notifier {
  send(message: PushMessage): Promise<void>;
}

function dayBody(plan: PublishPlan): string {
  const day = plan.canonicalValue;
  // Validation requires a reason on every "noschool" day before it can be published.
  return day.type === 'noschool' ? `No school: ${day.reason}.` : 'The bell schedule changed.';
}

export function dayNotification(plan: PublishPlan): PushMessage {
  return { topic: SCHEDULE_TOPIC, title: displayDate(plan.isoDate), body: dayBody(plan) };
}

export function rangeNotification(plan: RangePublishPlan): PushMessage {
  return {
    topic: SCHEDULE_TOPIC,
    title: plan.range.reason,
    body: `No school ${displayDate(plan.range.startDate)} through ${displayDate(plan.range.endDate)}.`,
  };
}

/** Best-effort. A failed send is logged, never thrown — the publish already succeeded. */
export async function notifyDayPublished(notifier: Notifier, plan: PublishPlan): Promise<void> {
  try {
    await notifier.send(dayNotification(plan));
  } catch (error) {
    console.error('[notify] day push failed', error);
  }
}

export async function notifyRangePublished(notifier: Notifier, plan: RangePublishPlan): Promise<void> {
  try {
    await notifier.send(rangeNotification(plan));
  } catch (error) {
    console.error('[notify] range push failed', error);
  }
}
