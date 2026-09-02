# Changing the schedule

Everything about getting a schedule change onto students' phones: the website, the AI setup,
and what to do when it goes wrong.

## The short version

Go to **[mikeveson.com/knight-life/admin](https://mikeveson.com/knight-life/admin)**, sign in
with your school Google account, paste the email BB&N sent, check what it shows you, publish.

## Who is allowed to do this

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

## Doing it on the website

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

The app picks up the change the next time a student opens it, and as of
[HQ-112](https://mikeveson.com/dev) it also sends a push: every publish (a day or a break) sends
one FCM message to the `schedule-updates` topic, which every device with notifications on has
subscribed to. See "Push notifications for schedule changes" below for the one manual step this
still needs before it reaches a real phone.

## Doing it by talking to an AI

Same permissions, same validation, same log. You describe the change or forward the email, the
agent shows you what it plans to publish, and you approve it.

Setup and the full safety model: **[mcp/README.md](../mcp/README.md)**.

The short version of the safety model: the agent cannot publish as a side effect of reading
something, and everything it does still runs through your admin account and the Firestore
rules. The confirmation step only protects anyone if you actually read the times.

## Push notifications for schedule changes

[HQ-112](https://mikeveson.com/dev). Both write routes — `publish` (a day) and `publish-range`
(a break) — send one push after a successful publish, through `notifyDayPublished` /
`notifyRangePublished` in `web/src/lib/notify/scheduleNotify.ts`.

**Why a topic, not a device-token list.** A schedule change affects every student the same
way, so there is no one to target individually. The app subscribes every device to the FCM
topic `schedule-updates` (`ScheduleNotifications.swift`), and the server sends one message to
that topic. Nothing about a device — its token, its owner — is stored anywhere for this; there
is no new Firestore collection and no new security rule.

**It reuses the existing "Notifications" switch in Settings**, the same one that already
turns the per-block local reminders on and off, rather than adding a second toggle. Turning it
off unsubscribes from the topic; turning it on (the default) subscribes.

**The send is best-effort.** If FCM is unreachable or misconfigured, `notifyDayPublished` /
`notifyRangePublished` log the error and return normally — a failed push never fails, blocks,
or retries the publish that already succeeded. The write to Firestore is the source of truth;
the notification is a courtesy on top of it.

**The one manual step this still needs, and it isn't done yet:** FCM cannot reach a real
iPhone until an APNs Auth Key is uploaded for this project — Firebase console → Project
Settings → Cloud Messaging → Apple app configuration → upload the `.p8` key from the Apple
Developer account this app is built under. Without it, `notifier.send()` will fail (silently,
by design, per the paragraph above) for every subscribed device. This is a one-time console
action, not a code change, and nobody has confirmed it is done as of 2026-08-29 — check the
Cloud Messaging tab before assuming a push actually arrives.

## Vacations and the school year

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

## When something goes wrong

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

**Signing in on the website says "admin approval required," but the iOS app never asks.**
([HQ-648](https://mikeveson.com/dev)) Not a bug — the two apps use different OAuth clients, and
BB&N's Google Workspace only trusts one of them so far.

| | Client ID | Type |
| --- | --- | --- |
| iOS app (`BBNDaily/GoogleService-Info.plist`) | `...5g3lkl7pjqpnvm5q2lbkspqt0cpdo4g5` | iOS |
| Web sign-in (Firebase Auth's Google provider) | `...70vufjqd54bcm5hs219qve7n1ct9ag32` | Web |

Both belong to the same Firebase project (`bbn-daily`). The iOS client has been signing students
in since 2021 and bbns.org trusts it; the web client is new to the workspace, so a browser
sign-in hits BB&N's third-party app restriction and shows the admin-approval screen instead of
completing sign-in. Nothing about the app changed — this is the workspace's allowlist, not our
code.

**If you hit this:** it means your bbns.org account has not been individually approved for the
web client yet, and requesting approval yourself sends a bare, unexplained app name to BB&N IT.
Don't do that cold — see the note below first, and ask a current maintainer whether BB&N IT has
already trusted `...70vufjqd54bcm5hs219qve7n1ct9ag32` domain-wide before you request anything.

**Status as of 2026-08-27: still open.** BB&N IT has not yet been asked to trust the web client.
Until they do, the admin tool at mikeveson.com/knight-life/admin only works for a bbns.org
account BB&N has individually approved, which blocks handing it to a new maintainer. The note
below is ready to send; it still needs someone signed into a bbns.org account to (a) read back
the exact consent-screen text so IT can match it to their logs, and (b) send it to BB&N IT
through whatever channel BB&N actually uses for that (helpdesk ticket, not a cold email).

<details>
<summary>Draft note for BB&N IT</summary>

> Subject: Trusting a second OAuth client for the Knight Life app
>
> Hi — I maintain Knight Life, the student schedule app BB&N students have used since 2021
> (App Store: "BB&N's Knight Life"). It signs in with a bbns.org Google account.
>
> We recently added a web-based admin tool (mikeveson.com/knight-life/admin) that lets the
> two or three student maintainers publish schedule changes without an Xcode rebuild. It signs
> in the same way, through the same Firebase project (`bbn-daily`), but a website needs its own
> OAuth client, separate from the iOS app's.
>
> Your workspace already trusts the iOS app's client:
> `...5g3lkl7pjqpnvm5q2lbkspqt0cpdo4g5` (iOS).
>
> Could you add the web client to the same trust list?
> `...70vufjqd54bcm5hs219qve7n1ct9ag32` (Web application).
>
> Happy to answer anything about the app or send more detail — thanks for taking a look.

</details>

Fill in the full client IDs from the table above before sending — they're truncated here on
purpose. Whoever sends this should paste it from a bbns.org account so IT can see the exact
consent screen it's replying to.

## Running the website on your own computer

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

## Putting a new version online

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

## Links

- [Firebase](https://console.firebase.google.com/u/0/project/bbn-daily/overview) — Firestore, Auth, rules
- [App Store Connect](https://appstoreconnect.apple.com/apps/1585503654/distribution) — releases
- [App Store listing](https://apps.apple.com/us/app/bb-ns-knight-life/id1585503654)
- [THE HARLEQUIN](https://mikeveson.com/dev) — the ticket board
