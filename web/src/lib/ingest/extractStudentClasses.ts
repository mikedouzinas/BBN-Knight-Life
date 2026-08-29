/**
 * Source in, validated classes out. Same shape as extract.ts's loop - invalid output is
 * fed back to the model as a tool error and retried, valid output never writes anywhere
 * on its own - pointed at a different output: one student's seven blocks instead of a
 * day of bell times.
 */
import 'server-only';
import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';
import type { IngestAttachment } from './extract';
import { IMAGE_TYPES, IngestError, attachmentBlock } from './extract';
import { EMIT_STUDENT_CLASSES_TOOL, STUDENT_CLASSES_SYSTEM_PROMPT } from './studentClassesTool';

export const STUDENT_INGEST_MODEL = 'claude-opus-5';
const MAX_ATTEMPTS = 3;
const MAX_TOKENS = 4000;

export const studentClassSchema = z.object({
  block: z.enum(['a', 'b', 'c', 'd', 'e', 'f', 'g']),
  subject: z.string().min(1).max(120),
  teacher: z.string().max(120).optional(),
  room: z.string().max(60).optional(),
});

export type StudentClass = z.infer<typeof studentClassSchema>;

export interface ExtractStudentClassesInput {
  attachments: IngestAttachment[];
  notes?: string;
}

export interface ExtractStudentClassesResult {
  classes: StudentClass[];
  message: string;
  rejected: { input: unknown; issues: string[] }[];
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
    text: input.notes ? `Read this student's schedule.\n\nStudent's notes: ${input.notes}` : "Read this student's schedule.",
  });

  const messages: Anthropic.MessageParam[] = [{ role: 'user', content: firstBlocks }];
  const classes: StudentClass[] = [];
  const rejected: { input: unknown; issues: string[] }[] = [];
  let message = '';
  let attempts = 0;

  while (attempts < MAX_ATTEMPTS) {
    attempts += 1;
    const response = await anthropic.messages.create({
      model: STUDENT_INGEST_MODEL,
      max_tokens: MAX_TOKENS,
      thinking: { type: 'adaptive' },
      system: STUDENT_CLASSES_SYSTEM_PROMPT,
      tools: [EMIT_STUDENT_CLASSES_TOOL],
      messages: [...messages],
    });

    const prose = response.content
      .filter((block): block is Anthropic.TextBlock => block.type === 'text')
      .map((block) => block.text.trim())
      .filter(Boolean)
      .join('\n\n');
    if (prose) message = prose;

    const calls = response.content.filter(
      (block): block is Anthropic.ToolUseBlock => block.type === 'tool_use' && block.name === EMIT_STUDENT_CLASSES_TOOL.name,
    );
    if (!calls.length) break;

    const results: Anthropic.ToolResultBlockParam[] = [];
    let anyInvalid = false;

    for (const call of calls) {
      const raw = call.input as Record<string, unknown>;
      const parsed = studentClassSchema.safeParse(raw);
      if (parsed.success) {
        // A later call for the same block replaces the earlier one - the model correcting
        // itself mid-conversation, not a second class in one block.
        const existing = classes.findIndex((c) => c.block === parsed.data.block);
        if (existing >= 0) classes[existing] = parsed.data;
        else classes.push(parsed.data);
        results.push({ type: 'tool_result', tool_use_id: call.id, content: `Accepted block ${parsed.data.block}.` });
      } else {
        anyInvalid = true;
        const issues = issueLines(parsed.error);
        rejected.push({ input: raw, issues });
        results.push({
          type: 'tool_result',
          tool_use_id: call.id,
          is_error: true,
          content: `Rejected. Fix these and call emit_student_classes again for this block:\n${issues.join('\n')}`,
        });
      }
    }

    messages.push({ role: 'assistant', content: response.content });
    messages.push({ role: 'user', content: results });
    if (!anyInvalid) break;
  }

  const accepted = new Set(classes.map((c) => c.block));
  const stillRejected = rejected.filter((entry) => {
    const block = (entry.input as { block?: unknown }).block;
    return typeof block !== 'string' || !accepted.has(block as StudentClass['block']);
  });

  classes.sort((a, b) => a.block.localeCompare(b.block));
  return { classes, message, rejected: stillRejected, attempts };
}
