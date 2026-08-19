'use client';

/**
 * A break, rendered as one row rather than as a schedule.
 *
 * A span has no blocks to check, so the thing a reviewer must actually verify is the two
 * dates and specifically the LAST one: the commonest mistake in a break announcement is
 * reading "classes resume Monday the 4th" as an end date, which takes an extra day of school
 * off the calendar for everybody. So the card shows the end date with its weekday, the
 * inclusive day count, and the day classes resume, spelled out.
 */
import { useState } from 'react';
import { Glow } from './Glow';
import { displayDate } from '@/lib/schedule/dates';
import type { CandidateRange } from './useIngest';

function nextDay(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number);
  const next = new Date(Date.UTC(y, m - 1, d + 1));
  return `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, '0')}-${String(next.getUTCDate()).padStart(2, '0')}`;
}

function inclusiveDays(startIso: string, endIso: string): number {
  const [ys, ms, ds] = startIso.split('-').map(Number);
  const [ye, me, de] = endIso.split('-').map(Number);
  return Math.round((Date.UTC(ye, me - 1, de) - Date.UTC(ys, ms - 1, ds)) / 86_400_000) + 1;
}

export function RangeCard({
  range,
  publishing,
  publishedDetail,
  onPublish,
  onDiscard,
  publishLabel = 'Publish',
}: {
  range: CandidateRange;
  publishing: boolean;
  publishedDetail?: string;
  onPublish: () => void;
  onDiscard: () => void;
  publishLabel?: string;
}) {
  const [confirming, setConfirming] = useState(false);
  const days = range.dayCount ?? inclusiveDays(range.startDate, range.endDate);

  return (
    <section className="card day">
      <Glow size={300} intensity={0.1} />

      <div className="standalone-row">
        <Glow size={160} intensity={0.16} color="255, 214, 130" />
        <span className="standalone-mark">No school</span>
        <span className="standalone-text">
          {displayDate(range.startDate)} through {displayDate(range.endDate)}
        </span>
        <span className="standalone-reason">{range.reason}</span>
      </div>

      <p className="note">
        {days} {days === 1 ? 'day' : 'days'}, both ends included. Classes resume{' '}
        <strong>{displayDate(nextDay(range.endDate))}</strong>.
      </p>

      {publishedDetail ? (
        <p className="published">Published. {publishedDetail}</p>
      ) : confirming ? (
        <div className="confirm">
          <p>Are you sure?</p>
          <button type="button" className="primary" disabled={publishing} onClick={onPublish}>
            <Glow size={130} intensity={0.3} color="255, 214, 130" />
            {publishing ? 'Publishing...' : 'Yes, publish it'}
          </button>
          <button type="button" className="secondary" disabled={publishing} onClick={() => setConfirming(false)}>
            <Glow size={130} intensity={0.22} />
            Cancel
          </button>
        </div>
      ) : (
        <div className="actions">
          <button type="button" className="primary" onClick={() => setConfirming(true)}>
            <Glow size={130} intensity={0.3} color="255, 214, 130" />
            {publishLabel}
          </button>
          <button type="button" className="secondary" onClick={onDiscard}>
            <Glow size={130} intensity={0.22} />
            Discard
          </button>
        </div>
      )}
    </section>
  );
}
