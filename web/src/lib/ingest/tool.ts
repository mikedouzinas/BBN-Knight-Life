/**
 * The tool Claude fills in, and the prompt that tells it what a BB&N schedule is.
 *
 * The schema is flat by one level on purpose: a `specific` group holds leaf events and
 * nothing deeper. All 79 production days nest exactly one level.
 *
 * `strict: true` is deliberately NOT set. Measured 2026-08-19 against claude-opus-5: this
 * schema returns `400 invalid_request_error: Schema is too complex` after about three
 * minutes of waiting. Constrained decoding is not the gate here anyway. The gate is
 * schema.ts, which re-validates every emitted day and feeds its own error text back for
 * a retry, and it catches the failures that matter (a wrong time, a lunch wave with no
 * block to split) which a JSON-shape constraint never would.
 */
import type Anthropic from '@anthropic-ai/sdk';

const TIME_DESCRIPTION = '12-hour time exactly as "8:15 am" or "12:05 pm". Lowercase am/pm, one space.';

const leafEvent = {
  type: 'object' as const,
  additionalProperties: false,
  required: ['type', 'startTime', 'endTime'],
  properties: {
    type: { type: 'string', enum: ['block', 'lunch'], description: '"lunch" for a lunch period, "block" for everything else.' },
    block: {
      type: 'string',
      enum: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'advisory', 'other'],
      description: 'Required on "block". The letter block this is, lowercase. "advisory" for advisory, "other" for anything that is not a lettered class (assembly, meeting, activity).',
    },
    name: {
      type: 'string',
      description: 'Required on "block". What students see: "E", "Extended B", "Assembly", "Class Meeting". Copy the source wording.',
    },
    startTime: { type: 'string', description: TIME_DESCRIPTION },
    endTime: { type: 'string', description: TIME_DESCRIPTION },
    room: { type: 'string', description: 'Only if the source names a room.' },
  },
};

export const EMIT_SCHEDULE_TOOL: Anthropic.Tool = {
  name: 'emit_schedule',
  description:
    'Emit one day of the BB&N Upper School schedule, transcribed from the source. Call it once per day the source describes. Do not call it for a day the source does not cover, and do not fill in a day from memory or from a normal week.',
  input_schema: {
    type: 'object' as const,
    additionalProperties: false,
    required: ['date', 'type'],
    properties: {
      date: { type: 'string', description: 'The date this schedule is for, YYYY-MM-DD. Take the year from the source; if the source omits it, use the year given in the request.' },
      type: {
        type: 'string',
        enum: ['blocks', 'noschool', 'image'],
        description: '"blocks" for a school day with a schedule, "noschool" for a holiday or closure, "image" only when the schedule is a picture that cannot be transcribed.',
      },
      reason: { type: 'string', description: 'Why this day is special: "Snow day", "Labor Day", "Orientation Week". Required on "noschool". Short.' },
      imageUrl: { type: 'string', description: 'Only on "image".' },
      blocks: {
        type: 'array',
        description: 'Required on "blocks". Every row of the day, in the order the source lists them.',
        items: {
          type: 'object',
          additionalProperties: false,
          required: ['type'],
          properties: {
            type: {
              type: 'string',
              enum: ['block', 'lunch', 'specific'],
              description: '"specific" wraps rows only some people attend. "block" and "lunch" apply to everyone.',
            },
            block: leafEvent.properties.block,
            name: leafEvent.properties.name,
            startTime: leafEvent.properties.startTime,
            endTime: leafEvent.properties.endTime,
            room: leafEvent.properties.room,
            filter: {
              type: 'array',
              items: { type: 'string', enum: ['9', '10', '11', '12', 'teacher', 'L1', 'L2'] },
              description: 'Required on "specific". Either grades (and "teacher" if faculty are included) OR one lunch wave, never both. "L1" is first lunch, "L2" is second.',
            },
            lunchBlock: {
              type: 'string',
              enum: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
              description: 'Required when filter is L1 or L2: the letter block that splits around lunch.',
            },
            contents: { type: 'array', items: leafEvent, description: 'Required on "specific". The rows this group sees.' },
          },
        },
      },
    },
  },
};

export const SYSTEM_PROMPT = `You transcribe Buckingham Browne & Nichols Upper School schedule changes into structured data for the Knight Life app, which about 600 students use to know where to be.

Transcribe. Do not infer, complete, or tidy. If the source does not say something, leave it out. A block you invented sends students to a room they do not have a class in.

The school day
- Classes sit in lettered blocks a through g. A row named "E" is block e. "Extended B" is block b. "F1" and "G2" are still blocks f and g.
- Advisory uses block "advisory". Assemblies, class meetings, activities, workshops and anything else that is not a lettered class use block "other".
- Lunch is its own row type, not a block.

Two things the schedule splits on
1. Lunch waves. When some students have lunch while others are in class, that is two "specific" groups over the same lettered block: one with filter ["L1"] and one with filter ["L2"], both carrying lunchBlock set to the letter that splits. First lunch is L1. A row labelled "G1" is normally the class the second-lunch students attend first, and "G2" the one first-lunch students attend after eating; use the times in the source to decide, not the label.
2. Grades. "Gr. 9 Class Meeting", "New 10/11s Orientation", "Seniors only" become a "specific" group whose filter lists those grades. Include "teacher" in the filter when faculty attend too. Anything the whole school attends is not a "specific" group.

Rules
- Times come out exactly as "8:15 am". Never 24-hour, never "8.15", never a missing meridiem. A morning row is am and an afternoon row is pm even when the source omits it.
- Keep the source's own names for rows. Do not rewrite "Dessert in the Courtyard" into "Dessert".
- One call to emit_schedule per day. A source covering four days is four calls.
- If the source is unreadable, or you cannot tell which date it is for, say so in text and call nothing. An admin would rather retype one day than publish a wrong one.`;

export function buildUserPreamble(input: { defaultYear: number; hintDate?: string; notes?: string }): string {
  const lines = [
    `Today's school year is ${input.defaultYear}-${input.defaultYear + 1}. Use ${input.defaultYear} as the year when the source omits one and the month is August through December, otherwise ${input.defaultYear + 1}.`,
  ];
  if (input.hintDate) lines.push(`The admin says this source is for ${input.hintDate}. Use that unless the source clearly says otherwise.`);
  if (input.notes) lines.push(`Admin notes: ${input.notes}`);
  lines.push('Transcribe every day this source describes.');
  return lines.join('\n');
}
