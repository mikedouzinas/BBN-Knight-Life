/**
 * Things that are legal but worth a second look before publishing.
 *
 * These never block a publish. They exist because the admin is the correctness check,
 * and a check works better when the odd row is pointed at rather than buried in
 * thirty identical-looking ones.
 */
import type { ScheduleDay } from './types';
import { parseTime12 } from './time';
import { renderForAudience, type Audience, type Grade, type LunchWave } from './render';

const GRADES: Grade[] = ['9', '10', '11', '12'];
const WAVES: LunchWave[] = ['L1', 'L2'];

function audienceName(audience: Audience): string {
  const grade = audience.grade === null ? 'any grade' : audience.grade === 'teacher' ? 'faculty' : `grade ${audience.grade}`;
  const wave = audience.lunchWave === null ? '' : audience.lunchWave === 'L1' ? ', 1st lunch' : ', 2nd lunch';
  return `${grade}${wave}`;
}

export function dayWarnings(day: ScheduleDay): string[] {
  const warnings: string[] = [];
  if (day.type !== 'blocks') return warnings;

  const audiences: Audience[] = [];
  for (const grade of GRADES) for (const lunchWave of WAVES) audiences.push({ grade, lunchWave });

  for (const audience of audiences) {
    const rows = renderForAudience(day, audience);
    if (!rows.length) {
      warnings.push(`Nothing at all is scheduled for ${audienceName(audience)}.`);
      continue;
    }
    for (let i = 0; i < rows.length; i += 1) {
      const start = parseTime12(rows[i].startTime);
      const end = parseTime12(rows[i].endTime);
      if (start !== null && end !== null && start === end) {
        warnings.push(`"${rows[i].name}" starts and ends at ${rows[i].startTime}.`);
      }
      const next = rows[i + 1];
      if (!next) continue;
      const nextStart = parseTime12(next.startTime);
      if (end !== null && nextStart !== null && nextStart < end) {
        warnings.push(`"${rows[i].name}" and "${next.name}" overlap for ${audienceName(audience)}.`);
      }
    }
  }

  const hasLunch = JSON.stringify(day.blocks ?? []).includes('"lunch"');
  if (!hasLunch) warnings.push('No lunch anywhere in this day.');

  return [...new Set(warnings)];
}
