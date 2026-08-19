# Rebuilding Knight Life

A design for HQ-609, written 2026-08-19, after a day spent finding out what is actually
wrong with the app.

## The thing this document exists to argue

**The UI is not the problem.** Every defect found today was data-shaped:

| What a student saw | What it actually was |
| --- | --- |
| A seven-block Wednesday in mid-August | An unknown date fell through to the weekly pattern |
| Notifications through summer break | Two resolvers, one of which did not know about breaks |
| A phantom lunch menu | A read with no guard on an absent document |
| 101 Firestore reads per launch | A collection listed for a screen 8 people can open |
| A launch crash waiting on one typo | 28 force casts over documents anyone can edit |

Not one of those is a view. A SwiftUI rewrite that ports the same data layer ships every one
of them again, in nicer typography.

So the order is: **schema, then resolver, then views.** If only the first two land, the app
is materially better and the third can wait a year. If only the third lands, nothing is
fixed.

## What must not break

**The shipped 2.4.1 app can never be updated.** Roughly 582 students carry a binary from
September 2024, and no rebuild changes that. Everything below runs alongside it, not instead
of it, until a number says otherwise.

That single fact drives most of the design. It means:

- Firestore documents keep their current shape until the old app's usage is measurably near
  zero. New shapes go in new documents, never as new fields on old ones.
- **No document-level field may ever be added to `schedules/special` or `schedules/break`.**
  The old app iterates every field and force-casts each one. One `updatedAt` is a launch
  crash for everybody. This is written in `web/src/lib/schedule/publish.ts` and is not a
  style preference.
- Retirement is a decision with a threshold, not a vibe. Log the app version on launch, and
  retire the old schema when fewer than N students are on 2.4.1, with N chosen in advance.

## The data layer

### One schema, ISO-keyed

`schedules_v2/{YYYY-MM-DD}`, one document per published day. Zero-padded, sortable,
locale-free.

The current keys are the root of most of this. `special-schedules` is keyed on
`Monday, September 15, 2025`, produced by `dateStyle = .full`, which means:

- the keys do not sort, so no range query is possible, so the app lists the whole collection;
- on a non-US locale the app writes a key nothing else can find;
- `Extensions.swift` force-unwrapped `firstIndex(of: ",")` on that string, which crashes in
  any locale whose date has no comma.

**Never derive meaning from a formatted display string.** That one rule would have prevented
the schema, the crash, and the read cost. It belongs at the top of the new code.

`schedules/special` (v2) is closer, keyed `2024/10/11`, but not zero-padded, so `2024/10/1`
sorts before `2024/2/1`. It still cannot be range-queried.

### Reads are bounded

A launch loads a two-week window: `where(date >= today).where(date <= today+14)`. Not the
whole collection, ever. Today that is 19 reads after removing the legacy scan; with a window
it is closer to 8.

### Everything is decoded, nothing is force-cast

One `Codable` model per document, decoded once at the boundary, with a malformed document
skipped rather than fatal. The rule from HQ-627 carries over: **one missing day is a wrong
schedule for one date, and a crash is no app at all for anybody.**

28 `as!` casts remain on `main`, counted 2026-08-19, over documents an admin can edit by hand
in a console. That is not a hypothetical; the admin tool exists precisely because people edit
this data. HQ-627 removed the ones on the launch path; the rest are still there.

## The resolver

**One function decides what a day is. It takes its inputs as parameters and returns a value.**

```swift
struct DayResolver {
    let term: Term?
    let breaks: [Break]
    let published: [Date: PublishedDay]
    let weekly: WeeklyPattern

    func resolve(_ date: Date) -> ResolvedDay
}
```

No statics, no `LoginVC.specialDays`, no reaching into a view controller. That signature is
the whole argument: a resolver you can construct in a test with four literals is a resolver
that can be tested, and the current one cannot be.

**Precedence, which is the part a future change will break:**

1. A published day wins. Somebody decided it.
2. Then a break. A span outranks the weekly pattern.
3. Then a weekend.
4. Then the term. Outside it, there is no school.
5. Then the weekly pattern.

**Fail open at every step.** A missing term, an unparseable one, a reversed one: all leave
the app behaving as though the rule did not exist. "The read failed" must never render to 582
students as "there is no school today." That is a worse failure than a stale calendar, and it
would be ours rather than the calendar's.

**HQ-602 is the cautionary tale and it is mine.** Its commit message says "resolve every day
through one function." It built the resolver, pointed notifications at it, and left
`CalendarVC` with its own copy, so the two drifted the same week. A commit message is a
claim. The test is what makes it true: construct one resolver, assert the calendar and the
notification scheduler produce the same answer for the same date.

## Notifications

Today they are **local only**. `setNotifications()` schedules up to 64 requests on the device
and nothing anywhere sends a push. So a snow day published at 6am reaches no phone that is
not opened, which is the single largest gap in the product (HQ-639).

The rebuild should decide three things explicitly rather than inherit them:

1. **Push on publish.** A Cloud Function on write plus a token registry. This is the only way
   a change reaches a phone that stays in a pocket.
2. **What deserves a notification at all.** Every block is almost certainly wrong. A change
   to today or tomorrow is worth waking someone for; a normal Tuesday is not.
3. **Whether local scheduling stays** as the offline fallback, or goes. Keeping both without
   deciding is how the 64-request cap came to be spent blindly, first-come by date, so the
   last days in the window silently got nothing.

## Architecture

Adopt the Iris Mobile patterns, for the reason they exist rather than for consistency:

- `@MainActor final class ViewModel: ObservableObject` with `@Published private(set)`, so
  state has exactly one writer.
- `actor` services for I/O, so a Firestore read cannot race a view update.
- A protocol-injected data source, so previews and tests run against a mock and **the seeded
  scenarios below become possible at all**.
- An explicit `Phase` enum (`.loading`, `.loaded`, `.failed`) rather than a bare optional, so
  "no data yet" and "no data" stop being the same state. The phantom lunch menu was exactly
  that confusion.
- Stale-while-revalidate disk caching: show the last known schedule instantly, refresh
  behind it. A student opening the app between classes should not watch a spinner.

Six files pass state through `static var link` view-controller references, and
`Extensions.swift` is 1,404 lines holding the core logic. Neither gets ported. They are the
reason the current app cannot be tested: there is no seam to inject anything at.

## Testing, which is a prerequisite and not a follow-up

The app had **two empty test targets from 2021** until today. It now has 20 real tests and a
working Firestore emulator. Before the rebuild starts, HQ-646 should give it:

- The app pointed at the emulator behind a launch argument.
- A seed script per scenario: a normal Tuesday, a snow day, a break, an image day, a day with
  no lunch, an empty calendar, a term boundary.
- UI tests that launch, tap every tab, open settings, select a date. The doubled tab bar, the
  invisible button, the white-on-white light mode and the Settings crash were each found by
  one person on one phone, one at a time, over several rounds. A launch-and-tap-everything
  test finds that whole class in one run.
- One test that publishes through the admin tool and asserts the app renders it. That is the
  actual product promise and it currently has no coverage anywhere.

**Do this before the rebuild, not after.** A rewrite with no end-to-end coverage has only
somebody's memory of the old app as its correctness check, and the person with that memory
graduates in December.

## Sequence

| | | |
| --- | --- | --- |
| 1 | HQ-646 | The harness. Nothing after this is verifiable without it. |
| 2 | HQ-603 | ISO schema, dual-write, backfill, bounded reads. |
| 3 | HQ-639 | Notifications, decided rather than inherited. |
| 4 | HQ-609 | The SwiftUI app, on a data layer that is already correct. |
| 5 | | Retire the old schema against the version threshold. |

Steps 1 through 3 are worth doing even if step 4 never happens. Step 4 alone is worth
very little.

## The requirement underneath all of it

Mike graduates in December 2026. His brother is at BB&N; Lucas Ho is taking over.

Every failure found today had the same shape: **a critical path through one person with no
mechanism behind it.** The schedule editable by three graduated addresses. Onboarding in a
document only one person could edit. A build depending on files the repository did not
contain. A handoff plan that read "text me."

So the test for any decision in this rebuild is not "is this clean." It is: **can a student
who has never met Mike pick this up from the repository alone and change it safely?** If the
answer needs a conversation, the design is wrong.
