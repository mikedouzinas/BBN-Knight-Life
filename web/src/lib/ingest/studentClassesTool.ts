/**
 * The tool and prompt for HQ-656: reading one student's own seven blocks off their
 * personal schedule, not a school-wide bulletin. Deliberately its own tool rather than a
 * mode of emit_schedule - a student's schedule has no dates, no lunch waves, no grade
 * filters, and a wrong field here changes one person's data, not the whole school's.
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
        description: 'The class name exactly as the source shows it, e.g. "AP Physics C", "Precalculus AB (Honors)".',
      },
      teacher: { type: 'string', description: 'The teacher\'s name, only if the source names one.' },
      room: { type: 'string', description: 'The room number or name, only if the source names one.' },
    },
  },
};

export const STUDENT_CLASSES_SYSTEM_PROMPT = `You read one BB&N student's personal class schedule - a printed sheet, a screenshot, a photo of a page - and transcribe their lettered blocks (a through g) into structured data.

Transcribe only. Do not infer a block the source does not show, and do not fill in a subject, teacher, or room from memory. A block you invented sends that student a notification for a class they are not actually in.

Each lettered block appears at most once. If the source does not show every letter - a free period, a study hall, a block the sheet just does not cover - simply do not call emit_student_classes for that letter. It is left blank for the student to fill in by hand if they need to.

Call emit_student_classes once per block the source actually shows, up to seven times. If the source is unreadable, or you cannot tell which block a row belongs to, say so in text and call nothing for that row - a student would rather type one block in by hand than have a wrong one silently saved.`;
