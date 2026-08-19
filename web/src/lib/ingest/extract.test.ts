/**
 * The retry loop, with a stubbed model. Offline: `npm test` never calls the API.
 *
 * What is being proven is the contract from the design doc: invalid output goes back to
 * the model with the reason attached and is never returned as if it were a schedule.
 */
import { describe, expect, it, vi } from 'vitest';
import type Anthropic from '@anthropic-ai/sdk';
import { IngestError, extractSchedule } from './extract';

function toolUse(id: string, input: unknown) {
  return { type: 'tool_use' as const, id, name: 'emit_schedule', input };
}

function stubClient(responses: { content: unknown[] }[]) {
  const create = vi.fn();
  for (const response of responses) create.mockResolvedValueOnce(response);
  create.mockResolvedValue({ content: [] });
  return { client: { messages: { create } } as unknown as Anthropic, create };
}

const GOOD = {
  date: '2025-10-16',
  type: 'blocks',
  blocks: [{ type: 'block', block: 'b', name: 'B', startTime: '8:15 am', endTime: '9:00 am' }],
};

const BAD = { ...GOOD, blocks: [{ type: 'block', block: 'b', name: 'B', startTime: '08:15', endTime: '09:00' }] };

describe('extractSchedule', () => {
  it('returns a day the schema accepted', async () => {
    const { client, create } = stubClient([{ content: [toolUse('a', GOOD)] }]);
    const result = await extractSchedule({ text: 'anything' }, client);
    expect(result.days).toHaveLength(1);
    expect(result.days[0].date).toBe('2025-10-16');
    expect(create).toHaveBeenCalledTimes(1);
  });

  it('hands the validation error back to the model and accepts the corrected day', async () => {
    const { client, create } = stubClient([
      { content: [toolUse('a', BAD)] },
      { content: [toolUse('b', GOOD)] },
    ]);
    const result = await extractSchedule({ text: 'anything' }, client);

    expect(create).toHaveBeenCalledTimes(2);
    expect(result.days).toHaveLength(1);
    expect(result.rejected).toEqual([]);

    // The second call carries the rejection, marked as an error, with the reason in it.
    const followUp = create.mock.calls[1][0] as Anthropic.MessageCreateParamsNonStreaming;
    const toolResults = followUp.messages.at(-1)!.content as { is_error?: boolean; content?: string }[];
    expect(toolResults[0].is_error).toBe(true);
    expect(toolResults[0].content).toMatch(/12-hour time/);
  });

  it('gives up after three attempts and reports the failure rather than a schedule', async () => {
    const { client, create } = stubClient([
      { content: [toolUse('a', BAD)] },
      { content: [toolUse('b', BAD)] },
      { content: [toolUse('c', BAD)] },
    ]);
    const result = await extractSchedule({ text: 'anything' }, client);

    expect(create).toHaveBeenCalledTimes(3);
    expect(result.days).toEqual([]);
    expect(result.rejected).toHaveLength(3);
    expect(result.rejected[0].issues.join()).toMatch(/startTime/);
  });

  it('keeps the good days from a batch where one day was bad', async () => {
    const other = { ...GOOD, date: '2025-10-17' };
    const { client } = stubClient([
      { content: [toolUse('a', GOOD), toolUse('b', { ...BAD, date: '2025-10-17' })] },
      { content: [toolUse('c', other)] },
    ]);
    const result = await extractSchedule({ text: 'anything' }, client);
    expect(result.days.map((d) => d.date)).toEqual(['2025-10-16', '2025-10-17']);
    expect(result.rejected).toEqual([]);
  });

  it('passes through what the model said when it called nothing', async () => {
    const { client } = stubClient([{ content: [{ type: 'text', text: 'I cannot read the date on this page.' }] }]);
    const result = await extractSchedule({ text: 'anything' }, client);
    expect(result.days).toEqual([]);
    expect(result.message).toMatch(/cannot read the date/);
  });

  it('refuses an empty request before spending a token', async () => {
    const { client, create } = stubClient([]);
    await expect(extractSchedule({}, client)).rejects.toBeInstanceOf(IngestError);
    expect(create).not.toHaveBeenCalled();
  });

  it('refuses a file type the API cannot read', async () => {
    const { client } = stubClient([]);
    await expect(
      extractSchedule({ attachments: [{ mediaType: 'application/msword', data: 'abc' }] }, client),
    ).rejects.toBeInstanceOf(IngestError);
  });
});
