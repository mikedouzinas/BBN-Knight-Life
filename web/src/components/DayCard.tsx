'use client';

import { useState } from 'react';
import type { CandidateDay } from './useIngest';
import { SchedulePreview } from './SchedulePreview';
import { displayDate } from '@/lib/schedule/dates';

export function DayCard({
  candidate,
  publishing,
  publishedDetail,
  onPublish,
  onDiscard,
  publishLabel = 'Publish',
}: {
  candidate: CandidateDay;
  publishing: boolean;
  publishedDetail?: string;
  onPublish: () => void;
  onDiscard: () => void;
  publishLabel?: string;
}) {
  const [confirming, setConfirming] = useState(false);

  return (
    <section className="card day">
      <header>
        <h3>{displayDate(candidate.date)}</h3>
        {candidate.day.reason && <p className="reason">{candidate.day.reason}</p>}
      </header>

      <SchedulePreview isoDate={candidate.date} day={candidate.day} />

      {candidate.warnings.length > 0 && (
        <ul className="warnings">
          {candidate.warnings.map((warning) => (
            <li key={warning}>{warning}</li>
          ))}
        </ul>
      )}

      {publishedDetail ? (
        <p className="published">Published. {publishedDetail}</p>
      ) : confirming ? (
        <div className="confirm">
          <p>Does this match the email you were sent, row for row?</p>
          <button type="button" className="primary" disabled={publishing} onClick={onPublish}>
            {publishing ? 'Publishing...' : 'Yes, publish it'}
          </button>
          <button type="button" className="secondary" disabled={publishing} onClick={() => setConfirming(false)}>
            Not yet
          </button>
        </div>
      ) : (
        <div className="confirm">
          <button type="button" className="primary" onClick={() => setConfirming(true)}>
            {publishLabel}
          </button>
          <button type="button" className="secondary" onClick={onDiscard}>
            Discard
          </button>
        </div>
      )}
    </section>
  );
}
