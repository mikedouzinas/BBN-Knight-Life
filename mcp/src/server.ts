/**
 * The Knight Life MCP server.
 *
 * Four tools. Three of them read. One of them writes, and it refuses to write unless the
 * caller passes `confirm: true`, which the tool description tells the model it may only do
 * after a person has said yes in their own words.
 *
 * That gate is a guardrail, not a proof. An agent that decides to pass `confirm: true` on
 * its own will succeed, exactly as an admin who clicks publish without reading will
 * succeed. What the split buys is that publishing can never be a side effect of asking a
 * question: reading a schedule email and writing to 582 phones are two different calls,
 * and the second one has to be chosen.
 *
 * The real containment is underneath, and it is not in this file. Every call carries an
 * admin's Firebase token, the server re-validates every schedule from scratch, and
 * Firestore rules refuse a write from anyone not in `admins`. This process is a
 * convenience on top of that, never a way around it.
 */
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { KnightLifeClient, KnightLifeError } from './client.js';
import { ProposalStore } from './proposals.js';
import { formatDay, formatProposal, type ProposedDay, type ProposedRange } from './format.js';

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

const attachmentSchema = z.object({
  mediaType: z.enum(['application/pdf', 'image/png', 'image/jpeg', 'image/gif', 'image/webp']),
  data: z.string().min(1).describe('The file, base64 encoded, with no data: prefix.'),
  filename: z.string().max(200).optional(),
});

function text(body: string) {
  return { content: [{ type: 'text' as const, text: body }] };
}

function failure(body: string) {
  return { content: [{ type: 'text' as const, text: body }], isError: true };
}

function describe(error: unknown): string {
  if (error instanceof KnightLifeError) return error.message;
  return error instanceof Error ? error.message : String(error);
}

export function createServer(client: KnightLifeClient, proposals = new ProposalStore()): McpServer {
  const server = new McpServer({ name: 'knight-life', version: '1.0.0' });

  server.registerTool(
    'whoami',
    {
      title: 'Check the Knight Life connection',
      description:
        'Confirm this server can reach Knight Life and report which admin account it acts as. ' +
        'Run this first when anything is not working.',
      inputSchema: {},
    },
    async () => {
      try {
        const identity = await client.whoami();
        return text(
          `Connected to Knight Life as ${identity.email}${identity.name ? ` (${identity.name})` : ''}.\n` +
            'Anything published through this server is recorded under that address.',
        );
      } catch (error) {
        return failure(describe(error));
      }
    },
  );

  server.registerTool(
    'read_schedule',
    {
      title: 'Read a published day',
      description:
        'What Knight Life currently shows students for one date. Read-only. Use it before ' +
        'proposing a change, so you can say what is being replaced.',
      inputSchema: {
        date: z.string().regex(ISO_DATE, 'date must be YYYY-MM-DD').describe('The date to read, YYYY-MM-DD.'),
      },
    },
    async ({ date }) => {
      try {
        const result = await client.readDay(date);
        if (!result.published) {
          return text(
            `${result.day == null ? date : date}: nothing special is published, so students see the ` +
              'regular weekly schedule for that weekday.',
          );
        }
        return text(formatDay(result as unknown as ProposedDay));
      } catch (error) {
        return failure(describe(error));
      }
    },
  );

  server.registerTool(
    'propose_schedule',
    {
      title: 'Read a source and propose schedule changes',
      description:
        'Turn a schedule announcement into proposed days. Accepts pasted text, a PDF, or a photo, ' +
        'and handles a source covering several dates at once (a message naming three snow days ' +
        'produces three days in one proposal).\n\n' +
        'A stretch of days with no school comes back as ONE break rather than a pile of days, so ' +
        '"winter break, back January 4th" is a single entry covering the whole span.\n\n' +
        'This NEVER publishes. It returns a readable plan and a proposal id. Show the plan to the ' +
        'person, get their answer, then call publish_schedule.',
      inputSchema: {
        text: z.string().max(80_000).optional().describe('The announcement, pasted as text.'),
        attachments: z.array(attachmentSchema).max(4).optional().describe('A PDF or photo of the schedule.'),
        hintDate: z
          .string()
          .regex(ISO_DATE)
          .optional()
          .describe('The date this is about, when the source does not say plainly. YYYY-MM-DD.'),
        notes: z.string().max(2000).optional().describe('Anything the source leaves out.'),
      },
    },
    async ({ text: sourceText, attachments, hintDate, notes }) => {
      if (!sourceText?.trim() && !attachments?.length) {
        return failure('Give me the announcement: paste the text, or attach the PDF or photo.');
      }
      try {
        const result = await client.ingest({ text: sourceText, attachments, hintDate, notes });
        const ranges = (result.ranges ?? []) as ProposedRange[];
        if (!result.days.length && !ranges.length) {
          return failure(
            `Nothing publishable came out of that source.${result.message ? ` ${result.message}` : ''}` +
              (result.rejected?.length ? `\nSkipped: ${result.rejected.join('; ')}` : ''),
          );
        }
        const proposal = proposals.create(result.days as ProposedDay[], ranges);
        const extra = [
          result.message ? `\nNote: ${result.message}` : '',
          result.rejected?.length ? `\nSkipped: ${result.rejected.join('; ')}` : '',
        ].join('');
        return text(formatProposal(proposal.id, proposal.days, proposal.ranges) + extra);
      } catch (error) {
        return failure(describe(error));
      }
    },
  );

  server.registerTool(
    'publish_schedule',
    {
      title: 'Publish a proposal to every student',
      description:
        'Write a proposal to Knight Life. This is visible to every student at BB&N as soon as it ' +
        'lands, so it is the one call here that changes what other people see.\n\n' +
        'Only set confirm to true after the person has looked at the proposed days and said yes. ' +
        'Their yes is the point of this tool; do not supply it on their behalf, and do not infer ' +
        'it from an earlier instruction to "go ahead and fix the schedule". If you have not shown ' +
        'them the days, call propose_schedule and show them.',
      inputSchema: {
        proposal_id: z.string().describe('The id from propose_schedule.'),
        confirm: z
          .boolean()
          .describe('Must be true. Set it only after a person has approved the days you showed them.'),
        dates: z
          .array(z.string().regex(ISO_DATE))
          .optional()
          .describe(
            'Publish only these from the proposal. A day is named by its date; a break is named by ' +
            'the date it STARTS. Omit to publish everything in the proposal.',
          ),
      },
    },
    async ({ proposal_id, confirm, dates }) => {
      if (!confirm) {
        return failure(
          'Nothing was published. publish_schedule needs confirm: true, and that means a person ' +
            'has seen the days and approved them. Show them the proposal first.',
        );
      }

      const proposal = proposals.get(proposal_id);
      if (!proposal) {
        return failure(
          `No proposal ${proposal_id}. Proposals live for an hour and are cleared when this server ` +
            'restarts. Run propose_schedule again.',
        );
      }

      // `dates` selects days by date and breaks by their start date, so an admin approving
      // "just the winter one" names the day it begins, which is what they see on the card.
      const chosenDays = dates?.length ? proposal.days.filter((d) => dates.includes(d.date)) : proposal.days;
      const chosenRanges = dates?.length
        ? proposal.ranges.filter((r) => dates.includes(r.startDate))
        : proposal.ranges;

      if (!chosenDays.length && !chosenRanges.length) {
        const covers = [
          ...proposal.ranges.map((r) => `${r.startDate} (break)`),
          ...proposal.days.map((d) => d.date),
        ];
        return failure(
          `Proposal ${proposal_id} has nothing matching ${dates?.join(', ')}. It covers: ${covers.join(', ')}`,
        );
      }

      // Publish one day at a time and report honestly. A partial failure is a real state:
      // saying "published" when the third of three days failed would be the worst outcome
      // here, because the person would stop looking.
      const done: string[] = [];
      const failed: string[] = [];

      // Breaks first. A span is what decides whether the days inside it are school days at
      // all, so if only one of the two kinds lands, the break is the more useful one to have.
      for (const range of chosenRanges) {
        try {
          const result = await client.publishRange(range);
          done.push(
            `${range.startDate} to ${range.endDate} (${range.reason}) -> schedules/break.${result.published.breakKey}`,
          );
        } catch (error) {
          failed.push(`${range.startDate} to ${range.endDate}: ${describe(error)}`);
        }
      }

      for (const day of chosenDays) {
        try {
          const result = await client.publish(day.date, day.day);
          done.push(`${day.display ?? day.date} -> ${result.published.legacyId}`);
        } catch (error) {
          failed.push(`${day.display ?? day.date}: ${describe(error)}`);
        }
      }

      const chosen = [...chosenRanges, ...chosenDays];

      if (!failed.length) proposals.take(proposal_id);

      const lines = [
        failed.length ? `Published ${done.length} of ${chosen.length} days.` : `Published ${done.length} day(s). Students see this now.`,
        ...done.map((d) => `  ok   ${d}`),
        ...failed.map((f) => `  FAIL ${f}`),
      ];
      if (failed.length) {
        lines.push('', `Proposal ${proposal_id} is still open so the failed days can be retried.`);
      }
      const body = lines.join('\n');
      return failed.length ? failure(body) : text(body);
    },
  );

  return server;
}
