'use client';

import { useState } from 'react';
import type { CandidateDay } from './useIngest';
import { SchedulePreview } from './SchedulePreview';
import { displayDate } from '@/lib/schedule/dates';
import { Glow } from './Glow';

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
      <Glow size={280} intensity={0.13} color="255, 214, 130" />
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
          <p>Are you sure?</p>
          <button type="button" className="primary" disabled={publishing} onClick={onPublish}>
            <Glow size={130} intensity={0.3} color="255, 214, 130" />
            {publishing ? 'Publishing...' : 'Yes, publish it'}
          </button>
          <button type="button" className="secondary" disabled={publishing} onClick={() => setConfirming(false)}>
            Not yet
          </button>
        </div>
      ) : (
        <div className="confirm">
          <button type="button" className="primary" onClick={() => setConfirming(true)}>
            <Glow size={130} intensity={0.3} color="255, 214, 130" />
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
