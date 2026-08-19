# Knight Life MCP server

Publish BB&N schedule changes by describing them to an AI agent, instead of filling in a form.

You say *"there's no school Thursday and Friday, snow"*, or you forward the email BB&N sent.
The agent reads it, shows you the days it plans to publish, and waits. Nothing reaches a
student's phone until you say yes.

## What it can do

| Tool | What it does |
| --- | --- |
| `whoami` | Confirms the connection and names the admin account it acts as. |
| `read_schedule` | Shows what students currently see for a date. Read-only. |
| `propose_schedule` | Reads text, a PDF, or a photo and returns proposed days. **Never publishes.** |
| `publish_schedule` | Writes a proposal to every student. Refuses unless `confirm` is true. |

One source can cover several dates. A message naming three snow days produces one proposal
with three days, and publishing it publishes all three.

A vacation comes back as **one break**, not a pile of days. *"Winter break begins after
classes Friday the 18th, classes resume Monday the 4th"* becomes a single span, and the
proposal spells out the last day off and the day classes resume, because reading the resume
date as the end date takes an extra day of school off the calendar for everybody.

## Setting it up

You need to already be a Knight Life admin. If you are not, an existing admin adds you by
creating a document at `admins/<your-email>` in Firestore, and this will not work until they do.

**1. Get your token.** Sign in at [mikeveson.com/knight-life/admin](https://mikeveson.com/knight-life/admin),
open **Link an AI agent** at the bottom of the page, and copy the token.

Treat it like a password. It signs in as you, it publishes under your name, and it stops
working the moment you are removed from `admins`.

**2. Build the server.**

```bash
git clone https://github.com/mikedouzinas/BBN-Knight-Life.git
cd BBN-Knight-Life/mcp
npm install
npm run build
```

**3. Point your client at it.** For Claude Desktop, edit
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "knight-life": {
      "command": "node",
      "args": ["/absolute/path/to/BBN-Knight-Life/mcp/dist/index.js"],
      "env": {
        "KNIGHT_LIFE_REFRESH_TOKEN": "the token you copied"
      }
    }
  }
}
```

For Claude Code, from any directory:

```bash
claude mcp add knight-life \
  --env KNIGHT_LIFE_REFRESH_TOKEN=the-token-you-copied \
  -- node /absolute/path/to/BBN-Knight-Life/mcp/dist/index.js
```

Restart the client, then ask it to run `whoami`. It should answer with your school email.

## Using it

Talk normally.

> There's no school tomorrow, snow day.

> Here's the email from the office about Thursday's assembly schedule. *(paste it)*

> What's the schedule for September 15th?

For a photo or PDF, tell your agent the file path and let it attach the file.

The agent will show you the days before publishing. **Read the times.** That confirmation is
the only thing standing between a typo and 582 students showing up an hour early, and it only
works if somebody actually looks.

## Configuration

| Variable | Required | Default |
| --- | --- | --- |
| `KNIGHT_LIFE_REFRESH_TOKEN` | yes | none |
| `KNIGHT_LIFE_URL` | no | `https://mikeveson.com/knight-life` |
| `KNIGHT_LIFE_WEB_API_KEY` | no | the `bbn-daily` public web key |

Set `KNIGHT_LIFE_URL` to `http://localhost:3000/knight-life` to point at a local `npm run dev`.
The app carries a `/knight-life` base path in development too, so the two addresses have the
same shape and a URL that works locally works deployed.

## How the safety actually works

Worth being precise about, because "it asks first" is not by itself a security property.

**The confirm flag is a guardrail, not a proof.** An agent that decides to pass `confirm: true`
without asking you will succeed, in the same way that an admin who clicks publish without
reading will succeed. What splitting propose from publish buys is that publishing can never
happen *as a side effect* of asking a question. Reading an email and writing to 582 phones are
two different calls, and something has to choose the second one.

**The real containment is underneath, and it is not in this server.**

- Every call carries your Firebase token. The server verifies it and checks the `admins`
  collection, exactly as it does for the browser. This server invents no new way in.
- The API re-validates every schedule from scratch. A malformed day is rejected at the
  boundary, not trusted because an agent produced it.
- Firestore rules refuse a schedule write from anyone not in `admins`, so a leaked token from
  a non-admin account can do nothing at all.
- Removing someone from `admins` revokes their agent at the same instant it revokes their
  browser, because it is one check in one place.

**Proposals live in memory only.** They expire after an hour, they are cleared when the server
restarts, and publishing consumes the proposal so the same plan cannot be published twice.

## Development

```bash
npm test        # 9 tests, all about not publishing without a person
npm run build
```

The tests drive the server over a real in-memory MCP transport and assert on writes rather
than on wording, so rephrasing a refusal message cannot make them pass vacuously. Each safety
test carries a note recording what was broken to make it fail, and what it printed.
