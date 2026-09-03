/**
 * The retry loop for HQ-656, with a stubbed model - offline, same as extract.test.ts.
 * What's being proven: invalid output goes back to the model with the reason attached
 * and is never returned as if it were an accepted class.
 */
import { describe, expect, it, vi } from 'vitest';
import type Anthropic from '@anthropic-ai/sdk';
import { IngestError } from './extract';
import { extractStudentClasses } from './extractStudentClasses';

function toolUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_student_classes', input };
}

function detailsUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_student_details', input };
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

  it('is null when the model never calls emit_student_details', async () => {
    const { client } = stubClient([{ content: [toolUse('a', GOOD)] }]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.details).toBeNull();
  });

  it('captures lunch, grade, and advisory from a details call alongside classes in the same turn', async () => {
    const { client, create } = stubClient([
      {
        content: [
          toolUse('a', GOOD),
          detailsUse('b', { lunch: '2nd Lunch', grade: '10', advisory: 'Rm 204' }),
        ],
      },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(create).toHaveBeenCalledTimes(1);
    expect(result.classes).toHaveLength(1);
    expect(result.details).toEqual({ lunch: '2nd Lunch', grade: '10', advisory: 'Rm 204' });
  });

  it('accepts a details call with only some fields set', async () => {
    const { client } = stubClient([{ content: [detailsUse('a', { grade: '9' })] }]);
    const result = await extractStudentClasses(PHOTO, client);
    expect(result.details).toEqual({ grade: '9' });
  });

  it('rejects an invalid details call, retries, and accepts the correction without leaving a dangling tool_use', async () => {
    const { client, create } = stubClient([
      { content: [detailsUse('a', { lunch: '3rd Lunch' })] },
      { content: [detailsUse('b', { lunch: '2nd Lunch' })] },
    ]);
    const result = await extractStudentClasses(PHOTO, client);

    expect(create).toHaveBeenCalledTimes(2);
    expect(result.details).toEqual({ lunch: '2nd Lunch' });
    expect(result.rejected).toEqual([]);

    const followUp = create.mock.calls[1][0] as Anthropic.MessageCreateParamsNonStreaming;
    const toolResults = followUp.messages.at(-1)!.content as { tool_use_id?: string; is_error?: boolean }[];
    // The first turn's tool_use must have a matching tool_result, or the real API rejects
    // the whole request - this is what would catch a dropped result for the second tool.
    expect(toolResults).toHaveLength(1);
    expect(toolResults[0].is_error).toBe(true);
  });
});
