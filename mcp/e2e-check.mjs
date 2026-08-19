/**
 * End-to-end check: a real MCP client, the real built server, the real HTTP API, and real
 * Firestore. The unit tests use a fake client, so they prove the confirm gate and prove
 * nothing about whether a refresh token actually authenticates. This proves the chain.
 *
 * READ-ONLY BY CONSTRUCTION. It calls whoami, read_schedule, and propose_schedule, and the
 * only publish it makes is one with `confirm: false`, which must be refused. Do not add a
 * confirmed publish here: this file writes to production.
 *
 *   npm run build
 *   KNIGHT_LIFE_REFRESH_TOKEN=... KNIGHT_LIFE_URL=http://localhost:3000/knight-life \
 *     node e2e-check.mjs
 *
 * Get the token from "Link an AI agent" on the admin page.
 */
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
const refreshToken = (process.env.KNIGHT_LIFE_REFRESH_TOKEN ?? '').trim();
if (!refreshToken) {
  console.error('Set KNIGHT_LIFE_REFRESH_TOKEN. Get one from "Link an AI agent" on the admin page.');
  process.exit(1);
}
const baseUrl = process.env.KNIGHT_LIFE_URL ?? 'http://localhost:3000/knight-life';

const transport = new StdioClientTransport({
  command: 'node',
  args: [new URL('./dist/index.js', import.meta.url).pathname],
  env: {
    ...process.env,
    KNIGHT_LIFE_REFRESH_TOKEN: refreshToken,
    KNIGHT_LIFE_URL: baseUrl,
  },
  stderr: 'pipe',
});

const client = new Client({ name: 'e2e', version: '1.0.0' });
await client.connect(transport);

const tools = await client.listTools();
console.log('=== tools the server advertises ===');
for (const t of tools.tools) console.log('  ' + t.name.padEnd(18) + (t.title ?? ''));

async function call(name, args) {
  const r = await client.callTool({ name, arguments: args });
  const text = (r.content ?? []).map((c) => c.text ?? '').join('\n');
  return { text, isError: r.isError === true };
}

console.log('\n=== whoami (real token -> real requireAdmin -> real admins collection) ===');
console.log((await call('whoami', {})).text);

console.log('\n=== read_schedule 2026-09-08 (first day of school) ===');
console.log((await call('read_schedule', { date: '2026-09-08' })).text);

console.log('\n=== read_schedule 2026-09-21 (Yom Kippur, published today) ===');
console.log((await call('read_schedule', { date: '2026-09-21' })).text);

console.log('\n=== propose_schedule: three snow days in one voice-note-style message ===');
const proposal = await call('propose_schedule', {
  text: "hey so there's gonna be a snow day on December 3rd, December 4th, and also December 5th 2026. no school any of those days, snow.",
});
console.log(proposal.text);

console.log('\n=== publish WITHOUT confirm (must refuse) ===');
const id = /Proposal (\S+)/.exec(proposal.text)?.[1];
const refused = await call('publish_schedule', { proposal_id: id, confirm: false });
console.log('isError:', refused.isError);
console.log(refused.text);

await client.close();
if (!refused.isError) {
  console.error('\nFAIL: publish_schedule accepted confirm:false. That is the whole safety model.');
  process.exit(1);
}
console.log('\n=== done. Nothing was published. ===');
