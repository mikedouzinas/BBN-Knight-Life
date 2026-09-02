/**
 * HQ-634's checklist item 3: warn in the admin tool when break/term coverage is about to
 * lapse, rather than let a school year quietly end with nothing published for the next one.
 *
 * This is what actually happened in August 2026: `schedules/term` and `schedules/break` both
 * stopped being kept current, resolveDay had no term boundary to fall back on, and every
 * student saw a full seven-block Wednesday in the middle of summer. The code-side fix
 * (resolveDay defaulting an unscheduled weekday to no school) already landed; this is the
 * warning that should have caught the gap before it reached students.
 */
import { fromCanonicalKey, isValidIsoDate } from './dates';

export interface Term {
  /** `yyyy/M/d`, matching how the iOS app reads `schedules/term`. */
  end: string;
}

export interface TermCoverageWarning {
  message: string;
}

const WARNING_WINDOW_DAYS = 21;

function daysUntil(todayIso: string, targetIso: string): number {
  const [ty, tm, td] = todayIso.split('-').map(Number);
  const [ey, em, ed] = targetIso.split('-').map(Number);
  return Math.round((Date.UTC(ey, em - 1, ed) - Date.UTC(ty, tm - 1, td)) / 86_400_000);
}

/**
 * `today` is passed in, not read from `Date.now()`, so this stays a pure function a test can
 * call with any date rather than one that only behaves differently depending on when it runs.
 */
export function termCoverageWarning(term: Term | null, today: string): TermCoverageWarning | null {
  if (!isValidIsoDate(today)) throw new Error(`today must be YYYY-MM-DD: ${today}`);

  if (!term) {
    return {
      message:
        'No school-year end date is published (schedules/term). Every day resolves as though it might be outside the school year.',
    };
  }

  let endIso: string;
  try {
    endIso = fromCanonicalKey(term.end);
  } catch {
    return { message: `schedules/term's end date ("${term.end}") is not a valid yyyy/M/d key.` };
  }

  const daysLeft = daysUntil(today, endIso);
  if (daysLeft < 0) {
    return {
      message: `The published school year already ended (${term.end}). Publish the next one before students see "no school" every day.`,
    };
  }
  if (daysLeft <= WARNING_WINDOW_DAYS) {
    return {
      message: `The published school year ends in ${daysLeft} day${daysLeft === 1 ? '' : 's'} (${term.end}). Publish next year's term before it lapses.`,
    };
  }
  return null;
}
