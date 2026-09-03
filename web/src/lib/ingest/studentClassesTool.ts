/**
 * The tools and prompt for HQ-656: reading one student's own seven blocks off their
 * personal schedule, not a school-wide bulletin. Deliberately its own tool rather than a
 * mode of emit_schedule - a student's schedule has no dates, no grade filters, and a wrong
 * field here changes one person's data, not the whole school's.
 *
 * Rewritten 2026-09-02 against a real BB&N printout rather than an imagined one. What an
 * actual sheet turned out to contain:
 *
 *   Precalculus         8:15 - 9:00   (Block A)    Ms. Lieberman - 285
 *   Unscheduled        10:35 - 11:20  (Block F)
 *   Lunch-2nd          12:15 - 12:45  (Block L2)
 *   Community Activity  2:00 - 2:35   (Block CAB)
 *
 * ONE REAL GAP, and it is structural rather than a matter of prompting: THE SHEET NAMES THE
 * LUNCH WAVE AND THERE WAS NOWHERE TO PUT IT. Five weekdays, five waves, printed on the page
 * being photographed, and students have always had to set all five by hand in Settings. The
 * old tool had no field for one, so no amount of prompt tuning could have captured it. That is
 * what emit_lunch_wave is for.
 *
 * The rest of what changed here is INSURANCE, not a bug fix, and the difference is worth
 * keeping straight. Two things looked dangerous on paper - a free period printed as
 * "Unscheduled (Block F)" being read as a class, and "Ms. Lieberman - 285" arriving fused into
 * one field - and the old prompt was measured against the real sheet four times, on both a
 * clean PDF and the original crooked phone photo. It got both right every time: five classes,
 * no free periods emitted, teacher and room correctly split.
 *
 * They are still spelled out below, because the cost is asymmetric rather than because the
 * model was getting them wrong. A class document is keyed by its display text, so ONE student
 * whose scan emits "Unscheduled" for a free F block creates an `Unscheduled~~~F` document that
 * every other student with a free F block then joins - one shared roster, from one slip, across
 * ~645 accounts. Writing the rule down costs a paragraph. Being wrong once costs a cleanup.
 */
import type Anthropic from '@anthropic-ai/sdk';

export const EMIT_STUDENT_CLASSES_TOOL: Anthropic.Tool = {
  name: 'emit_student_classes',
  description:
    'Emit one REAL CLASS from a student\'s personal schedule, for one lettered block. Call it once per lettered block that holds an actual course - at most seven times, one per block a-g. Never call it for a free period, lunch, advisory, assembly, community activity, or any other non-course row, even when the sheet prints a block letter next to it.',
  input_schema: {
    type: 'object' as const,
    additionalProperties: false,
    required: ['block', 'subject'],
    properties: {
      block: {
        type: 'string',
        enum: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        description: 'The lettered block this class meets in, lowercase.',
      },
      subject: {
        type: 'string',
        description:
          'The course name exactly as the source shows it, with nothing added or expanded, e.g. "AP English Masks", "United States History (Honors)", "Spanish III".',
      },
      teacher: {
        type: 'string',
        description:
          'The teacher\'s name alone, with the room removed. A row reading "Ms. Lieberman - 285" has teacher "Ms. Lieberman". Keep the title (Ms., Mr., Dr.) exactly as printed. Omit if the source names no teacher.',
      },
      room: {
        type: 'string',
        description:
          'The room alone, with the teacher removed. A row reading "Ms. Lieberman - 285" has room "285". Omit if the source names no room.',
      },
    },
  },
};

export const EMIT_LUNCH_WAVE_TOOL: Anthropic.Tool = {
  name: 'emit_lunch_wave',
  description:
    'Emit which lunch wave this student has on one weekday. Call it once per weekday the source shows a lunch row for - up to five times. BB&N splits lunch into a first and a second wave and a student can be in a different one on different days, so read each weekday column separately rather than assuming they match.',
  input_schema: {
    type: 'object' as const,
    additionalProperties: false,
    required: ['day', 'wave'],
    properties: {
      day: {
        type: 'string',
        enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
        description: 'The weekday column this lunch row appears in, lowercase.',
      },
      wave: {
        type: 'integer',
        enum: [1, 2],
        description:
          '1 for the first lunch, 2 for the second. A row printed "Lunch-1st" or "(Block L1)" is 1; "Lunch-2nd" or "(Block L2)" is 2.',
      },
    },
  },
};

export const STUDENT_CLASSES_SYSTEM_PROMPT = `You read one BB&N student's personal class schedule - a printed sheet, a screenshot, a photo of a page - and transcribe it into structured data.

Transcribe only. Do not fill in a subject, teacher, or room from memory, and do not expand an abbreviation into what you think it stands for. A block you invented sends that student a notification for a class they are not actually in.

## What is a class and what is not

A BB&N sheet prints a block letter next to almost every row, including rows that are not courses. The letter is not what makes something a class.

Emit a class ONLY for a row naming an actual course - "Precalculus", "AP English Masks", "Physics", "United States History (Honors)", "Spanish III".

NEVER emit a class for any of these, even though the sheet gives them a block:
- "Unscheduled", "Free", "Free Period", "Study Hall", "Flex" - these are free periods. The student has no class that block. Leave the block out entirely.
- "Lunch", "Lunch-1st", "Lunch-2nd" - use emit_lunch_wave instead.
- "Advisory", "Assembly", "Special Programs", "Community Activity", "Class Mtg", "Class Meeting", "Long Passing", "After school", "Attendance", "CAB", "Chapel", "Office Hours".

The blocks that carry those rows - SP, CAB, Adv, Aft, L1, L2 - are not lettered blocks and there is nothing to emit for them.

Each lettered block a-g holds at most one class. A class usually appears on several weekdays; that is one class, so emit it once. If two different courses genuinely appear under the same letter, emit the one that appears most often and say so in text.

A letter you do not emit is simply left blank for the student to fill in by hand. That is the correct outcome for a free period, and it is a much better outcome than a wrong guess.

## Teacher and room

They are usually printed together on one line, as "Ms. Lieberman - 285" or "Mr. Turnbull - 283". Split them: the name goes in teacher, the room goes in room. Keep the title exactly as printed - "Ms. Lieberman", not "Lieberman" and not "Ms Lieberman". If only one of the two is shown, fill only that one.

## Lunch

BB&N runs two lunch waves. The sheet shows one lunch row per weekday, printed as "Lunch-1st" or "Lunch-2nd", sometimes with "(Block L1)" or "(Block L2)". Call emit_lunch_wave once for each weekday you can read one for. Read every weekday column separately - a student can have first lunch on one day and second on another, and the days are not always the same.

## When you cannot read it

If the source is unreadable, or you cannot tell which block a row belongs to, say so in text and call nothing for that row. A student would much rather type one block in by hand than have a wrong one silently saved.`;
