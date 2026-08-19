/**
 * These tests exist for one reason: publish_schedule must not write without a person.
 *
 * They drive the server over a real in-memory MCP transport rather than reaching into its
 * internals, so what is exercised is the call an agent actually makes.
 *
 * FALSIFICATION: see the note above each safety test. Each was broken on purpose and the
 * failure output recorded, because a test that has never failed is a claim, not a check.
 */
import { describe, expect, it } from 'vitest';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import { createServer } from './server.js';
import { ProposalStore } from './proposals.js';
import type { KnightLifeClient } from './client.js';

interface PublishedCall {
  date: string;
  day: unknown;
}

function fakeClient(overrides: Record<string, unknown> = {}) {
  const published: PublishedCall[] = [];
  const client = {
    published,
    whoami: async () => ({ email: 'admin@bbns.org', name: 'Test Admin' }),
    readDay: async (date: string) => ({ date, display: date, day: null, published: false }),
    ingest: async () => ({
      days: [
        { date: '2026-09-15', display: 'Tuesday, September 15, 2026', day: { type: 'noschool', reason: 'Snow day' } },
        { date: '2026-09-16', display: 'Wednesday, September 16, 2026', day: { type: 'noschool', reason: 'Snow day' } },
      ],
    }),
    publish: async (date: string, day: unknown) => {
      published.push({ date, day });
      return {
        published: { date, canonicalKey: date, legacyId: `legacy ${date}`, updatedBy: 'admin@bbns.org', updatedAt: 'now' },
      };
    },
    ...overrides,
  };
  return client as unknown as KnightLifeClient & { published: PublishedCall[] };
}

type Call = (name: string, args: Record<string, unknown>) => Promise<{ text: string; isError: boolean }>;

async function connect(client: KnightLifeClient): Promise<Call> {
  const server = createServer(client, new ProposalStore());
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const mcp = new Client({ name: 'test', version: '1.0.0' });
  await Promise.all([server.connect(serverTransport), mcp.connect(clientTransport)]);

  return async (name, args) => {
    const result = await mcp.callTool({ name, arguments: args });
    const content = (result.content ?? []) as { type: string; text?: string }[];
    return { text: content.map((c) => c.text ?? '').join('\n'), isError: result.isError === true };
  };
}

async function propose(call: Call): Promise<string> {
  const result = await call('propose_schedule', { text: 'no school sept 15 and 16, snow' });
  const id = /Proposal (\S+)/.exec(result.text)?.[1];
  expect(id, `propose_schedule should return a proposal id, got: ${result.text}`).toBeTruthy();
  return id as string;
}

describe('the confirm gate', () => {
  /**
   * FALSIFIED 2026-08-19: changed the guard to `if (!confirm && false)`. This failed with
   *   AssertionError: expected [ { date: '2026-09-15', … } ] to deeply equal []
   * The assertion is on the fake client's recorded writes, not on the wording of the
   * refusal, so rewording the message cannot make it pass vacuously.
   */
  it('writes nothing when confirm is false', async () => {
    const client = fakeClient();
    const call = await connect(client);
    const id = await propose(call);

    const result = await call('publish_schedule', { proposal_id: id, confirm: false });

    expect(client.published).toEqual([]);
    expect(result.isError).toBe(true);
  });

  it('publishes every day in the proposal once confirmed', async () => {
    const client = fakeClient();
    const call = await connect(client);
    const id = await propose(call);

    const result = await call('publish_schedule', { proposal_id: id, confirm: true });

    expect(client.published.map((c) => c.date)).toEqual(['2026-09-15', '2026-09-16']);
    expect(result.isError).toBe(false);
  });

  it('publishes only the dates asked for', async () => {
    const client = fakeClient();
    const call = await connect(client);
    const id = await propose(call);

    await call('publish_schedule', { proposal_id: id, confirm: true, dates: ['2026-09-16'] });

    expect(client.published.map((c) => c.date)).toEqual(['2026-09-16']);
  });

  it('cannot publish the same proposal twice', async () => {
    const client = fakeClient();
    const call = await connect(client);
    const id = await propose(call);

    await call('publish_schedule', { proposal_id: id, confirm: true });
    const second = await call('publish_schedule', { proposal_id: id, confirm: true });

    expect(client.published.length).toBe(2);
    expect(second.isError).toBe(true);
  });

  /**
   * FALSIFIED 2026-08-19, on the second attempt, and the first attempt is the useful part.
   * Removing ONLY the unknown-id guard did not fail this test: the empty-selection guard
   * below it caught the same case, so the behaviour stayed correct through a different
   * path. Removing BOTH failed with
   *   AssertionError: expected false to be true // Object.is equality
   * on `result.isError`. So this test pins the behaviour (an unknown id never publishes)
   * rather than one branch, which is what it should do, and the note says so rather than
   * claiming a falsification that never happened.
   */
  it('rejects an unknown proposal id rather than inventing a day', async () => {
    const client = fakeClient();
    const call = await connect(client);

    const result = await call('publish_schedule', { proposal_id: 'p999', confirm: true });

    expect(client.published).toEqual([]);
    expect(result.isError).toBe(true);
  });
});

describe('propose_schedule', () => {
  it('never writes, even for a source covering several days', async () => {
    const client = fakeClient();
    const call = await connect(client);
    const result = await call('propose_schedule', { text: 'no school sept 15 and 16, snow' });

    expect(client.published).toEqual([]);
    expect(result.text).toContain('NOTHING IS PUBLISHED YET');
    expect(result.text).toContain('Tuesday, September 15, 2026');
    expect(result.text).toContain('Wednesday, September 16, 2026');
  });

  it('asks for a source rather than calling the API with nothing', async () => {
    const client = fakeClient();
    const call = await connect(client);
    const result = await call('propose_schedule', {});
    expect(result.isError).toBe(true);
  });
});

describe('reporting', () => {
  /**
   * FALSIFIED 2026-08-19: made the summary always read "Published N day(s)". This failed
   * with `expected '…' to contain 'Published 1 of 2 days'`, which is the exact case where
   * a false success is most costly: the person stops checking.
   */
  it('reports a partial failure instead of claiming success', async () => {
    let calls = 0;
    const client = fakeClient({
      publish: async (date: string) => {
        calls += 1;
        if (calls === 2) throw new Error('Firestore said no');
        return { published: { date, canonicalKey: date, legacyId: 'x', updatedBy: 'a@b.org', updatedAt: 'now' } };
      },
    });
    const call = await connect(client);
    const id = await propose(call);

    const result = await call('publish_schedule', { proposal_id: id, confirm: true });

    expect(result.isError).toBe(true);
    expect(result.text).toContain('Published 1 of 2 days');
    expect(result.text).toContain('Firestore said no');
  });

  it('whoami names the account writes are recorded under', async () => {
    const call = await connect(fakeClient());
    const result = await call('whoami', {});
    expect(result.text).toContain('admin@bbns.org');
  });
});
