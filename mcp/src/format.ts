/**
 * Turning a day into something a person can check.
 *
 * The confirm step is the whole safety model, and a confirm step is worthless if what it
 * shows cannot be checked at a glance. So: full times, in order, with the block letters,
 * and warnings called out rather than buried. Nobody catches a wrong bell time in JSON.
 *
 * The date string is never built here. It arrives from the server, which builds it with
 * the same function the web tool uses.
 */

export interface ScheduleEvent {
  type?: string;
  block?: string;
  name?: string;
  startTime?: string;
  endTime?: string;
  filter?: string[];
  lunchBlock?: string;
  contents?: ScheduleEvent[];
}

export interface ScheduleDay {
  type?: string;
  reason?: string;
  imageUrl?: string;
  blocks?: ScheduleEvent[];
}

export interface ProposedDay {
  date: string;
  display?: string;
  day: ScheduleDay;
  warnings?: string[];
}

function label(event: ScheduleEvent): string {
  const block = event.block && event.block !== 'other' ? event.block.toUpperCase() : '';
  const name = event.name ?? '';
  if (block && name) return `${name} (${block})`;
  return name || block || event.type || 'untitled';
}

function eventLines(events: ScheduleEvent[], indent = ''): string[] {
  const lines: string[] = [];
  for (const event of events) {
    if (event.type === 'specific') {
      const who = event.filter?.length ? event.filter.join(', ') : 'everyone';
      lines.push(`${indent}only for ${who}${event.lunchBlock ? ` (splits ${event.lunchBlock.toUpperCase()})` : ''}:`);
      lines.push(...eventLines(event.contents ?? [], `${indent}    `));
      continue;
    }
    const time =
      event.startTime && event.endTime ? `${event.startTime} - ${event.endTime}` : 'no time given';
    lines.push(`${indent}${time.padEnd(21)} ${label(event)}`);
  }
  return lines;
}

/** One day, rendered for a human to approve or reject. */
export function formatDay(proposed: ProposedDay): string {
  const heading = proposed.display ?? proposed.date;
  const day = proposed.day;
  const lines: string[] = [heading];

  if (day.type === 'noschool') {
    lines.push(`  No school${day.reason ? ` - ${day.reason}` : ''}`);
  } else if (day.type === 'image') {
    lines.push(`  Posted as an image: ${day.imageUrl ?? '(no url)'}`);
  } else {
    const blocks = day.blocks ?? [];
    if (blocks.length === 0) {
      lines.push('  (no blocks, which is almost certainly wrong for a school day)');
    } else {
      lines.push(...eventLines(blocks, '  '));
    }
  }

  for (const warning of proposed.warnings ?? []) {
    lines.push(`  ! ${warning}`);
  }
  return lines.join('\n');
}

export function formatProposal(id: string, days: ProposedDay[]): string {
  const body = days.map(formatDay).join('\n\n');
  const count = days.length === 1 ? '1 day' : `${days.length} days`;
  return [
    `Proposal ${id} - ${count}. NOTHING IS PUBLISHED YET.`,
    '',
    body,
    '',
    'Show this to the person who asked for it and get a yes in their own words.',
    `Then call publish_schedule with proposal_id "${id}" and confirm true.`,
  ].join('\n');
}
