/**
 * The legacy projection: canonical day -> `special-schedules/{Full Date String}`.
 *
 * The legacy documents are never authored by hand again. They are generated from one
 * source, which is the difference between this dual-write and the hand-run one that
 * produced 43 days in v2 missing from v1 and 12 days where the two disagree.
 *
 * Two facts from the shipped app fix the shape, both read out of the code rather than
 * guessed:
 *
 *   1. `blocks` is the SECOND lunch wave and `blocks-l1` is the first.
 *      `SecretSchedule.swift:160` writes `"blocks": lunch2, "blocks-l1": lunch1`, and
 *      `Extensions.swift:773` reads `specialSchedulesL1` unless the student's lunch
 *      setting contains "2". Getting this backwards sends half the school to lunch at
 *      the wrong hour, so it is asserted by a test against a real production pair.
 *
 *   2. The block field is `"A".."G"` for a letter block and `"N/A"` for everything else
 *      (`Extensions.swift:884`), and a lunch row is named `"Lunch"` (line 889).
 *
 * The one place this is a projection rather than a copy: v1 has no grade dimension.
 * Grade-filtered content is kept, not dropped, with the audience folded into the row
 * name, as in "Gr. 10-12 Advisory". Dropping a row hides a real class from a real student;
 * an extra labelled row is legible. This matches the app's own default for a student
 * with no grade set, which is to show every grade-filtered group.
 */
import type { LegacyBlock, LegacyDayDoc, ScheduleDay, ScheduleEvent } from './types';
import { toLegacyKey } from './dates';
import { toLegacyTime } from './time';
import { audienceLabel, sortRows } from './render';

type Wave = 'L1' | 'L2';

function legacyRow(event: ScheduleEvent, namePrefix?: string): LegacyBlock {
  const raw = event.block ?? '';
  const block = raw.length === 1 ? raw.toUpperCase() : 'N/A';
  const base = event.type === 'lunch' ? 'Lunch' : event.name ?? (block === 'N/A' ? '' : block);
  const name = namePrefix && !/^(gr\.?|grade|faculty)\b/i.test(base) ? `${namePrefix} ${base}` : base;
  return {
    name,
    block,
    startTime: toLegacyTime(event.startTime ?? '') ?? '',
    endTime: toLegacyTime(event.endTime ?? '') ?? '',
  };
}

function waveOf(filter: string[]): Wave | null {
  if (filter.includes('L1')) return 'L1';
  if (filter.includes('L2')) return 'L2';
  return null;
}

/** One wave's flat row list, in start-time order. */
export function flattenForWave(day: ScheduleDay, wave: Wave): LegacyBlock[] {
  const rows: LegacyBlock[] = [];
  for (const event of day.blocks ?? []) {
    if (event.type !== 'specific') {
      rows.push(legacyRow(event));
      continue;
    }
    const filter = event.filter ?? [];
    const eventWave = waveOf(filter);
    if (eventWave && eventWave !== wave) continue;
    // A grade group has no wave, so it lands in both waves, labelled.
    const prefix = eventWave ? undefined : audienceLabel(filter);
    const label = prefix === 'All grades' ? undefined : prefix;
    for (const child of event.contents ?? []) rows.push(legacyRow(child, label));
  }
  return sortRows(rows);
}

/**
 * The legacy document for one day. `id` is the document ID; `doc` is its contents.
 * A no-school or image day carries empty block arrays, which is what the shipped
 * writer produces and what the reader tolerates (`AuthVC.swift:114` defaults both).
 */
export function deriveLegacyDay(isoDate: string, day: ScheduleDay): { id: string; doc: LegacyDayDoc } {
  const id = toLegacyKey(isoDate);
  const blocks = day.type === 'blocks' ? flattenForWave(day, 'L2') : [];
  const l1 = day.type === 'blocks' ? flattenForWave(day, 'L1') : [];
  return {
    id,
    doc: {
      date: id,
      reason: day.reason ?? '',
      imageUrl: day.imageUrl ?? '',
      blocks,
      'blocks-l1': l1,
    },
  };
}
