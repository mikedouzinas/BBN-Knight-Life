/**
 * The retry loop for HQ-656, with a stubbed model - offline, same as extract.test.ts.
 * What's being proven: invalid output goes back to the model with the reason attached
 * and is never returned as if it were an accepted class.
 */
import { describe, expect, it, vi } from 'vitest';
import type Anthropic from '@anthropic-ai/sdk';
import { IngestError } from './extract';
import {
  decodeEntities,
  extractStudentClasses,
  isFreeSubject,
  isNonBlockRow,
  normalizeSubject,
  splitTeacherAndRoom,
} from './extractStudentClasses';

function toolUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_student_classes', input };
}

function lunchUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_lunch_wave', input };
}

function detailsUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_student_details', input };
}

function stubClient(responses: { content: unknown[] }[]) {
  const create = vi.fn();
  for (const response of responses) create.mockResolvedValueOnce(response);
  create.mockResolvedValue({ content: [] });
  return { client: { messages: { create } } as unknown as Anthropic, create };
}

const PHOTO = { attachments: [{ mediaType: 'image/jpeg' as const, data: 'abc' }] };

const GOOD = { block: 'b', subject: 'Precalculus AB', teacher: 'Ms. Chen', room: '210' };
// Same block as GOOD, invalid for a different reason (empty subject) - so a follow-up
// call for the same block is a real correction, not a different class replacing it.
const BAD = { block: 'b', subject: '' };

describe('extractStudentClasses', () => {
  it('returns a class the schema accepted', async () => {
    const { client, create } = stubClient([{ content: [toolUse('a', GOOD)] }]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes).toHaveLength(1);
    expect(result.classes[0].block).toBe('b');
    expect(create).toHaveBeenCalledTimes(1);
  });

  it('hands the validation error back to the model and accepts the corrected block', async () => {
    const { client, create } = stubClient([
      { content: [toolUse('a', BAD)] },
      { content: [toolUse('b', GOOD)] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(create).toHaveBeenCalledTimes(2);
    expect(result.classes).toHaveLength(1);
    expect(result.rejected).toEqual([]);

    const followUp = create.mock.calls[1][0] as Anthropic.MessageCreateParamsNonStreaming;
    const toolResults = followUp.messages.at(-1)!.content as { is_error?: boolean; content?: string }[];
    expect(toolResults[0].is_error).toBe(true);
    expect(toolResults[0].content).toMatch(/block/);
  });

  it('gives up after three attempts and reports the failure rather than a class', async () => {
    const { client, create } = stubClient([
      { content: [toolUse('a', BAD)] },
      { content: [toolUse('b', BAD)] },
      { content: [toolUse('c', BAD)] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(create).toHaveBeenCalledTimes(3);
    expect(result.classes).toEqual([]);
    expect(result.rejected).toHaveLength(3);
  });

  it('keeps the good blocks from a batch where one block was bad', async () => {
    const { client } = stubClient([
      { content: [toolUse('a', GOOD), toolUse('b', { block: 'e', subject: '' })] },
      { content: [toolUse('c', { block: 'e', subject: 'Chemistry' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes.map((c) => c.block)).toEqual(['b', 'e']);
    expect(result.rejected).toEqual([]);
  });

  it('passes through what the model said when it called nothing', async () => {
    const { client } = stubClient([{ content: [{ type: 'text', text: 'I cannot make out this photo.' }] }]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes).toEqual([]);
    expect(result.message).toMatch(/cannot make out/);
  });

  it('refuses an empty request before spending a token', async () => {
    const { client, create } = stubClient([]);
    await expect(extractStudentClasses({ attachments: [] }, client)).rejects.toBeInstanceOf(IngestError);
    expect(create).not.toHaveBeenCalled();
  });

  it('refuses a file type the API cannot read', async () => {
    const { client } = stubClient([]);
    await expect(
      extractStudentClasses({ attachments: [{ mediaType: 'application/msword', data: 'abc' }] }, client),
    ).rejects.toBeInstanceOf(IngestError);
  });

  it('replaces an earlier block call with a later one for the same letter', async () => {
    const { client } = stubClient([
      { content: [toolUse('a', GOOD), toolUse('b', { ...GOOD, subject: 'Corrected Name' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes).toHaveLength(1);
    expect(result.classes[0].subject).toBe('Corrected Name');
  });
});

/**
 * Everything below was written against a real BB&N Grade 11 printout (US Trimester 1),
 * transcribed in `__fixtures__/real-schedule-2025.md`. The tests above stub the model, so none
 * of them could ever have caught what that sheet actually contains.
 */
describe('a row that is not a lettered block', () => {
  // Lunch and school-wide activities. These carry block-shaped labels on a real sheet
  // (L1, L2, SP, CAB, Adv, Aft) and must never become one of the student's seven classes.
  it.each([
    ['Lunch-2nd', 'as printed, hyphenated'],
    ['Lunch - 1st', 'spaced'],
    ['LUNCH 2ND', 'case and spacing'],
    ['Lunch', ''],
    ['Advisory', ''],
    ['Assembly - Special Programs', 'as printed on the Monday column'],
    ['Community Activity', ''],
    ['Class Mtg', ''],
    ['Long Passing', ''],
    ['After school', ''],
    ['', 'nothing at all'],
  ])('drops %s', (subject) => {
    expect(isNonBlockRow(subject)).toBe(true);
  });

  // A real course must never be dropped for containing a fragment of something on the list.
  it.each([
    'Precalculus',
    'AP English Masks',
    'Physics',
    'Spanish III',
    'United States History (Honors)',
    'Freedom and Justice',
    'Free Speech in America',
    'Advanced Study Hall Design',
    'Breakfast Chemistry',
    'Community Organizing in America',
    'Passing Through: Modern Poetry',
  ])('keeps %s', (subject) => {
    expect(isNonBlockRow(subject)).toBe(false);
  });

  it('is dropped without costing a retry, because there is nothing to correct', async () => {
    const { client, create } = stubClient([
      { content: [toolUse('a', GOOD), toolUse('b', { block: 'c', subject: 'Lunch-2nd' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(create).toHaveBeenCalledTimes(1);
    expect(result.classes.map((c) => c.block)).toEqual(['b']);
    expect(result.skipped).toEqual([{ block: 'c', subject: 'Lunch-2nd' }]);
    expect(result.rejected).toEqual([]);
  });

  it('is told not to substitute another class for the dropped block', async () => {
    const { client, create } = stubClient([
      { content: [toolUse('a', { block: 'f', subject: 'Advisory' }), toolUse('b', { block: 'b', subject: '' })] },
      { content: [toolUse('c', { block: 'b', subject: 'AP English Masks' })] },
    ]);
    await extractStudentClasses(PHOTO, client);

    const followUp = create.mock.calls[1][0] as Anthropic.MessageCreateParamsNonStreaming;
    const toolResults = followUp.messages.at(-1)!.content as { is_error?: boolean; content?: string }[];
    expect(toolResults[0].content).toMatch(/not a block/i);
    expect(toolResults[0].content).toMatch(/do not substitute/i);
    expect(toolResults[0].is_error).toBeUndefined();
  });
});

/**
 * A free block is an ANSWER, not a gap, and it is kept on purpose: seeing who else is free in
 * your block is the point of recording it. What matters is that every sheet's wording lands on
 * ONE spelling, because the class document is keyed by its subject text - "Unscheduled" and
 * "Study Hall" would otherwise be two rosters for the same empty block.
 */
describe('a free block', () => {
  it.each([
    'Unscheduled',
    'unscheduled',
    'Free',
    'Free Period',
    'Free Block',
    'Study Hall',
    'Open',
    'No Class',
    'N/A',
  ])('recognises %s as free', (subject) => {
    expect(isFreeSubject(subject)).toBe(true);
  });

  it.each(['Precalculus', 'Free Speech in America', 'Advanced Study Hall Design'])(
    'does not treat %s as free',
    (subject) => {
      expect(isFreeSubject(subject)).toBe(false);
    },
  );

  it('is kept as a class, under the canonical spelling', async () => {
    const { client } = stubClient([
      { content: [toolUse('a', { block: 'f', subject: 'Unscheduled' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(result.classes).toEqual([{ block: 'f', subject: 'Free', teacher: undefined, room: undefined }]);
    expect(result.skipped).toEqual([]);
  });

  it('collapses different sheets\' wordings onto one roster', async () => {
    const { client: c1 } = stubClient([{ content: [toolUse('a', { block: 'f', subject: 'Unscheduled' })] }]);
    const { client: c2 } = stubClient([{ content: [toolUse('a', { block: 'f', subject: 'Study Hall' })] }]);
    const [a, b] = [await extractStudentClasses(PHOTO, c1), await extractStudentClasses(PHOTO, c2)];
    expect(a.classes[0].subject).toBe(b.classes[0].subject);
    expect(a.classes[0].subject).toBe('Free');
  });

  it('carries no teacher or room, even if the model supplies them', async () => {
    const { client } = stubClient([
      { content: [toolUse('a', { block: 'g', subject: 'Free', teacher: 'Ms. Nobody', room: '101' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes[0].teacher).toBeUndefined();
    expect(result.classes[0].room).toBeUndefined();
  });
});

describe('grade', () => {
  it('is collected from the sheet header', async () => {
    const { client } = stubClient([{ content: [detailsUse('a', { grade: '11' })] }]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.details).toEqual({ grade: '11' });
  });

  // Advisory room was removed: the sheet names an advisor, never a room, so an always-empty
  // field only invited the model to put the advisor's NAME into `room-advisory`.
  it('ignores an advisory room even if the model sends one', async () => {
    const { client } = stubClient([
      { content: [detailsUse('a', { grade: '11', advisory: 'Ms. Rose' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.details).toEqual({ grade: '11' });
  });

  it('is left out when the sheet does not state it', async () => {
    const { client } = stubClient([{ content: [toolUse('a', GOOD)] }]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.details).toEqual({});
  });

  it('rejects a grade outside 9-12 and asks again', async () => {
    const { client, create } = stubClient([
      { content: [detailsUse('a', { grade: '13' })] },
      { content: [detailsUse('b', { grade: '12' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(create).toHaveBeenCalledTimes(2);
    expect(result.details).toEqual({ grade: '12' });
  });
});

describe('the lunch wave', () => {
  it('is collected per weekday', async () => {
    const { client } = stubClient([
      {
        content: [
          lunchUse('a', { day: 'monday', wave: 2 }),
          lunchUse('b', { day: 'tuesday', wave: 2 }),
          lunchUse('c', { day: 'wednesday', wave: 2 }),
          lunchUse('d', { day: 'thursday', wave: 2 }),
          lunchUse('e', { day: 'friday', wave: 2 }),
        ],
      },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.lunch).toEqual({
      monday: 2, tuesday: 2, wednesday: 2, thursday: 2, friday: 2,
    });
  });

  // The whole reason this is read per day rather than once. A student can be in the first
  // wave on one day and the second on another, and the app stores five separate values.
  it('can differ between days', async () => {
    const { client } = stubClient([
      { content: [lunchUse('a', { day: 'monday', wave: 1 }), lunchUse('b', { day: 'friday', wave: 2 })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.lunch).toEqual({ monday: 1, friday: 2 });
  });

  it('leaves out a day the sheet does not show, rather than guessing it', async () => {
    const { client } = stubClient([{ content: [lunchUse('a', { day: 'monday', wave: 1 })] }]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.lunch).toEqual({ monday: 1 });
    expect(Object.keys(result.lunch)).toHaveLength(1);
  });

  it('rejects a wave that is not 1 or 2 and asks again', async () => {
    const { client, create } = stubClient([
      { content: [lunchUse('a', { day: 'monday', wave: 3 })] },
      { content: [lunchUse('b', { day: 'monday', wave: 1 })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(create).toHaveBeenCalledTimes(2);
    expect(result.lunch).toEqual({ monday: 1 });
    expect(result.rejected).toEqual([]);
  });

  it('does not confuse a lunch day with a class block', async () => {
    const { client } = stubClient([
      { content: [toolUse('a', GOOD), lunchUse('b', { day: 'monday', wave: 2 })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes).toHaveLength(1);
    expect(result.lunch).toEqual({ monday: 2 });
  });
});

describe('teacher and room arriving fused', () => {
  // A class document is keyed by Subject~Teacher~Room~Block, so leaving "Ms. Lieberman - 285"
  // whole in `teacher` makes a different document than the split version - two rosters for
  // one real class.
  it.each([
    ['Ms. Lieberman - 285', 'Ms. Lieberman', '285'],
    ['Mr. Turnbull - 283', 'Mr. Turnbull', '283'],
    ['Ms. Courtemanche - 134', 'Ms. Courtemanche', '134'],
    ['Ms. Rose - 380', 'Ms. Rose', '380'],
    ['Dr. Alvarez - B12', 'Dr. Alvarez', 'B12'],
  ])('splits %s', (fused, teacher, room) => {
    expect(splitTeacherAndRoom(fused, undefined)).toEqual({ teacher, room });
  });

  it('leaves a correctly split pair alone', () => {
    expect(splitTeacherAndRoom('Ms. Lieberman', '285')).toEqual({ teacher: 'Ms. Lieberman', room: '285' });
  });

  it('does not split a hyphenated surname, because the tail is not a room', () => {
    expect(splitTeacherAndRoom('Ms. Sanchez - Gomez', undefined)).toEqual({
      teacher: 'Ms. Sanchez - Gomez',
      room: undefined,
    });
  });

  it('does not invent a room when none is printed', () => {
    expect(splitTeacherAndRoom('Ms. Kornet', undefined)).toEqual({ teacher: 'Ms. Kornet', room: undefined });
  });

  it('treats a blank teacher as absent rather than empty, which is what broke HQ-658', () => {
    expect(splitTeacherAndRoom('   ', '  ')).toEqual({ teacher: undefined, room: undefined });
  });

  it('applies through the extractor, not just in isolation', async () => {
    const { client } = stubClient([
      { content: [toolUse('a', { block: 'a', subject: 'Precalculus', teacher: 'Ms. Lieberman - 285' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes[0]).toEqual({
      block: 'a',
      subject: 'Precalculus',
      teacher: 'Ms. Lieberman',
      room: '285',
    });
  });
});

/**
 * The whole sheet at once, as the model would emit it if it read the real printout
 * correctly. This is the shape the app has to end up with: five classes, two blank blocks,
 * five lunch waves, and nothing named "Unscheduled" anywhere.
 */
describe('the real Grade 11 sheet, end to end', () => {
  it('produces five courses, two free blocks and five lunch waves', async () => {
    const { client } = stubClient([
      {
        content: [
          toolUse('1', { block: 'a', subject: 'Precalculus', teacher: 'Ms. Lieberman', room: '285' }),
          toolUse('2', { block: 'b', subject: 'AP English Masks', teacher: 'Ms. Kornet', room: '258' }),
          toolUse('3', { block: 'c', subject: 'Physics', teacher: 'Ms. Courtemanche', room: '134' }),
          toolUse('4', { block: 'd', subject: 'Spanish III', teacher: 'Ms. Rose', room: '380' }),
          toolUse('5', {
            block: 'e',
            subject: 'United States History (Honors)',
            teacher: 'Mr. Turnbull',
            room: '283',
          }),
          // F and G are "Unscheduled" on the real sheet, printed with their letters.
          toolUse('6', { block: 'f', subject: 'Unscheduled' }),
          toolUse('7', { block: 'g', subject: 'Unscheduled' }),
          lunchUse('8', { day: 'monday', wave: 2 }),
          lunchUse('9', { day: 'tuesday', wave: 2 }),
          lunchUse('10', { day: 'wednesday', wave: 2 }),
          lunchUse('11', { day: 'thursday', wave: 2 }),
          lunchUse('12', { day: 'friday', wave: 2 }),
        ],
      },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(result.classes).toEqual([
      { block: 'a', subject: 'Precalculus', teacher: 'Ms. Lieberman', room: '285' },
      { block: 'b', subject: 'AP English Masks', teacher: 'Ms. Kornet', room: '258' },
      { block: 'c', subject: 'Physics', teacher: 'Ms. Courtemanche', room: '134' },
      { block: 'd', subject: 'Spanish III', teacher: 'Ms. Rose', room: '380' },
      { block: 'e', subject: 'United States History (Honors)', teacher: 'Mr. Turnbull', room: '283' },
      { block: 'f', subject: 'Free', teacher: undefined, room: undefined },
      { block: 'g', subject: 'Free', teacher: undefined, room: undefined },
    ]);
    expect(result.lunch).toEqual({ monday: 2, tuesday: 2, wednesday: 2, thursday: 2, friday: 2 });
    expect(result.skipped).toEqual([]);
    // The sheet's own wording never survives - F and G come back as the canonical "Free".
    expect(result.classes.some((c) => c.subject === 'Unscheduled')).toBe(false);
  });
});

/**
 * A busy API is a different failure from a bad photo, and the student must not pay for it.
 * Hit for real on 2026-09-03: a 529 Overloaded while testing, which is exactly what the first
 * week of school looks like when a whole grade scans within the same hour.
 */
describe('a transient model failure', () => {
  function apiError(status: number) {
    return Object.assign(new Error(`${status} overloaded`), { status });
  }

  function flakyClient(failures: number[], then: { content: unknown[] }) {
    const create = vi.fn();
    for (const status of failures) create.mockRejectedValueOnce(apiError(status));
    create.mockResolvedValue(then);
    return { client: { messages: { create } } as unknown as Anthropic, create };
  }

  it.each([408, 429, 500, 502, 503, 504, 529])('retries a %i and then succeeds', async (status) => {
    const { client, create } = flakyClient([status], { content: [toolUse('a', GOOD)] });
    const result = await extractStudentClasses(PHOTO, client);
    expect(create).toHaveBeenCalledTimes(2);
    expect(result.classes).toHaveLength(1);
  });

  // Explicit timeout: the backoff is real time, and the point of the test is that it stops
  // rather than retrying forever. The whole retry budget has to stay small because the route
  // is maxDuration = 60 and three correctness attempts already spend most of that.
  it('gives up after two retries rather than retrying forever', { timeout: 15_000 }, async () => {
    const { client, create } = flakyClient([529, 529, 529], { content: [] });
    await expect(extractStudentClasses(PHOTO, client)).rejects.toThrow(/529/);
    expect(create).toHaveBeenCalledTimes(3);
  });

  it('does not spend a correction attempt on an availability failure', async () => {
    // One 529, then two rounds of the correctness loop. If the two were conflated, the 529
    // would eat one of the three correction attempts and the good block would never land.
    const { client, create } = flakyClient([529], { content: [toolUse('a', GOOD)] });
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.attempts).toBe(1);
    expect(create).toHaveBeenCalledTimes(2);
  });

  it('does NOT retry an error that would fail the same way again', async () => {
    for (const status of [400, 401, 403, 404, 413, 422]) {
      const { client, create } = flakyClient([status], { content: [toolUse('a', GOOD)] });
      await expect(extractStudentClasses(PHOTO, client)).rejects.toThrow();
      expect(create).toHaveBeenCalledTimes(1);
    }
  });

  it('does not retry an error with no status at all', async () => {
    const create = vi.fn().mockRejectedValue(new Error('socket hang up'));
    const client = { messages: { create } } as unknown as Anthropic;
    await expect(extractStudentClasses(PHOTO, client)).rejects.toThrow(/socket/);
    expect(create).toHaveBeenCalledTimes(1);
  });
});

describe('decodeEntities', () => {
  // Found on a real sheet on 2026-09-03: "Health &amp; Wellness". The subject is part of the
  // class document's id, so this is not a display bug - it is a second roster for a class that
  // already exists, and the two never merge.
  it('turns an escaped ampersand back into a class name a human would type', () => {
    expect(decodeEntities('Health &amp; Wellness')).toBe('Health & Wellness');
  });

  it('handles the entities a course name plausibly carries', () => {
    expect(decodeEntities('Rhetoric &amp; Composition')).toBe('Rhetoric & Composition');
    expect(decodeEntities('Writers&apos; Workshop')).toBe("Writers' Workshop");
    expect(decodeEntities('Art &ndash; Ceramics')).toBe('Art – Ceramics');
    expect(decodeEntities('AP &quot;Masks&quot;')).toBe('AP "Masks"');
  });

  it('handles numeric references, decimal and hex', () => {
    expect(decodeEntities('Health &#38; Wellness')).toBe('Health & Wellness');
    expect(decodeEntities('Health &#x26; Wellness')).toBe('Health & Wellness');
  });

  it('unwinds double escaping, which is what two systems in a row produce', () => {
    expect(decodeEntities('Health &amp;amp; Wellness')).toBe('Health & Wellness');
  });

  it('leaves an ordinary ampersand and unknown entities alone', () => {
    expect(decodeEntities('Health & Wellness')).toBe('Health & Wellness');
    expect(decodeEntities('Chem &notarealentity; Lab')).toBe('Chem &notarealentity; Lab');
  });

  // The whole point: after decoding, the escaped and unescaped spellings are the SAME key.
  it('makes the escaped and plain spellings normalize identically', () => {
    expect(normalizeSubject(decodeEntities('Health &amp; Wellness')))
      .toBe(normalizeSubject(decodeEntities('Health & Wellness')));
  });
});

describe('entities are decoded by the PIPELINE, not just by the helper', () => {
  // The tests above prove `decodeEntities` works. They would all still pass if nothing ever
  // called it, which is precisely how the route came to drop `details`: a correct function and a
  // missing call site look identical from the function's own tests.
  it('stores the decoded subject, so the class key matches a hand-typed one', async () => {
    const { client } = stubClient([
      { content: [toolUse('t1', { block: 'c', subject: 'Health &amp; Wellness', teacher: 'Ms. Rose', room: '110' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes[0].subject).toBe('Health & Wellness');
  });

  it('decodes the teacher and room too, since both are part of the key', async () => {
    const { client } = stubClient([
      { content: [toolUse('t1', { block: 'c', subject: 'Ceramics', teacher: 'Mr. O&apos;Brien', room: 'Art &amp; Design' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes[0].teacher).toBe("Mr. O'Brien");
    expect(result.classes[0].room).toBe('Art & Design');
  });

  it('still recognises a free block whose wording arrives escaped', async () => {
    const { client } = stubClient([
      { content: [toolUse('t1', { block: 'g', subject: 'Free&nbsp;Period' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.classes[0].subject).toBe('Free');
  });
});
