import { describe, expect, it } from 'vitest';
import { planPublish, planRangePublish } from '@/lib/schedule/publish';
import type { ScheduleDay } from '@/lib/schedule/types';
import productionV2 from '@/lib/schedule/__fixtures__/production-v2-2024-09-04.json';
import {
  SCHEDULE_TOPIC,
  dayNotification,
  notifyDayPublished,
  notifyRangePublished,
  rangeNotification,
  type Notifier,
  type PushMessage,
} from './scheduleNotify';

class RecordingNotifier implements Notifier {
  readonly sent: PushMessage[] = [];
  async send(message: PushMessage): Promise<void> {
    this.sent.push(message);
  }
}

class ThrowingNotifier implements Notifier {
  async send(): Promise<void> {
    throw new Error('FCM is down');
  }
}

const day = productionV2 as ScheduleDay;

describe('dayNotification', () => {
  it('names a snow day by its reason', () => {
    const plan = planPublish({
      date: '2024-09-04',
      day: { type: 'noschool', reason: 'Snow day' },
      updatedBy: 'a@bbns.org',
      source: 'ingest',
    });
    const message = dayNotification(plan);
    expect(message.topic).toBe(SCHEDULE_TOPIC);
    expect(message.title).toBe('Wednesday, September 4, 2024');
    expect(message.body).toBe('No school: Snow day.');
  });

  it('describes a normal block day generically, not by its contents', () => {
    const plan = planPublish({ date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });
    expect(dayNotification(plan).body).toBe('The bell schedule changed.');
  });
});

describe('rangeNotification', () => {
  it('titles the notification with the break reason and spells out the span', () => {
    const plan = planRangePublish({
      range: { startDate: '2026-12-19', endDate: '2027-01-03', reason: 'Winter break' },
      updatedBy: 'a@bbns.org',
      source: 'ingest',
    });
    const message = rangeNotification(plan);
    expect(message.topic).toBe(SCHEDULE_TOPIC);
    expect(message.title).toBe('Winter break');
    expect(message.body).toBe('No school Saturday, December 19, 2026 through Sunday, January 3, 2027.');
  });
});

describe('notifyDayPublished / notifyRangePublished', () => {
  it('sends exactly one message for a day publish', async () => {
    const notifier = new RecordingNotifier();
    const plan = planPublish({ date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });
    await notifyDayPublished(notifier, plan);
    expect(notifier.sent).toHaveLength(1);
    expect(notifier.sent[0]).toEqual(dayNotification(plan));
  });

  it('never throws when the send fails, because the publish already happened', async () => {
    const plan = planPublish({ date: '2024-09-04', day, updatedBy: 'a@bbns.org', source: 'ingest' });
    await expect(notifyDayPublished(new ThrowingNotifier(), plan)).resolves.toBeUndefined();
  });

  it('never throws for a range send failure either', async () => {
    const plan = planRangePublish({
      range: { startDate: '2026-12-19', endDate: '2027-01-03', reason: 'Winter break' },
      updatedBy: 'a@bbns.org',
      source: 'ingest',
    });
    await expect(notifyRangePublished(new ThrowingNotifier(), plan)).resolves.toBeUndefined();
  });
});
