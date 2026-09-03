/**
 * Source in, validated classes out. Same shape as extract.ts's loop - invalid output is
 * fed back to the model as a tool error and retried, valid output never writes anywhere
 * on its own - pointed at a different output: one student's seven blocks plus their five
 * lunch waves, instead of a day of bell times.
 *
 * The non-class rejection below is deliberately duplicated with the system prompt. The prompt
 * is a rule and rules hold most of the time; this is the mechanism, and it holds every time.
 *
 * It is insurance rather than a fix: measured against the real sheet four times, on a clean
 * PDF and on the original crooked phone photo, the model never once emitted a free period as a
 * class. It is here because the cost is asymmetric. A class document is keyed by its display
 * text, so ONE student whose scan emits "Unscheduled" for a free F block creates an
 * `Unscheduled~~~F` document that every other student with a free F block then joins - one
 * shared roster across ~645 accounts, from one slip, needing a manual cleanup to undo.
 */
import 'server-only';
import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';
import type { IngestAttachment } from './extract';
import { IMAGE_TYPES, IngestError, attachmentBlock } from './extract';
import {
  EMIT_LUNCH_WAVE_TOOL,
  EMIT_STUDENT_CLASSES_TOOL,
  STUDENT_CLASSES_SYSTEM_PROMPT,
} from './studentClassesTool';

export const STUDENT_INGEST_MODEL = 'claude-opus-5';
const MAX_ATTEMPTS = 3;
const MAX_TOKENS = 4000;

/**
 * Rows a BB&N sheet prints with a block letter that are not courses. Matched against the
 * whole subject, case- and punctuation-insensitively, so "Lunch - 2nd", "lunch-2nd" and
 * "LUNCH 2ND" are one entry.
 *
 * Every one of these was read off a real Grade 11 printout except the ones marked defensive.
 * Deliberately NOT a substring match: "Physics" must never be rejected for containing a
 * fragment of something here, so this compares normalised whole strings plus a small number
 * of explicit prefixes.
 */
const NON_CLASS_SUBJECTS = new Set([
  // Free periods. The sheet prints these WITH a block letter, which is why they need naming.
  'unscheduled',
  'free',
  'free period',
  'free block',
  'study hall',
  'studyhall',
  'flex',
  'open',
  'none',
  'n a',
  // Lunch. Handled by emit_lunch_wave instead.
  'lunch',
  'lunch 1st',
  'lunch 2nd',
  'lunch 1',
  'lunch 2',
  'first lunch',
  'second lunch',
  '1st lunch',
  '2nd lunch',
  // Everything else the school puts in a block that is not a course.
  'advisory',
  'advising',
  'assembly',
  'assembly special programs',
  'special programs',
  'special programming',
  'community activity',
  'cab',
  'optional cab',
  'class mtg',
  'class meeting',
  'long passing',
  'passing',
  'after school',
  'afterschool',
  'attendance',
  'faculty time',
  'faculty meeting',
  // Defensive: not on the sheet that was read, but the same kind of row.
  'chapel',
  'office hours',
  'homeroom',
  'recess',
  'break',
]);

/** Prefixes that make a row non-course whatever follows them. */
const NON_CLASS_PREFIXES = ['lunch', 'assembly', 'advisory', 'community activity', 'after school'];

/** Lowercase, strip punctuation and collapse whitespace, so one entry covers its spellings. */
export function normalizeSubject(subject: string): string {
  return subject
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export function isNonClassSubject(subject: string): boolean {
  const normalized = normalizeSubject(subject);
  if (!normalized) return true;
  if (NON_CLASS_SUBJECTS.has(normalized)) return true;
  return NON_CLASS_PREFIXES.some(
    (prefix) => normalized === prefix || normalized.startsWith(`${prefix} `),
  );
}

/**
 * A BB&N sheet prints the teacher and the room on one line, as "Ms. Lieberman - 285". The
 * prompt asks for them split, and in four measured runs the model always did. This is the
 * backstop for the run where it does not.
 *
 * Worth a backstop because a class document is keyed by `Subject~Teacher~Room~Block`, so
 * "Ms. Lieberman - 285" landing whole in `teacher` makes a DIFFERENT document than
 * "Ms. Lieberman" + "285" - two rosters for one real class, which is HQ-877's duplicate
 * problem produced by the feature meant to reduce it.
 *
 * Only splits when `room` is empty, so a model that already did the work is left alone, and
 * only on a trailing token that actually looks like a room.
 */
const ROOM_LIKE = /^[A-Za-z]?\d{1,4}[A-Za-z]?$/;

export function splitTeacherAndRoom(
  teacher?: string,
  room?: string,
): { teacher?: string; room?: string } {
  const cleanTeacher = teacher?.trim();
  const cleanRoom = room?.trim();
  if (!cleanTeacher || cleanRoom) {
    return { teacher: cleanTeacher || undefined, room: cleanRoom || undefined };
  }

  const match = cleanTeacher.match(/^(.*\S)\s+[-‐-―−]\s+(\S+)$/);
  if (!match) return { teacher: cleanTeacher, room: undefined };

  const [, name, tail] = match;
  if (!ROOM_LIKE.test(tail)) return { teacher: cleanTeacher, room: undefined };
  return { teacher: name, room: tail };
}

export const studentClassSchema = z.object({
  block: z.enum(['a', 'b', 'c', 'd', 'e', 'f', 'g']),
  subject: z.string().min(1).max(120),
  teacher: z.string().max(120).optional(),
  room: z.string().max(60).optional(),
});

export const lunchWaveSchema = z.object({
  day: z.enum(['monday', 'tuesday', 'wednesday', 'thursday', 'friday']),
  wave: z.union([z.literal(1), z.literal(2)]),
});

export type StudentClass = z.infer<typeof studentClassSchema>;
export type LunchWave = z.infer<typeof lunchWaveSchema>;
export type LunchWaves = Partial<Record<LunchWave['day'], 1 | 2>>;

export interface ExtractStudentClassesInput {
  attachments: IngestAttachment[];
  notes?: string;
}

export interface ExtractStudentClassesResult {
  classes: StudentClass[];
  lunch: LunchWaves;
  message: string;
  rejected: { input: unknown; issues: string[] }[];
  /** Non-class rows the model emitted as classes anyway, kept so a bad prompt is visible. */
  skipped: { block: string; subject: string }[];
  attempts: number;
}

/** Every validation failure as one flat "path: message" line, for the retry prompt. */
function issueLines(error: z.ZodError): string[] {
  return error.issues.map((issue) => {
    const path = issue.path.length ? issue.path.join('.') : '(root)';
    return `${path}: ${issue.message}`;
  });
}

export async function extractStudentClasses(
  input: ExtractStudentClassesInput,
  client?: Anthropic,
): Promise<ExtractStudentClassesResult> {
  if (!input.attachments.length) {
    throw new IngestError('Nothing to read. Attach a photo, screenshot, or PDF of your schedule.');
  }
  for (const attachment of input.attachments) {
    if (attachment.mediaType !== 'application/pdf' && !IMAGE_TYPES.has(attachment.mediaType)) {
      throw new IngestError(`Cannot read a ${attachment.mediaType} file. Send a PDF or a photo.`);
    }
  }

  const anthropic = client ?? new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

  const firstBlocks: Anthropic.ContentBlockParam[] = input.attachments.map(attachmentBlock);
  firstBlocks.push({
    type: 'text',
    text: input.notes
      ? `Read this student's schedule.\n\nStudent's notes: ${input.notes}`
      : "Read this student's schedule.",
  });

  const messages: Anthropic.MessageParam[] = [{ role: 'user', content: firstBlocks }];
  const classes: StudentClass[] = [];
  const lunch: LunchWaves = {};
  const rejected: { input: unknown; issues: string[] }[] = [];
  const skipped: { block: string; subject: string }[] = [];
  let message = '';
  let attempts = 0;

  while (attempts < MAX_ATTEMPTS) {
    attempts += 1;
    const response = await anthropic.messages.create({
      model: STUDENT_INGEST_MODEL,
      max_tokens: MAX_TOKENS,
      thinking: { type: 'adaptive' },
      system: STUDENT_CLASSES_SYSTEM_PROMPT,
      tools: [EMIT_STUDENT_CLASSES_TOOL, EMIT_LUNCH_WAVE_TOOL],
      messages: [...messages],
    });

    const prose = response.content
      .filter((block): block is Anthropic.TextBlock => block.type === 'text')
      .map((block) => block.text.trim())
      .filter(Boolean)
      .join('\n\n');
    if (prose) message = prose;

    const calls = response.content.filter(
      (block): block is Anthropic.ToolUseBlock =>
        block.type === 'tool_use' &&
        (block.name === EMIT_STUDENT_CLASSES_TOOL.name || block.name === EMIT_LUNCH_WAVE_TOOL.name),
    );
    if (!calls.length) break;

    const results: Anthropic.ToolResultBlockParam[] = [];
    let anyInvalid = false;

    for (const call of calls) {
      const raw = call.input as Record<string, unknown>;

      if (call.name === EMIT_LUNCH_WAVE_TOOL.name) {
        const parsedLunch = lunchWaveSchema.safeParse(raw);
        if (parsedLunch.success) {
          lunch[parsedLunch.data.day] = parsedLunch.data.wave;
          results.push({
            type: 'tool_result',
            tool_use_id: call.id,
            content: `Accepted ${parsedLunch.data.day} lunch.`,
          });
        } else {
          anyInvalid = true;
          const issues = issueLines(parsedLunch.error);
          rejected.push({ input: raw, issues });
          results.push({
            type: 'tool_result',
            tool_use_id: call.id,
            is_error: true,
            content: `Rejected. Fix these and call emit_lunch_wave again for this day:\n${issues.join('\n')}`,
          });
        }
        continue;
      }

      const parsed = studentClassSchema.safeParse(raw);
      if (!parsed.success) {
        anyInvalid = true;
        const issues = issueLines(parsed.error);
        rejected.push({ input: raw, issues });
        results.push({
          type: 'tool_result',
          tool_use_id: call.id,
          is_error: true,
          content: `Rejected. Fix these and call emit_student_classes again for this block:\n${issues.join('\n')}`,
        });
        continue;
      }

      // The mechanism behind the prompt. A free period or a lunch row is not a class, and
      // this is NOT retried: there is nothing for the model to correct, the right outcome is
      // a blank block, and telling it to "try again" invites it to invent something to fill
      // the space.
      if (isNonClassSubject(parsed.data.subject)) {
        skipped.push({ block: parsed.data.block, subject: parsed.data.subject });
        results.push({
          type: 'tool_result',
          tool_use_id: call.id,
          content:
            `Not a class - "${parsed.data.subject}" is a free period or a non-course row, so block ` +
            `${parsed.data.block.toUpperCase()} is left blank on purpose. Do not emit it again and do not ` +
            `substitute another class for it.`,
        });
        continue;
      }

      const { teacher, room } = splitTeacherAndRoom(parsed.data.teacher, parsed.data.room);
      const accepted: StudentClass = {
        block: parsed.data.block,
        subject: parsed.data.subject.trim(),
        teacher,
        room,
      };

      // A later call for the same block replaces the earlier one - the model correcting
      // itself mid-conversation, not a second class in one block.
      const existing = classes.findIndex((c) => c.block === accepted.block);
      if (existing >= 0) classes[existing] = accepted;
      else classes.push(accepted);
      results.push({ type: 'tool_result', tool_use_id: call.id, content: `Accepted block ${accepted.block}.` });
    }

    messages.push({ role: 'assistant', content: response.content });
    messages.push({ role: 'user', content: results });
    if (!anyInvalid) break;
  }

  const acceptedBlocks = new Set(classes.map((c) => c.block));
  const acceptedDays = new Set(Object.keys(lunch));
  const stillRejected = rejected.filter((entry) => {
    const input = entry.input as { block?: unknown; day?: unknown };
    if (typeof input.block === 'string') return !acceptedBlocks.has(input.block as StudentClass['block']);
    if (typeof input.day === 'string') return !acceptedDays.has(input.day);
    return true;
  });

  classes.sort((a, b) => a.block.localeCompare(b.block));
  return { classes, lunch, message, rejected: stillRejected, skipped, attempts };
}
