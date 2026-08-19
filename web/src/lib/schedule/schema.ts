/**
 * The strict schema. Nothing reaches Firestore without passing it.
 *
 * A wrong schedule is worse than no schedule, so this file is deliberately narrow: it
 * accepts the shapes production actually contains and rejects everything else, including
 * plausible-looking model output like a 25-hour time, an unknown block letter, or a
 * lunch-wave split with no `lunchBlock` to split on.
 */
import { z } from 'zod';
import { BLOCK_VALUES, FILTER_VALUES } from './types';
import { isValidIsoDate } from './dates';
import { normalizeTime12, parseTime12 } from './time';

const time = z
  .string()
  .transform((raw, ctx) => {
    const normalized = normalizeTime12(raw);
    if (normalized === null) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: `not a 12-hour time like "8:15 am": ${JSON.stringify(raw)}` });
      return z.NEVER;
    }
    return normalized;
  });

const blockValue = z.enum(BLOCK_VALUES);
const filterValue = z.enum(FILTER_VALUES);

/** A leaf event: a class block or a lunch period. Never contains other events. */
const blockEvent = z.object({
  type: z.literal('block'),
  block: blockValue,
  name: z.string().min(1).max(120),
  startTime: time,
  endTime: time,
  room: z.string().min(1).max(60).optional(),
});

const lunchEvent = z.object({
  type: z.literal('lunch'),
  startTime: time,
  endTime: time,
});

/**
 * Backwards is always wrong. Zero-length is not: production carries a handful of marker
 * rows that start and end at the same minute, and rejecting them would make this schema
 * unable to describe days that are already published. The review screen flags those
 * instead (warnings.ts).
 */
function checkTimeOrder(event: { startTime: string; endTime: string }, ctx: z.RefinementCtx): void {
  const start = parseTime12(event.startTime);
  const end = parseTime12(event.endTime);
  if (start !== null && end !== null && end < start) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: `endTime ${event.endTime} is before startTime ${event.startTime}`,
    });
  }
}

const leafEvent = z.discriminatedUnion('type', [blockEvent, lunchEvent]).superRefine(checkTimeOrder);

/** A `specific` group: contents that only some people see. One level deep, as production is. */
const groupEvent = z.object({
  type: z.literal('specific'),
  filter: z.array(filterValue).min(1),
  matchMode: z.literal('any').default('any'),
  lunchBlock: blockValue.optional(),
  contents: z.array(leafEvent).min(1),
});

function checkGroup(group: z.infer<typeof groupEvent>, ctx: z.RefinementCtx): void {
  const waves = group.filter.filter((f) => f === 'L1' || f === 'L2');
  const audience = group.filter.filter((f) => f !== 'L1' && f !== 'L2');
  if (waves.length && audience.length) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'a group filters on a lunch wave or on grades, not both' });
  }
  if (waves.length > 1) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'a group covers one lunch wave, not both' });
  }
  if (waves.length && !group.lunchBlock) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'a lunch-wave group needs lunchBlock: which block the wave splits',
    });
  }
  if (!waves.length && group.lunchBlock) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'lunchBlock only belongs on a lunch-wave group' });
  }
  if (new Set(group.filter).size !== group.filter.length) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'filter repeats a value' });
  }
}

/**
 * One discriminated union, so a bad field reports itself ("blocks.0.startTime: ...")
 * rather than collapsing to "invalid input". The retry loop feeds these lines straight
 * back to the model, so a vague message costs an attempt.
 */
export const scheduleEventSchema = z
  .discriminatedUnion('type', [blockEvent, lunchEvent, groupEvent])
  .superRefine((event, ctx) => {
    if (event.type === 'specific') checkGroup(event, ctx);
    else checkTimeOrder(event, ctx);
  });

export const scheduleDaySchema = z
  .object({
    type: z.enum(['blocks', 'noschool', 'image']),
    reason: z.string().max(200).optional(),
    imageUrl: z.string().url().optional(),
    blocks: z.array(scheduleEventSchema).optional(),
  })
  .superRefine((day, ctx) => {
    if (day.type === 'blocks') {
      if (!day.blocks?.length) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'a "blocks" day needs at least one block' });
      }
    } else if (day.blocks?.length) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: `a "${day.type}" day carries no blocks` });
    }
    if (day.type === 'noschool' && !day.reason?.trim()) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'a "noschool" day needs a reason: students see it' });
    }
    if (day.type === 'image' && !day.imageUrl) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'an "image" day needs imageUrl' });
    }
    // Two lunch-wave groups covering the same block must cover both waves, not one twice.
    const waveGroups = (day.blocks ?? []).filter(
      (e): e is z.infer<typeof groupEvent> => e.type === 'specific' && e.filter.some((f: string) => f === 'L1' || f === 'L2'),
    );
    const byBlock = new Map<string, string[]>();
    for (const g of waveGroups) {
      const key = g.lunchBlock ?? '?';
      byBlock.set(key, [...(byBlock.get(key) ?? []), ...g.filter]);
    }
    for (const [block, waves] of byBlock) {
      if (new Set(waves).size !== waves.length) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `block ${block} splits into the same lunch wave twice`,
        });
      }
    }
  });

export const datedScheduleDaySchema = z.object({
  date: z.string().refine(isValidIsoDate, 'date must be a real YYYY-MM-DD date'),
  day: scheduleDaySchema,
});

export type ValidatedDay = z.infer<typeof scheduleDaySchema>;
export type ValidatedDatedDay = z.infer<typeof datedScheduleDaySchema>;

/** Every validation failure as one flat list of "path: message" lines, for the retry prompt. */
export function issueLines(error: z.ZodError): string[] {
  return error.issues.map((issue) => {
    const path = issue.path.length ? issue.path.join('.') : '(root)';
    return `${path}: ${issue.message}`;
  });
}
