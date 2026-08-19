# Publishing a schedule

Everything about getting a schedule change onto students' phones: the web tool, the AI agent
setup, and what to do when it goes wrong.

## The short version

Go to **[mikeveson.com/knight-life/admin](https://mikeveson.com/knight-life/admin)**, sign in
with your school Google account, paste the email BB&N sent, check what it shows you, publish.

## Who can publish

Anyone with a document in the `admins` collection in Firestore, keyed by their lowercase email.
Nothing else. There is no list of addresses in the code and no separate password.

**To add a maintainer:** open the
[Firestore console](https://console.firebase.google.com/u/0/project/bbn-daily/firestore),
go to `admins`, and create a document whose ID is their lowercase school email. The document
can be empty; only its existence matters. They can publish immediately, in the browser and
through an agent, with no deploy.

**To remove one:** delete that document. It takes effect on their next request, everywhere.

This is deliberately the easiest thing in the project to do. Handing this app to the next
student is the step most likely to fail, and it should never require a developer.

## Publishing in the browser

1. Sign in.
2. Give it the source: paste the text, or upload the PDF or photo. Anything works, including a
   forwarded email with the schedule buried in it.
3. It shows you each day it read, drawn to real times against an hour rail, so a bell time in
   the wrong place looks wrong instead of reading fine.
4. Check it against the source. **Read the times.**
5. Publish.

A source covering several dates produces several cards, each published separately.

### What "published" means

Two writes, in one batch, both or neither:

- `schedules/special`, field `2026/9/15` — the canonical store.
- `special-schedules/Tuesday, September 15, 2026` — the legacy per-day document the shipped
  2.4.1 app also reads.

A third document goes to `schedule-publish-log`, recording who published, when, and from what
kind of source. That is the answer to "who changed this?", and it is the reason the log exists
rather than a comment in a spreadsheet.

The app picks up the change the next time a student opens it. **It does not push a
notification** — notifications today are scheduled locally on each device, so a student who
does not open the app is not told. That is [HQ-639](https://mikeveson.com/dev), and it is the
biggest remaining gap in this system.

## Publishing from an AI agent

Same permissions, same validation, same log. You describe the change or forward the email, the
agent shows you what it plans to publish, and you approve it.

Setup and the full safety model: **[mcp/README.md](../mcp/README.md)**.

The short version of the safety model: the agent cannot publish as a side effect of reading
something, and everything it does still runs through your admin account and the Firestore
rules. The confirmation step only protects anyone if you actually read the times.

## Breaks and the school year

Paste the break announcement like anything else. A vacation comes back as **one break**
covering the whole span, not a card per day.

The review card shows the last day off and, spelled out, the day classes resume. Check that
line: reading *"classes resume Monday the 4th"* as the end date takes an extra day of school
off the calendar for the whole school, and it is the only mistake a break really invites.

Breaks live in `schedules/break`, keyed `2026/12/19-2027/1/3`. The 2026-27 calendar is loaded
through June 2027.

The tool refuses a span that overlaps one already published. Two breaks covering the same day
disagree, and the app shows whichever it reads first, so it asks you which you meant instead
of guessing. Republishing the same span is an edit and is allowed.

If you ever edit that document by hand in the console, two rules are load-bearing against the
shipped app, which will never be updated:

- The start must not be after the end. The app builds a Swift `ClosedRange` from the key,
  which **crashes on launch** if they are reversed.
- Every value must be a map with a `reason` string, which the app force-casts.

The tool enforces both, which is the reason to use it rather than the console.

**The school year itself** is `schedules/term`, holding the first and last day of classes. A
weekday outside it is treated as no school, so a gap in the calendar produces silence rather
than a confident wrong schedule. If that document is missing the app behaves as it did
before, which is deliberate: a failed read must never tell the school there is no class
today.

## When something is wrong

**Someone cannot sign in.** They are not in `admins`, or they used a personal Google account
instead of their school one. The error names the address it saw; check it matches the document
ID exactly, lowercase.

**A schedule published but students do not see it.** They have not reopened the app. There is
no push yet (HQ-639).

**The wrong schedule went out.** Publish the correct one for that date. The write replaces the
day rather than appending to it, so there is nothing to clean up. `schedule-publish-log` keeps
both entries, which is the point.

**Everything returns 401.** The deploy is missing its Firebase credentials, or your sign-in
expired. Sign out and back in first; if it persists it is the server.

## Running it locally

```bash
cd web
cp .env.local.example .env.local   # then fill it in
npm install
npm run dev                        # http://localhost:3000/knight-life/admin
```

`.env.local` is gitignored and **this repository is public**. The service account JSON never
goes in the repo, in any branch, private or not.

| Variable | What |
| --- | --- |
| `ANTHROPIC_API_KEY` | Reads the source into a schedule. |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to the service account JSON, for local use. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | The same JSON on one line, for a host with no filesystem. Set one or the other. |
| `NEXT_PUBLIC_FIREBASE_*` | Public client config. Not secrets. |
| `DEMO_ENABLED` | `/demo` sandbox, which never touches Firestore. Off unless exactly `true`. |

## Deploying

The tool is a Next app in `web/`, deployed as its own Vercel project and served under
mikeveson.com by a rewrite, so it shares an address with the rest of the site without sharing
a codebase.

The app sets `basePath: '/knight-life'` in `web/next.config.ts`, so it emits its own asset
URLs already prefixed and local development runs at the same shape as the real address. Do not
remove it: without it the HTML loads through the rewrite and every stylesheet 404s against the
portfolio, which reads as a broken build rather than a routing mistake.

1. New Vercel project, root directory `web/`.
2. Set every variable above. Use `FIREBASE_SERVICE_ACCOUNT_JSON` (Vercel has no filesystem for
   secrets), and leave `DEMO_ENABLED` unset.
3. In the portfolio repo's `next.config.ts`, rewrite `/knight-life/:path*` to the Vercel
   deployment.
4. Add `mikeveson.com` to Firebase Auth → Settings → **Authorized domains**, or Google sign-in
   fails on the real address while working fine on localhost.

## Consoles

- [Firebase](https://console.firebase.google.com/u/0/project/bbn-daily/overview) — Firestore, Auth, rules
- [App Store Connect](https://appstoreconnect.apple.com/apps/1585503654/distribution) — releases
- [App Store listing](https://apps.apple.com/us/app/bb-ns-knight-life/id1585503654)
- [THE HARLEQUIN](https://mikeveson.com/dev) — the ticket board
