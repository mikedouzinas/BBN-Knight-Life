'use client';

/**
 * The day drawn against an hour rail, each block sized to its real duration.
 *
 * A list of rows hides the three mistakes that actually matter here: a gap where a block
 * was dropped, two blocks that overlap, and a time that parsed wrong. Production already
 * contains the third (a lunch ending at 12:05am), and in a table it reads as an ordinary
 * row. Drawn to scale it is a band running off the bottom of the day, which is the point:
 * the human in this loop is here to catch things, so the shape should do the catching.
 */
import type { RenderedRow } from '@/lib/schedule/render';
import { parseTime12 } from '@/lib/schedule/time';
import { Glow } from './Glow';

const PX_PER_MIN = 1.15;
const MIN_BAND = 26;

interface Band {
  row: RenderedRow;
  top: number;
  height: number;
  kind: 'block' | 'lunch' | 'other';
  tight: boolean;
}

function hourLabel(minutes: number): string {
  const h24 = Math.floor(minutes / 60);
  const h = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${h}${h24 < 12 ? 'am' : 'pm'}`;
}

export function BellRail({ rows }: { rows: RenderedRow[] }) {
  const parsed = rows
    .map((row) => ({ row, start: parseTime12(row.startTime), end: parseTime12(row.endTime) }))
    .filter((r): r is { row: RenderedRow; start: number; end: number } =>
      r.start !== null && r.end !== null);

  // Anything unparseable cannot be placed. Show it plainly rather than guessing a position.
  const unplaceable = rows.filter(
    (row) => parseTime12(row.startTime) === null || parseTime12(row.endTime) === null,
  );

  if (parsed.length === 0) {
    return <p className="note">No times could be read from this day.</p>;
  }

  const dayStart = Math.floor(Math.min(...parsed.map((r) => r.start)) / 60) * 60;
  const dayEnd = Math.ceil(Math.max(...parsed.map((r) => Math.max(r.end, r.start + 5))) / 60) * 60;
  const height = (dayEnd - dayStart) * PX_PER_MIN;

  const bands: Band[] = parsed.map(({ row, start, end }) => {
    const raw = Math.max(end - start, 5) * PX_PER_MIN;
    const name = row.name.toLowerCase();
    const kind: Band['kind'] = name.includes('lunch')
      ? 'lunch'
      : row.block
        ? 'block'
        : 'other';
    return {
      row,
      top: (start - dayStart) * PX_PER_MIN,
      height: Math.max(raw, MIN_BAND),
      kind,
      tight: raw < 34,
    };
  });

  const hours: number[] = [];
  for (let m = dayStart; m <= dayEnd; m += 60) hours.push(m);

  return (
    <>
      <div className="rail" style={{ height }}>
        <div className="rail-hours">
          {hours.map((m) => (
            <span key={m} className="rail-hour" style={{ top: (m - dayStart) * PX_PER_MIN }}>
              {hourLabel(m)}
            </span>
          ))}
        </div>
        <div className="rail-track" style={{ height }}>
          {hours.map((m) => (
            <div key={m} className="rail-gridline" style={{ top: (m - dayStart) * PX_PER_MIN }} />
          ))}
          {bands.map((band, i) => (
            <div
              key={`${band.row.name}-${i}`}
              className={`band ${band.kind}${band.tight ? ' tight' : ''}`}
              style={{ top: band.top, height: band.height }}
            >
              <Glow size={150} intensity={0.16} />
              {band.row.block && <span className="band-letter">{band.row.block}</span>}
              <span className="band-name">{band.row.name}</span>
              {band.row.room && <span className="band-meta">Room {band.row.room}</span>}
              {band.row.audienceLabel && <span className="band-meta">{band.row.audienceLabel}</span>}
              <span className="band-time">
                {band.row.startTime}–{band.row.endTime}
              </span>
            </div>
          ))}
        </div>
      </div>

      {unplaceable.length > 0 && (
        <ul className="warnings">
          {unplaceable.map((row, i) => (
            <li key={i}>
              Could not read the times on {row.name} ({row.startTime} to {row.endTime}), so it is
              not drawn above.
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
