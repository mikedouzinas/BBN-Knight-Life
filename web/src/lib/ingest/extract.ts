/**
 * Source in, validated days out.
 *
 *   input -> model -> validate -+- invalid -> retry with the error, never publish
 *                               +- valid   -> hand back for the human to confirm
 *
 * Nothing in this file writes. It cannot: it has no store. Invalid output is fed back to
 * the model as a tool error and the loop runs again up to MAX_ATTEMPTS, then gives up
 * and says so. Unvalidated model output never leaves this function.
 */
import 'server-only';
import Anthropic from '@anthropic-ai/sdk';
import { datedScheduleDaySchema, issueLines } from '@/lib/schedule/schema';
import type { DatedScheduleDay } from '@/lib/schedule/types';
import { EMIT_SCHEDULE_TOOL, SYSTEM_PROMPT, buildUserPreamble } from './tool';

export const INGEST_MODEL = 'claude-opus-5';
const MAX_ATTEMPTS = 3;
const MAX_TOKENS = 16000;

export interface IngestAttachment {
  /** application/pdf, image/png, image/jpeg, image/gif, image/webp. */
  mediaType: string;
  /** Base64, no data: prefix, no newlines. */
  data: string;
  filename?: string;
}

export interface IngestInput {
  text?: string;
  attachments?: IngestAttachment[];
  /** What the admin thinks the date is. A hint, not an override. */
  hintDate?: string;
  notes?: string;
  /** The calendar year the school year starts in. Defaults to the current year. */
  defaultYear?: number;
}

export interface IngestResult {
  days: DatedScheduleDay[];
  /** Anything the model said in prose, e.g. why it could not read a page. */
  message: string;
  /** Days the model produced that never passed validation, with the reasons. */
  rejected: { input: unknown; issues: string[] }[];
  attempts: number;
}

export class IngestError extends Error {}

const IMAGE_TYPES = new Set(['image/png', 'image/jpeg', 'image/gif', 'image/webp']);

function attachmentBlock(attachment: IngestAttachment): Anthropic.ContentBlockParam {
  if (attachment.mediaType === 'application/pdf') {
    return {
      type: 'document',
      source: { type: 'base64', media_type: 'application/pdf', data: attachment.data },
    };
  }
  if (IMAGE_TYPES.has(attachment.mediaType)) {
    return {
      type: 'image',
      source: {
        type: 'base64',
        media_type: attachment.mediaType as 'image/png' | 'image/jpeg' | 'image/gif' | 'image/webp',
        data: attachment.data,
      },
    };
  }
  throw new IngestError(`Cannot read a ${attachment.mediaType} file. Send a PDF, a photo, or paste the text.`);
}

function buildFirstMessage(input: IngestInput): Anthropic.ContentBlockParam[] {
  const blocks: Anthropic.ContentBlockParam[] = [];
  // Documents and images go before the text, which is the order the API expects.
  for (const attachment of input.attachments ?? []) blocks.push(attachmentBlock(attachment));
  blocks.push({
    type: 'text',
    text: buildUserPreamble({
      defaultYear: input.defaultYear ?? new Date().getFullYear(),
      hintDate: input.hintDate,
      notes: input.notes,
    }),
  });
  if (input.text?.trim()) {
    blocks.push({ type: 'text', text: `Source:\n\n${input.text.trim()}` });
  }
  return blocks;
}

export async function extractSchedule(input: IngestInput, client?: Anthropic): Promise<IngestResult> {
  if (!input.text?.trim() && !input.attachments?.length) {
    throw new IngestError('Nothing to read. Paste the schedule, or attach the PDF or photo.');
  }
  const anthropic = client ?? new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

  const messages: Anthropic.MessageParam[] = [{ role: 'user', content: buildFirstMessage(input) }];
  const days: DatedScheduleDay[] = [];
  const rejected: { input: unknown; issues: string[] }[] = [];
  let message = '';
  let attempts = 0;

  while (attempts < MAX_ATTEMPTS) {
    attempts += 1;
    const response = await anthropic.messages.create({
      model: INGEST_MODEL,
      max_tokens: MAX_TOKENS,
      thinking: { type: 'adaptive' },
      system: SYSTEM_PROMPT,
      tools: [EMIT_SCHEDULE_TOOL],
      // A copy: `messages` grows below, and a request should carry the history as it
      // stood when it was sent.
      messages: [...messages],
    });

    const prose = response.content
      .filter((block): block is Anthropic.TextBlock => block.type === 'text')
      .map((block) => block.text.trim())
      .filter(Boolean)
      .join('\n\n');
    if (prose) message = prose;

    const calls = response.content.filter(
      (block): block is Anthropic.ToolUseBlock => block.type === 'tool_use' && block.name === EMIT_SCHEDULE_TOOL.name,
    );
    if (!calls.length) break;

    const results: Anthropic.ToolResultBlockParam[] = [];
    let anyInvalid = false;

    for (const call of calls) {
      const raw = call.input as Record<string, unknown>;
      const { date, ...day } = raw;
      const parsed = datedScheduleDaySchema.safeParse({ date, day });
      if (parsed.success) {
        // A later call for the same date replaces the earlier one.
        const existing = days.findIndex((d) => d.date === parsed.data.date);
        const entry = { date: parsed.data.date, day: parsed.data.day } as DatedScheduleDay;
        if (existing >= 0) days[existing] = entry;
        else days.push(entry);
        results.push({ type: 'tool_result', tool_use_id: call.id, content: `Accepted ${parsed.data.date}.` });
      } else {
        anyInvalid = true;
        const issues = issueLines(parsed.error);
        rejected.push({ input: raw, issues });
        results.push({
          type: 'tool_result',
          tool_use_id: call.id,
          is_error: true,
          content: `Rejected. Fix these and call emit_schedule again for this day:\n${issues.join('\n')}`,
        });
      }
    }

    messages.push({ role: 'assistant', content: response.content });
    messages.push({ role: 'user', content: results });
    if (!anyInvalid) break;
  }

  // A day that was rejected and then accepted on a retry is not a failure.
  const accepted = new Set(days.map((d) => d.date));
  const stillRejected = rejected.filter((entry) => {
    const date = (entry.input as { date?: unknown }).date;
    return typeof date !== 'string' || !accepted.has(date);
  });

  days.sort((a, b) => a.date.localeCompare(b.date));
  return { days, message, rejected: stillRejected, attempts };
}
