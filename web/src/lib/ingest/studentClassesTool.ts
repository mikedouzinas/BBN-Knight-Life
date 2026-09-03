/**
 * The tools and prompt for HQ-656: reading one student's own seven blocks off their
 * personal schedule, not a school-wide bulletin. Deliberately its own tool rather than a
 * mode of emit_schedule - a student's schedule has no dates, no grade filters, and a
 * wrong field here changes one person's data, not the whole school's.
 *
 * emit_student_details is separate from emit_student_classes because it is a single
 * fact about the student, not a per-block record - called at most once, where classes
 * are called once per block. Every field on it is optional and independent: a sheet
 * that shows lunch but not advisory should still report the lunch it found.
 */
import type Anthropic from '@anthropic-ai/sdk';

export const EMIT_STUDENT_CLASSES_TOOL: Anthropic.Tool = {
  name: 'emit_student_classes',
  description:
    'Emit one class from a student\'s personal schedule, for one lettered block. Call it once per block the source shows - up to seven times, one per block a-g. Do not call it for a block the source does not show, and do not invent a class from memory.',
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
          'The class name exactly as the source shows it, e.g. "AP Physics C", "Precalculus AB (Honors)". Use exactly "Free" when the source shows this block but marks it unscheduled - blank, "Free", "Study Hall", or similar - rather than skipping the block.',
      },
      teacher: { type: 'string', description: 'The teacher\'s name, only if the source names one.' },
      room: { type: 'string', description: 'The room number or name, only if the source names one.' },
    },
  },
};

export const EMIT_STUDENT_DETAILS_TOOL: Anthropic.Tool = {
  name: 'emit_student_details',
  description:
    'Emit whichever of lunch wave, grade, and advisory room the source shows for this student. Call it at most once. Omit any field the source does not show - do not guess.',
  input_schema: {
    type: 'object' as const,
    additionalProperties: false,
    properties: {
      lunch: {
        type: 'string',
        enum: ['1st Lunch', '2nd Lunch'],
        description: 'Which lunch wave the student is assigned to, only if the source states it.',
      },
      grade: {
        type: 'string',
        enum: ['9', '10', '11', '12'],
        description: 'The student\'s grade level, only if the source states it.',
      },
      advisory: {
        type: 'string',
        description: 'The advisory room number or name, only if the source states it.',
      },
    },
  },
};

export const STUDENT_CLASSES_SYSTEM_PROMPT = `You read one BB&N student's personal class schedule - a printed sheet, a screenshot, a photo of a page - and transcribe their lettered blocks (a through g) into structured data.

Transcribe only. Do not infer a block the source does not show, and do not fill in a subject, teacher, or room from memory. A block you invented sends that student a notification for a class they are not actually in.

Each lettered block appears at most once. Two different situations look similar but are not:

- The block letter is ON the source, but marked as unscheduled - blank, "Free", "Study Hall", or similar. This IS shown, so call emit_student_classes for it with subject exactly "Free" and no teacher or room. Leaving it out would look identical to a block the sheet never mentioned, and the student loses the fact that block is deliberately open.
- The block letter does not appear on the source at all - the sheet just does not cover it. Do not call emit_student_classes for that letter. It is left blank for the student to fill in by hand if they need to; a guess here is worse than a gap, because "Free" would be as much an invention as any other subject.

Call emit_student_classes once per block the source actually shows (scheduled or explicitly free), up to seven times. If the source is unreadable, or you cannot tell which block a row belongs to, say so in text and call nothing for that row - a student would rather type one block in by hand than have a wrong one silently saved.

Separately, if the source also shows which lunch wave (1st or 2nd) the student is assigned to, their grade level, or their advisory room, call emit_student_details once with whichever of those it shows. Leave out any field it does not show rather than guessing - an empty field is left for the student to fill in by hand, a wrong one silently overwrites what they already had set.`;
