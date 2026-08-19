'use client';

/**
 * The result, rendered the way a student sees it. This screen is the whole point of the
 * tool: it is where a hallucinated block gets caught, by a person, before 600 students
 * act on it.
 */
import { useState } from 'react';
import type { ScheduleDay } from '@/lib/schedule/types';
import { renderForAudience, type Grade, type LunchWave } from '@/lib/schedule/render';
import { deriveLegacyDay } from '@/lib/schedule/derive';
import { displayDate } from '@/lib/schedule/dates';
import { BellRail } from './BellRail';
import { Glow } from './Glow';

const GRADES: Grade[] = ['9', '10', '11', '12'];
const WAVES: { value: LunchWave; label: string }[] = [
  { value: 'L1', label: '1st lunch' },
  { value: 'L2', label: '2nd lunch' },
];

export function SchedulePreview({ isoDate, day }: { isoDate: string; day: ScheduleDay }) {
  const [grade, setGrade] = useState<Grade>('10');
  const [wave, setWave] = useState<LunchWave>('L1');
  const [showLegacy, setShowLegacy] = useState(false);

  // A closed day is one fact, so it gets one row rather than an empty schedule.
  if (day.type === 'noschool') {
    return (
      <div className="preview">
        <div className="standalone-row">
          <Glow size={160} intensity={0.16} color="255, 214, 130" />
          <span className="standalone-mark">No school</span>
          <span className="standalone-text">{displayDate(isoDate)}</span>
          {day.reason && <span className="standalone-reason">{day.reason}</span>}
        </div>
      </div>
    );
  }
  if (day.type === 'image') {
    return (
      <div className="preview">
        <div className="standalone-row">
          <Glow size={160} intensity={0.16} />
          <span className="standalone-mark">Image</span>
          <span className="standalone-text">
            Posted as a picture, so the app shows the image rather than blocks.
          </span>
        </div>
        <p className="note">{day.imageUrl}</p>
      </div>
    );
  }

  const rows = renderForAudience(day, { grade, lunchWave: wave });
  const legacy = deriveLegacyDay(isoDate, day);

  return (
    <div className="preview">
      <div className="switcher">
        <span className="switcher-label">Showing</span>
        {GRADES.map((g) => (
          <button key={g} type="button" className={g === grade ? 'chip on' : 'chip'} onClick={() => setGrade(g)}>
            Gr. {g}
          </button>
        ))}
        {WAVES.map((w) => (
          <button key={w.value} type="button" className={w.value === wave ? 'chip on' : 'chip'} onClick={() => setWave(w.value)}>
            {w.label}
          </button>
        ))}
      </div>

      <BellRail rows={rows} />

      <button type="button" className="link" onClick={() => setShowLegacy((v) => !v)}>
        {showLegacy ? 'Hide' : 'Show'} what older app versions will see
      </button>
      {showLegacy && (
        <div className="legacy">
          <p className="note">
            Generated from the schedule above, never typed. Written to special-schedules/{legacy.id}, which is
            what 2.4.1 uses for notifications and what pre-2.4.1 builds use for everything.
          </p>
          {(['blocks-l1', 'blocks'] as const).map((key) => (
            <div key={key}>
              <h4>{key === 'blocks-l1' ? '1st lunch' : '2nd lunch'}</h4>
              <table className="schedule small">
                <tbody>
                  {legacy.doc[key].map((row, index) => (
                    <tr key={`${row.name}-${index}`}>
                      <td className="time">
                        {row.startTime} to {row.endTime}
                      </td>
                      <td className="name">
                        <span className="blockletter">{row.block}</span>
                        {row.name}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
        </div>
      )}
      <p className="note">{displayDate(isoDate)}</p>
    </div>
  );
}
