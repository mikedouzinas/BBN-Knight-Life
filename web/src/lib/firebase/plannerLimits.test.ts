/**
 * HQ-2180. The planner's length limits live in two places that cannot import each other: the
 * Swift app (FieldLimits, which the text fields enforce) and firebase/firestore.rules (which
 * the server enforces, because a client writes planner documents directly).
 *
 * If they drift, one of two things happens. App limit larger than the rules: a student types
 * a title the app accepts and the write is silently refused. App limit smaller: the rules are
 * looser than the app believes, which is harmless until a second client writes one. Both are
 * bugs nobody would see until a student did, so this reads both files and compares.
 *
 * Plain vitest, no emulator, so it runs in `npm test` on every push.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const ROOT = resolve(__dirname, '../../../..');
const swift = readFileSync(resolve(ROOT, 'BBNDaily/Other/Structs.swift'), 'utf8');
const rules = readFileSync(resolve(ROOT, 'firebase/firestore.rules'), 'utf8');

function swiftLimit(name: string): number {
  const match = swift.match(new RegExp(`static let ${name} = (\\d+)`));
  if (!match) throw new Error(`FieldLimits.${name} not found in Structs.swift`);
  return Number(match[1]);
}

/** The `<= N` that follows `d.<field>.size()` inside validPlannerItem. */
function rulesLimit(field: string): number {
  const fn = rules.slice(rules.indexOf('function validPlannerItem'));
  const match = fn.match(new RegExp(`d\\.${field}\\.size\\(\\) <= (\\d+)`));
  if (!match) throw new Error(`size limit for ${field} not found in validPlannerItem`);
  return Number(match[1]);
}

describe('planner field limits', () => {
  it('title: the app and the rules agree', () => {
    expect(rulesLimit('title')).toBe(swiftLimit('plannerTitle'));
  });

  it('notes: the app and the rules agree', () => {
    expect(rulesLimit('notes')).toBe(swiftLimit('plannerNotes'));
  });
});
