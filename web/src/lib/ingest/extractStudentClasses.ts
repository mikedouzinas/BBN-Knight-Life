/**
 * Source in, validated classes out. Same shape as extract.ts's loop - invalid output is
 * fed back to the model as a tool error and retried, valid output never writes anywhere
 * on its own - pointed at a different output: one student's seven blocks plus their five
 * lunch waves, instead of a day of bell times.
 *
 * A FREE BLOCK IS KEPT, a non-block row is not, and the difference is the whole shape of the
 * filter below. "Unscheduled (Block F)" means the student has F open - that is an answer, and
 * Mike wants it visible, because seeing who else is free in your block is the point. "Lunch-2nd
 * (Block L2)" is not a block at all and must never become a class.
 *
 * So NON_BLOCK_ROWS rejects the second kind only, and FREE_SUBJECTS normalises the first kind
 * onto one spelling. The prompt says the same things; this is the mechanism behind it, because
 * a prompt is a rule and rules hold most of the time. The cost of one slip is not a bad row on
 * a screen: a class is keyed by its text, so a single scan emitting the sheet's own wording
 * ("Unscheduled") instead of "Free" starts a SECOND shared roster alongside the real one, and
 * the two never merge.
 */
import 'server-only';
import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';
import type { IngestAttachment } from './extract';
import { IMAGE_TYPES, IngestError, attachmentBlock } from './extract';
import {
  EMIT_LUNCH_WAVE_TOOL,
  EMIT_STUDENT_CLASSES_TOOL,
  EMIT_STUDENT_DETAILS_TOOL,
  STUDENT_CLASSES_SYSTEM_PROMPT,
} from './studentClassesTool';

export const STUDENT_INGEST_MODEL = 'claude-opus-5';
const MAX_ATTEMPTS = 3;
const MAX_TOKENS = 4000;

/**
 * Retries for a busy API, which is a different failure from a bad photo.
 *
 * MAX_ATTEMPTS above is the CORRECTNESS loop: the model emitted something invalid and is being
 * asked to fix it. This is the AVAILABILITY loop: the request never landed. Conflating them
 * would let a single 529 eat one of the three correction attempts.
 *
 * It matters on one specific day. Hundreds of students set their classes up in the same week,
 * many in the same hour, and 529 Overloaded is what that looks like from here - hit while
 * testing this on 2026-09-03. Without a retry, a student sees "that scan failed" for something
 * that would have worked half a second later.
 */
const TRANSIENT_STATUSES = new Set([408, 429, 500, 502, 503, 504, 529]);

/**
 * Two retries, not more, and a short backoff - because this shares a 60-second budget.
 *
 * The route is `maxDuration = 60`, and one Opus call on a schedule photo measured ~12s. Three
 * correctness attempts is already ~36s of that, so the availability retries have to be cheap
 * or a scan that would have succeeded gets killed by the platform instead. Worst case here is
 * about 1.5s of waiting per correctness attempt, which fits.
 */
const MAX_TRANSIENT_RETRIES = 2;
const RETRY_BASE_MS = 400;

function isTransient(error: unknown): boolean {
  const status = (error as { status?: number } | null)?.status;
  return typeof status === 'number' && TRANSIENT_STATUSES.has(status);
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * One model call, retried only when the failure was the API being unavailable.
 *
 * Anything else - a bad request, an auth problem, a refusal - is thrown straight through,
 * because retrying it just spends the same money on the same answer.
 */
async function createWithRetry(
  anthropic: Anthropic,
  params: Anthropic.MessageCreateParamsNonStreaming,
): Promise<Anthropic.Message> {
  let lastError: unknown;
  for (let attempt = 0; attempt <= MAX_TRANSIENT_RETRIES; attempt += 1) {
    try {
      return await anthropic.messages.create(params);
    } catch (error) {
      if (!isTransient(error) || attempt === MAX_TRANSIENT_RETRIES) throw error;
      lastError = error;
      // Exponential, with jitter, because every phone in the grade retrying in lockstep is
      // what caused the overload in the first place.
      const backoff = RETRY_BASE_MS * 2 ** attempt + Math.random() * RETRY_BASE_MS;
      console.warn(
        `[student-classes] transient ${(error as { status?: number }).status} from the model, retrying in ${Math.round(backoff)}ms`,
      );
      await sleep(backoff);
    }
  }
  throw lastError;
}

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
const NON_BLOCK_ROWS = new Set([
  // Lunch. Handled by emit_lunch_wave instead.
  'lunch', 'lunch 1st', 'lunch 2nd', 'lunch 1', 'lunch 2',
  'first lunch', 'second lunch', '1st lunch', '2nd lunch',
  'l1', 'l2',
  // School-wide activities that carry a block-shaped label but are not lettered blocks.
  'advisory', 'advising', 'adv',
  'assembly', 'assembly special programs', 'special programs', 'special programming', 'sp',
  'community activity', 'cab', 'optional cab',
  'class mtg', 'class meeting',
  'long passing', 'passing',
  'after school', 'afterschool', 'aft', 'attendance',
  'faculty time', 'faculty meeting',
  // Not on the sheet that was read, but the same kind of row.
  'chapel', 'office hours', 'homeroom', 'recess', 'break', 'flex block', 'activity period',
]);

/** Prefixes that make a row non-block whatever follows them. */
const NON_BLOCK_PREFIXES = ['lunch', 'assembly', 'advisory', 'community activity', 'after school'];

/**
 * Every wording a sheet uses for "this block is open", normalised onto one.
 *
 * The canonical spelling is exactly `Free`, and that matters more than it looks: the class
 * document is keyed by its subject text, so students whose sheets said "Unscheduled" and
 * "Study Hall" would otherwise land on two different rosters for the same empty block.
 */
const FREE_SUBJECTS = new Set([
  'free', 'free period', 'free block', 'unscheduled', 'unassigned',
  'study hall', 'studyhall', 'study', 'open', 'none', 'n a', 'no class', 'flex',
]);

export const FREE_SUBJECT = 'Free';

/** Lowercase, strip punctuation and collapse whitespace, so one entry covers its spellings. */
export function normalizeSubject(subject: string): string {
  return subject.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

/** Named entities worth handling. Anything else numeric is covered by the two patterns below. */
const NAMED_ENTITIES: Record<string, string> = {
  amp: '&',
  apos: "'",
  quot: '"',
  lt: '<',
  gt: '>',
  nbsp: ' ',
  ndash: '–',
  mdash: '—',
  rsquo: '’',
  lsquo: '‘',
  rdquo: '”',
  ldquo: '“',
  hellip: '…',
};

/**
 * Turns `Health &amp; Wellness` back into `Health & Wellness`.
 *
 * This is a CORRECTNESS fix, not a cosmetic one. The subject is part of the class document's id,
 * so `Health &amp; Wellness` and `Health & Wellness` are two different documents - two rosters for
 * one real class, each showing half the students in it, and they never merge. It is the same
 * failure as a sheet's "Unscheduled" surviving instead of "Free", arriving by a different route.
 *
 * Seen on a real sheet on 2026-09-03. The model transcribes what it reads, and school systems
 * export HTML, so an ampersand reaches the page already escaped often enough to matter: "Health &
 * Wellness", "Science & Technology", "Rhetoric & Composition" are ordinary BB&N course names.
 *
 * Deliberately not a full HTML parser. These are course names, not documents; the named list plus
 * numeric references covers everything that plausibly appears, and a real parser here would be a
 * dependency and an attack surface for no gain. Applied repeatedly, because a double-escaped
 * `&amp;amp;` is exactly the sort of thing that comes out of two systems in a row.
 */
export function decodeEntities(value: string): string {
  let out = value;
  for (let pass = 0; pass < 3; pass += 1) {
    const next = out
      .replace(/&([a-zA-Z]+);/g, (whole, name: string) => NAMED_ENTITIES[name.toLowerCase()] ?? whole)
      .replace(/&#(\d+);/g, (_, code: string) => String.fromCodePoint(Number(code)))
      .replace(/&#[xX]([0-9a-fA-F]+);/g, (_, code: string) => String.fromCodePoint(parseInt(code, 16)));
    if (next === out) break;
    out = next;
  }
  return out;
}

/** A row that is not a lettered block at all, and must never become a class. */
export function isNonBlockRow(subject: string): boolean {
  const normalized = normalizeSubject(subject);
  if (!normalized) return true;
  if (NON_BLOCK_ROWS.has(normalized)) return true;
  return NON_BLOCK_PREFIXES.some((p) => normalized === p || normalized.startsWith(`${p} `));
}

/** A block the sheet shows as open. Kept, and reported under one spelling. */
export function isFreeSubject(subject: string): boolean {
  return FREE_SUBJECTS.has(normalizeSubject(subject));
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

export const studentDetailsSchema = z.object({
  grade: z.enum(['9', '10', '11', '12']).optional(),
});

export const lunchWaveSchema = z.object({
  day: z.enum(['monday', 'tuesday', 'wednesday', 'thursday', 'friday']),
  wave: z.union([z.literal(1), z.literal(2)]),
});

export type StudentClass = z.infer<typeof studentClassSchema>;
export type StudentDetails = z.infer<typeof studentDetailsSchema>;
export type LunchWave = z.infer<typeof lunchWaveSchema>;
export type LunchWaves = Partial<Record<LunchWave['day'], 1 | 2>>;

export interface ExtractStudentClassesInput {
  attachments: IngestAttachment[];
  notes?: string;
}

export interface ExtractStudentClassesResult {
  classes: StudentClass[];
  lunch: LunchWaves;
  /** The student's grade, when the sheet's header states it. */
  details: StudentDetails;
  message: string;
  rejected: { input: unknown; issues: string[] }[];
  /** Non-block rows the model emitted as classes anyway, kept so a bad prompt is visible. */
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
  let details: StudentDetails = {};
  const rejected: { input: unknown; issues: string[] }[] = [];
  const skipped: { block: string; subject: string }[] = [];
  let message = '';
  let attempts = 0;

  while (attempts < MAX_ATTEMPTS) {
    attempts += 1;
    const response = await createWithRetry(anthropic, {
      model: STUDENT_INGEST_MODEL,
      max_tokens: MAX_TOKENS,
      thinking: { type: 'adaptive' },
      system: STUDENT_CLASSES_SYSTEM_PROMPT,
      tools: [EMIT_STUDENT_CLASSES_TOOL, EMIT_LUNCH_WAVE_TOOL, EMIT_STUDENT_DETAILS_TOOL],
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
        (block.name === EMIT_STUDENT_CLASSES_TOOL.name ||
          block.name === EMIT_LUNCH_WAVE_TOOL.name ||
          block.name === EMIT_STUDENT_DETAILS_TOOL.name),
    );
    if (!calls.length) break;

    const results: Anthropic.ToolResultBlockParam[] = [];
    let anyInvalid = false;

    for (const call of calls) {
      const raw = call.input as Record<string, unknown>;

      if (call.name === EMIT_STUDENT_DETAILS_TOOL.name) {
        const parsedDetails = studentDetailsSchema.safeParse(raw);
        if (parsedDetails.success) {
          // Merged rather than replaced, so a second call adding advisory does not drop the
          // grade the first one found.
          details = { ...details, ...parsedDetails.data };
          results.push({ type: 'tool_result', tool_use_id: call.id, content: 'Accepted student details.' });
        } else {
          anyInvalid = true;
          const issues = issueLines(parsedDetails.error);
          rejected.push({ input: raw, issues });
          results.push({
            type: 'tool_result',
            tool_use_id: call.id,
            is_error: true,
            content: `Rejected. Fix these and call emit_student_details again:\n${issues.join('\n')}`,
          });
        }
        continue;
      }

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

      // A row that is not a lettered block at all. NOT retried: there is nothing for the model
      // to correct, the right outcome is that the row simply is not a class, and telling it to
      // "try again" invites it to invent something to fill the space.
      if (isNonBlockRow(parsed.data.subject)) {
        skipped.push({ block: parsed.data.block, subject: parsed.data.subject });
        results.push({
          type: 'tool_result',
          tool_use_id: call.id,
          content:
            `Not a block - "${parsed.data.subject}" is lunch or a school-wide activity, not one of ` +
            `this student's lettered blocks. Dropped. Do not emit it again and do not substitute ` +
            `another class for block ${parsed.data.block.toUpperCase()}.`,
        });
        continue;
      }

      // A free block IS an answer, and it is normalised onto one spelling so that two students
      // whose sheets said "Unscheduled" and "Study Hall" land on the same roster rather than
      // starting two.
      // Entities are decoded BEFORE anything else looks at the text, because everything after
      // this point either compares it or stores it as part of a document id. `Health &amp;
      // Wellness` reaching the id makes a second roster for a class that already exists.
      const subjectText = decodeEntities(parsed.data.subject);
      const free = isFreeSubject(subjectText);
      const { teacher, room } = free
        ? { teacher: undefined, room: undefined }
        : splitTeacherAndRoom(
            parsed.data.teacher === undefined ? undefined : decodeEntities(parsed.data.teacher),
            parsed.data.room === undefined ? undefined : decodeEntities(parsed.data.room),
          );
      const accepted: StudentClass = {
        block: parsed.data.block,
        subject: free ? FREE_SUBJECT : subjectText.trim(),
        teacher,
        room,
      };

      // A later call for the same block replaces the earlier one - the model correcting
      // itself mid-conversation, not a second class in one block.
      //
      // ONE EXCEPTION, and it is the C-block bug Mike found on 2026-09-03. A letter can be a
      // course on one weekday and print "Unscheduled" under the same letter on the other four
      // - an arts or wellness course meeting once a week does exactly this - so BOTH answers
      // are genuinely on the page and the model can emit both. Last-write-wins made the
      // outcome depend on which order they arrived in, so the same photo read twice gave the
      // course once and a free block the next time.
      //
      // A course beats "Free" here whatever the order. The two errors are not symmetric: a
      // course wrongly shown for a block the student is free in is sitting on the review
      // screen with an edit button next to it, while a real course wrongly reduced to "Free"
      // deletes a class they take, takes them off its roster, and shows them nothing to
      // suggest anything is missing.
      const existing = classes.findIndex((c) => c.block === accepted.block);
      if (existing >= 0) {
        if (free && !isFreeSubject(classes[existing].subject)) {
          results.push({
            type: 'tool_result',
            tool_use_id: call.id,
            content:
              `Kept "${classes[existing].subject}" for block ${accepted.block.toUpperCase()}. A letter that holds a ` +
              `course on any weekday is that course, even when the sheet shows it unscheduled on the others.`,
          });
          continue;
        }
        classes[existing] = accepted;
      } else {
        classes.push(accepted);
      }
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
  return { classes, lunch, details, message, rejected: stillRejected, skipped, attempts };
}
