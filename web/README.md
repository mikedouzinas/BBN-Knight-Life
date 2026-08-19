# Knight Life admin (HQ-605)

BB&N emails a schedule change. Someone retypes it into the Firebase console. That manual
step is why the app went stale when its maintainers graduated, and no amount of app
polish addresses it.

This tool removes the typing and keeps the human. Paste the email, or drop in the PDF or
a photo. Claude turns it into structured data, the data is validated against a strict
schema, and the result is rendered **as the real student-facing schedule**. Nothing is
written until a person looks at that rendering and presses Publish.

```
  input ──▶ model ──▶ validate ──┬── invalid ──▶ retry with the error, never publish
                                 └── valid ────▶ render as the real schedule
                                                        │
                                              admin confirms ──▶ publish
```

**The confirmation step is not optional and not bureaucracy.** A wrong schedule is worse
than no schedule, because students trust it and miss class. Fifteen seconds of looking
removes the entire class of failure where a hallucinated block sends 500 people to the
wrong room.

## Run it

```bash
cd web
npm install
cp .env.local.example .env.local     # then fill it in, see below
npm run dev                          # http://localhost:3000
```

- `/`: what this is.
- `/admin`: the real tool. Google sign-in, admin only.
- `/demo`: the same screens against nothing. Cannot write a schedule. Off unless `DEMO_ENABLED=true`.

## Environment

Every name is in `.env.local.example`. `.env.local` is gitignored, and **this repo is
public**, so nothing with a value in it belongs in a committed file.

| Variable | What it is |
| --- | --- |
| `ANTHROPIC_API_KEY` | Reads the schedule. |
| `GOOGLE_APPLICATION_CREDENTIALS` | Absolute path to the Firebase service account JSON. Never copy the file into this repo. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | The same JSON as one line, for hosts with no filesystem for secrets. Set this **or** the path, not both. |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Firebase console, Project settings, Your apps, Web app. |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Usually `bbn-daily.firebaseapp.com`. |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | `bbn-daily`. |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | From the same page. |
| `DEMO_ENABLED` | `true` turns on `/api/demo/ingest`. It has no sign-in in front of it and still spends tokens, so it defaults off. |

The `NEXT_PUBLIC_*` values are not secrets. Nothing about them grants access.

## Who can use it

A Google account is authorized if and only if a document exists at
`admins/{their-lowercase-email}` in Firestore. That is the same collection
`firebase/firestore.rules` reads with `exists()`, so the tool and the rules agree by
construction rather than by someone remembering to update both. No email address is
hardcoded anywhere in this repo.

**Adding a maintainer is one Firestore write.** Create `admins/new.person@bbns.org`. They
can be added before they have ever signed in, which is exactly when you want to add
someone. Removing them is deleting the document.

## What publishing writes

One function, `publishDay` in `src/lib/schedule/publish.ts`, is the only path from data to
storage. It writes two places in a single batch:

| Destination | What it is |
| --- | --- |
| `schedules/special`, field `2025/10/16` | Canonical. What the 2.4.1 calendar reads. |
| `special-schedules/Thursday, October 16, 2025` | **Derived**, never authored. What 2.4.1 uses for notifications and what pre-2.4.1 builds use for everything. |
| `schedule-publish-log/2025-10-16` | Who published it, when, and from what. New. |

The legacy document is a projection of the canonical one. That is the difference between
this dual-write and the hand-run one that left 43 days in one schema and not the other,
and 12 days where the two disagree. `src/lib/schedule/derive.ts` holds the mapping and
`derive.test.ts` checks it against real production documents.

**Do not add a document-level field to `schedules/special`.** `AuthVC.swift:69` iterates
every field of that document and force-casts each one to a day. An `updatedAt` at the top
level crashes the shipped app on launch for every student. That is why provenance has its
own collection.

### When HQ-603 lands

The ISO-keyed schema in the design doc (`schedules_v2/{YYYY-MM-DD}`) does not exist yet.
When it does, add the write to `FirestoreScheduleStore.commit` and a field to
`PublishPlan`. The UI and the model layer do not change, because neither of them knows
where anything is stored.

## Tests

```bash
npm test                                  # 57 tests, offline, no API key, no network
```

What is and is not covered:

| Covered | How |
| --- | --- |
| The v2 to v1 derivation | Against two real production days, including that `blocks` is the second lunch wave and `blocks-l1` the first. Getting that backwards sends half the school to lunch an hour early and errors nowhere. |
| The schema | Rejects 24-hour time, invented block letters, a lunch split with no block, a no-school day with no reason. |
| The student-facing render | Ported from `Extensions.swift` and checked per grade and per lunch wave. |
| The publish path | Against an in-memory store: nothing partial, nothing on a validation failure, the other 78 days untouched. |
| The retry loop | With a stubbed model: invalid output goes back with its reason attached and is never returned as a schedule. |

Two suites are skipped by default because they need something:

```bash
# The real model. Costs money. Run it when the prompt or the tool schema changes.
ANTHROPIC_API_KEY=... npx vitest run src/lib/ingest/extract.live.test.ts

# The real Firestore write path, against the emulator. Needs Java 21+.
JAVA_HOME=$(/usr/libexec/java_home -v 21+) \
  npx firebase-tools emulators:exec --only firestore --project knight-life-test \
  "cd web && npx vitest run src/lib/firebase"
```

Nothing in this repo writes to production Firestore from a test.

## Deploying

Any host that runs Next.js. Not Mike's portfolio: a student maintainer has to be able to
touch this without access to his personal repository, which is the whole succession point.

1. Point it at this directory as the project root.
2. Set the environment above. On Vercel use `FIREBASE_SERVICE_ACCOUNT_JSON`, since there
   is no filesystem to put a key file on.
3. Add the deployed domain to Firebase Authentication, Settings, Authorized domains, or
   Google sign-in will fail with `auth/unauthorized-domain`.
4. Leave `DEMO_ENABLED` unset in production unless you mean to expose the demo.

## Layout

```
src/lib/schedule/     types, time, dates, schema, render, derive, publish  (no I/O, all tested)
src/lib/ingest/       the tool definition, the prompt, and the validate-and-retry loop
src/lib/firebase/     admin SDK, the Firestore store, the browser client, requireAdmin
src/components/       useIngest and the screens, with no idea what they are talking to
src/app/admin/        the real tool
src/app/demo/         the sandbox
src/app/api/admin/    every route here starts with requireAdmin
src/app/api/demo/     no Firestore client, no write path
```

Three patterns are borrowed from Cere, the agent on Mike's portfolio site:

1. **An injection seam.** `useIngest({ ingestUrl, publishDay })`, so the same screens
   target the real backend or local state. It is what makes a public demo (HQ-613) a
   prop rather than a fork.
2. **A separate sandboxed route**, not the real one behind a flag.
3. **Auth by route placement.** Everything under `/api/admin` starts with `requireAdmin`;
   the sandbox under `/api/demo` has no Firestore client to guard.
