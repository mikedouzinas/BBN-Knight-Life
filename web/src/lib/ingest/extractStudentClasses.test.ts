/**
 * The retry loop for HQ-656, with a stubbed model - offline, same as extract.test.ts.
 * What's being proven: invalid output goes back to the model with the reason attached
 * and is never returned as if it were an accepted class.
 */
import { describe, expect, it, vi } from 'vitest';
import type Anthropic from '@anthropic-ai/sdk';
import { IngestError } from './extract';
import {
  extractStudentClasses,
  isNonClassSubject,
  splitTeacherAndRoom,
} from './extractStudentClasses';

function toolUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_student_classes', input };
}

function lunchUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_lunch_wave', input };
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
describe('a row that is not a class', () => {
  // The exact strings a BB&N sheet prints, with the block letter it prints beside them.
  it.each([
    ['Unscheduled', 'the free-period label on the real sheet, printed WITH a block letter'],
    ['unscheduled', 'case'],
    ['Free', 'other schools word it this way'],
    ['Free Period', ''],
    ['Study Hall', ''],
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
  ])('rejects %s', (subject) => {
    expect(isNonClassSubject(subject)).toBe(true);
  });

  // The other half, and the more important one: a real course must never be rejected for
  // containing a fragment of something on the list.
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
    expect(isNonClassSubject(subject)).toBe(false);
  });

  it('is dropped rather than saved, and the block is left blank', async () => {
    const { client } = stubClient([
      {
        content: [
          toolUse('a', { block: 'a', subject: 'Precalculus', teacher: 'Ms. Lieberman', room: '285' }),
          toolUse('b', { block: 'f', subject: 'Unscheduled' }),
          toolUse('c', { block: 'g', subject: 'Unscheduled' }),
        ],
      },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(result.classes.map((c) => c.block)).toEqual(['a']);
    expect(result.skipped).toEqual([
      { block: 'f', subject: 'Unscheduled' },
      { block: 'g', subject: 'Unscheduled' },
    ]);
  });

  it('does not cost a retry, because there is nothing for the model to correct', async () => {
    const { client, create } = stubClient([{ content: [toolUse('a', { block: 'f', subject: 'Unscheduled' })] }]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(create).toHaveBeenCalledTimes(1);
    expect(result.attempts).toBe(1);
    expect(result.rejected).toEqual([]);
  });

  it('is told not to substitute another class for the blank block', async () => {
    const { client, create } = stubClient([
      { content: [toolUse('a', { block: 'f', subject: 'Unscheduled' }), toolUse('b', { block: 'b', subject: '' })] },
      { content: [toolUse('c', { block: 'b', subject: 'AP English Masks' })] },
    ]);
    await extractStudentClasses(PHOTO, client);

    const followUp = create.mock.calls[1][0] as Anthropic.MessageCreateParamsNonStreaming;
    const toolResults = followUp.messages.at(-1)!.content as { is_error?: boolean; content?: string }[];
    expect(toolResults[0].content).toMatch(/left blank on purpose/);
    expect(toolResults[0].content).toMatch(/do not\s+substitute another class/i);
    expect(toolResults[0].is_error).toBeUndefined();
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
  it('produces five classes, two blank blocks and five lunch waves', async () => {
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
    ]);
    expect(result.lunch).toEqual({ monday: 2, tuesday: 2, wednesday: 2, thursday: 2, friday: 2 });
    expect(result.skipped.map((s) => s.block)).toEqual(['f', 'g']);
    expect(result.classes.some((c) => c.subject === 'Unscheduled')).toBe(false);
  });
});
