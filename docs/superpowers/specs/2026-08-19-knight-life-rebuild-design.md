# Knight Life rebuild — design

Date: 2026-08-19
Status: proposed
Board: THE HARLEQUIN, project `knight-life`, HQ-601 through HQ-624

---

## 1. What this is

Knight Life is a live iOS app for BB&N students. It has 645 lifetime accounts, 582 of them
`@bbns.org`, and 77 students signed up in September 2025. Special schedules were maintained
through March 2026. It is in use.

It was built starting 2021 in UIKit and storyboards. Its original author and its 2024 maintainer
have both left. This document describes rebuilding it in SwiftUI on a corrected data model,
without breaking the version students are running today.

### The pattern underneath every problem

Every failure in this system is the same failure. A critical path ran through one person, with
no mechanism behind them.

| Path | Who it ran through | What happened |
| --- | --- | --- |
| Publishing a schedule | 3 hardcoded email addresses | They graduated. Schedules stopped in March 2026. |
| Developer onboarding | A Google Doc only Mike can edit | Went stale. Its setup steps no longer work. |
| Building the project | Files the repo does not contain | Unbuildable from a clean clone since Aug 2024. |
| Handing the project on | "Text me." | The text stopped being answered. |

The rebuild is worth doing. The mechanisms are what make it survive. Where this document
chooses between a cleaner design and a design a student can take over, it chooses the second.

---

## 2. Constraints

**Never break the shipped app.** Students run 2.4.1 and cannot be forced to update. Every schema
change is additive. Approach A, chosen 2026-08-19.

**A wrong schedule is worse than no schedule.** Students trust it and miss class. Any automated
authoring path ends in a human confirming a rendered result.

**It has to outlive its maintainer.** Kai Veson and Lucas Ho are taking over. Design for the
person after them too.

---

## 3. Data model

### 3.1 Why the current one fails

`SecretSchedule.swift:147` sets `dateStyle = .full`, making the Firestore document ID the literal
string `Monday, September 15, 2025`, in the device's locale.

That single decision causes:

- Keys do not sort, so no range query is possible.
- So the app calls `getDocuments()` on the whole collection every launch: 81 of ~98 reads per
  launch, growing forever.
- So lookup is a linear string scan, re-run per calendar cell.
- And the key does not match on a non-US locale.

The v2 attempt moved to `2024/10/11`, which is closer but not zero-padded, so it still sorts
wrong: `2024/10/1` orders before `2024/2/1`.

### 3.2 The schema

```
schedules_v2/{YYYY-MM-DD}          one document per day, zero-padded ISO 8601
{
  date:      "2026-09-15",         duplicated as a field so it can be indexed and range-queried
  type:      "blocks" | "noschool" | "image",
  reason:    string?,              "Snow day"
  imageUrl:  string?,
  blocks:    Event[]?,
  updatedAt: timestamp,
  updatedBy: string,               who published it
  source:    "manual" | "ingest",  how it was authored
}

schedules_v2_meta/breaks
{ ranges: [ { start: "2026-06-04", end: "2026-08-31", reason: "Summer" } ] }

schedules_v2_meta/regular
{ monday: Event[], tuesday: Event[], ... }
```

**One document per day, not one document holding every day.** The current v2 keeps all 79 days
inside `schedules/special`. That is a single read, which is why it looks attractive, but it grows
without bound against Firestore's 1 MB document limit and every publish rewrites the whole thing.
Per-day documents with a bounded range query give bounded reads *and* bounded writes.

**Read pattern.** Fetch a two-week window, not the collection:

```swift
db.collection("schedules_v2")
  .whereField("date", isGreaterThanOrEqualTo: todayISO)
  .whereField("date", isLessThanOrEqualTo: twoWeeksISO)
  .limit(to: 20)
```

Expected reads per launch: **~6, down from ~98.**

**`updatedBy` and `source` are new and load-bearing.** Right now nothing records who published a
schedule, which is why we cannot tell who maintained it through March 2026 and therefore could not
tell whether locking the admin allowlist would break someone. Provenance is cheap to write and
impossible to reconstruct later.

### 3.3 The Event model, finished

The abandoned v2 `Event` struct is the right design. It expresses grade-specific programming,
faculty-only blocks, and both lunch waves as data. It needs three corrections.

```swift
struct ScheduleEvent: Codable, Hashable, Sendable {
    enum Kind: String, Codable { case block, lunch, group }

    var kind: Kind
    var block: String?              // "a"..."g", "advisory", "other"
    var name: String?               // "Extended B"
    var start: String?              // "08:15"  24-hour
    var end: String?                // "09:00"
    var audience: Audience?         // only on .group
    var children: [ScheduleEvent]?  // only on .group
}

struct Audience: Codable, Hashable, Sendable {
    var grades: [Int]?              // [9, 10, 11, 12]
    var roles: [String]?            // ["teacher"]
    var lunchWave: Int?             // 1 or 2
}
```

Corrections against the original:

1. **`Codable`.** The original is hand-parsed by `convertToEvent()` with force-casts (`as! String`)
   that crash on any malformed document. Conformance moves that failure to a thrown error.
2. **24-hour times.** The original stores `"8:15 am"`. `Extensions.swift:957` carries the comment
   *"Can't sort blocks yet because need to deal with 12h time format"* — the sort is disabled
   because the format cannot be compared. `"08:15"` sorts as a string.
3. **`Audience` replaces `filter` + `matchMode` + `lunchBlock`**, three loosely-coupled optionals
   that had to be interpreted together, with one typed value.

### 3.4 The `defaultVariables.swift` problem

`defaultVariables.swift:122` is a single 12,000-character line containing `Optional("...")`
wrappers on every field. It is debugger `po` output pasted into a Swift file. It compiles and
nobody can edit it.

The fallback schedule becomes a JSON resource in the bundle, decoded through the same `Codable`
path as the network data. Same decoder, same validation, one format.

---

## 4. Migration

### 4.1 Reconcile before re-keying (HQ-602 before HQ-603)

Two schemas are live and they disagree. Measured 2026-08-19: **43 days in v2 missing from v1, 32
in v1 missing from v2.** The app reads v1 in `getScheduleFor` and v2 in `getSchedule`, so some
students have been shown stale schedules. This is a present bug.

Reconcile first, while the divergence is still visible as two named collections. Migrating
unreconciled data into a clean schema launders the inconsistency somewhere harder to see.

#### Measured 2026-08-19

111 distinct dates across both schemas:

| Bucket | Count | What it is |
| --- | ---: | --- |
| v2 only | 43 | Real gaps in v1 |
| v1 only | 32 | **All on or before 2024-06-04.** Un-backfilled history, not drift. |
| both, equivalent | 24 | Agree |
| both, **different** | **12** | 3 disagree on whether it was a school day, 6 on content, 1 on order, 2 on the reason string only |

Only **2** of the 12 need a human: `2024-09-05` (F block ends 09:50 vs 09:55) and `2025-12-12`
(the two schemas describe different afternoons, and v1 also carries a junk `Test 4:00pm` row).

**v2 wins 8 of the 9 non-cosmetic disagreements, for a structural reason:** v1 has no grade
dimension, so every grade-differentiated day gets flattened or truncated on the way into it. The
disagreements cluster exactly on orientation week, PSAT day, and community-programming days.
**v2 is canonical.**

#### The shipped app has a split brain

The 2.4.1 calendar reads **v2 only** — the v1 loop in `CalendarVC.swift` is commented out at
lines 536–573. But `setNotifications()` is live, called from six places, and it calls
`getScheduleFor`, which reads **v1**.

So on the 12 diverged days, **what a student sees and what they are notified about come from
different schemas that disagree.** This is a present bug in the shipped app, not a migration risk.

It is worse on two entries where v1 was deliberately blanked and its `reason` set to an upgrade
prompt:

| v1 key | reason | v1 blocks | v2 |
| --- | --- | ---: | --- |
| `Tuesday, September 2, 2025-Friday, September 5, 2025` | "KnightLife Migration. Please update app" | 0 | full schedules |
| `Wednesday, October 1, 2025` | "Special Schedule - Please update KnightLife" | 0 | 5 blocks |

Blanking v1 was a deliberate nag aimed at pre-2.4.1 builds, whose calendars still read v1. It
worked for that. The unintended cost is that 2.4.1 users got **no notifications** on those five
real school days, because notifications read the blanked v1.

#### What this changes

- **v2 is canonical.** Migrate from v2, not from a merge of both.
- **The 32 v1-only dates are 2022–24 history.** Backfilling them is optional and low priority.
- **Dual-write to v1 is for notifications and pre-2.4.1 builds**, not for the 2.4.1 calendar,
  which is already on v2. That narrows §4.2's risk considerably.
- **Neither schema holds a single date after 2026-03-03.** There is no 2026-27 data at all, so
  the new schema starts on an empty year. That is a clean window and it will close when BB&N
  publishes the fall calendar.

#### Data quality to fix during migration

Three am/pm typos in v1 that resolve to midnight or 11:50pm; `blocks: {}` as an empty map rather
than an array on 2025-10-01; a `Test 4:00pm` junk row; narrow no-break spaces inside time strings;
a v2 full school day dated to Sunday 2025-10-05 with no Monday 10-06 entry anywhere (likely
off-by-one); and `schedules/break` labelling 2025/3/15–3/30 "Winter Break" where v1 says "Spring
Break".

### 4.2 Dual-write, with legacy as a generated projection

The admin tool writes the canonical `schedules_v2/{iso}` document, then **derives** the legacy
writes from it:

```
publish(day)
  → write schedules_v2/{YYYY-MM-DD}                       canonical
  → derive + write special-schedules/{Full Date String}   legacy v1, for 2.4.1
  → derive + write schedules/special.{y/m/d}              legacy v2, for 2.4.1
```

The legacy documents are never authored by hand again. They are projections of one source, which
is the difference between this dual-write and the hand-run one that already diverged.

A checker compares all three and fails loudly on drift. The lesson from `.gitignore` and from the
"LAST SYNCED" comment applies here: if two places must agree, generate one from the other and add
a check.

### 4.3 Retiring the legacy collections

Not left open-ended. The new app writes `clientVersion` to the user document on launch. Legacy
writes stop when **fewer than 5% of launches in a rolling 30 days come from a build below 3.0**.

That turns a risky cutover into a number someone can read off a dashboard. A number can be handed
to Kai or Lucas. A risky cutover can only be handed to Mike.

---

## 5. Security

### 5.1 Shipped 2026-08-19 (HQ-601, closed)

Rules were `allow read, write: if request.auth != null` on every path. Any signed-in account
could rewrite the school schedule or read every student's locker number, grade, and class list.

Now in `firebase/firestore.rules` and `firebase/storage.rules`:

- Schedule collections read-only except an admin allowlist.
- `users` allows `get` but denies `list`. The app looks up named classmates; nothing enumerates
  the collection. Bulk extraction now requires already knowing every uid.
- Cross-user writes narrowed to the A–G block fields, which is what `DaySelectVC` does on a class
  rename.

Verified in production against real admin and non-admin ID tokens.

### 5.2 The allowlist became data (HQ-615, shipped 2026-08-19)

Hardcoding admins in the rules file meant every handoff was a code change and a deploy, which is
friction on the path that most needs to stay easy. It also published five `@bbns.org` addresses,
two belonging to current high schoolers, into a public repository.

Admins are now `admins/{lowercase-email}` documents in Firestore. Firestore rules read them with
`exists()`; Storage rules read the same collection with `firestore.exists()`, so **one list
governs both and they cannot drift**. The collection is admin-readable only, so the maintainer
list is not a directory any signed-in student can pull, and `allow write: if false` means it is
changed through the console or the Admin SDK, never by the app.

Keyed by email rather than uid deliberately: a maintainer can be granted access before they have
ever signed in, which is exactly the moment you want to add someone.

Deployed in two releases so no one could lose access mid-transition. Release one accepted either
the Firestore lookup or the old hardcoded list. Only after a test email present *only* in the
collection was proven to gain access, and to lose it again when the document was deleted, was the
hardcoded list removed in release two.

**Adding a maintainer is now one Firestore write.** That is the mechanism this project has been
missing everywhere.

New collections get explicit rules. The catch-all stays `allow read, write: if false`.

Note for §6: the web admin tool reads this same collection, so the tool and the rules agree by
construction rather than by someone remembering to update both.

---

## 6. The schedule ingest tool (HQ-605)

### 6.1 The problem it solves

BB&N emails a schedule change. A human retypes it into the Firebase console. That manual step is
the reason the app went stale, and no amount of app polish addresses it.

### 6.2 Shape

Admin supplies a photo, a PDF, or pasted text. A model emits `ScheduleEvent` JSON validated
against the schema. The tool renders it **as the real student-facing schedule**. The admin
compares it to the email and publishes.

```
  input ──▶ model ──▶ validate ──┬── invalid ──▶ retry with the error, never publish
                                 └── valid ────▶ render as the real schedule
                                                        │
                                              admin confirms ──▶ publish (§4.2)
```

**The confirmation step is not optional and not bureaucracy.** It costs about fifteen seconds and
removes the entire class of failure where a hallucinated block sends 500 students to the wrong
room. Without it this design would not be worth building.

Validation failure means retry, never publish. Unvalidated model output never reaches Firestore.

### 6.3 Borrowed from Cere

The portfolio repo's `/playground/harlequin` demo establishes three moves worth copying:

1. **An injection seam.** `useCere` takes `{ plannerUrl, applyAction }`, so the same components
   write to a real backend or to local mock state. This is what makes the public demo (HQ-613)
   free rather than a fork.
2. **A separate sandboxed API route**, not the real one behind a flag.
3. **Auth by route placement**, not by a check inside a shared page.

### 6.4 Where it lives — a real decision

**Recommendation: a small Next.js app in `web/` inside `mikedouzinas/BBN-Knight-Life`, deployed
separately. Not a route in the portfolio repo.**

The portfolio repo is tempting: Cere lives there, auth middleware exists, deployment is solved.
But it is Mike's personal site. Putting the school's admin tool inside it means a student
maintainer cannot touch the tool without access to Mike's personal repository, which contradicts
the entire succession goal and HQ-611.

The cost is duplicating some pattern code rather than importing it. That is the right trade: the
alternative couples a school's app to one person's website permanently.

Auth: Google sign-in, restricted to the same admin source as §5.2.

---

## 7. The SwiftUI app (HQ-609)

The existing app is the specification, not the foundation. What it does is right. How it is built
is not: static mutable globals as the data layer, a 1,302-line `Extensions.swift` holding the core
logic, seven files coordinating through `static var link`, 30 force-casts, two empty test targets.

### 7.1 Architecture, from Iris Mobile

- `@MainActor final class ... ObservableObject` view models, state as `@Published private(set)`.
- `actor` services for anything doing I/O.
- **A protocol-injected data source** (`ScheduleDataSource`) so previews and tests run on a mock.
  This is what makes the app testable at all, which the current one is not.
- **Optional environment values** rather than `@EnvironmentObject`, which crashes previews when
  missing.
- An explicit `Phase { idle, loading, loaded, failed(String) }` per fetch.
- **Stale-while-revalidate disk caching**: last schedule read from disk in `init`, no launch
  spinner, background refresh swaps underneath, and **a failed refresh never blanks the view.**

### 7.2 Visual language

Flat cards, `0.05` opacity fill, radius 15 continuous. Gradient on text, never behind it.
Monospaced tracked eyebrows for day headers. Springs, not bare easing. Recency carried by opacity
rather than badges.

### 7.3 Two bugs the rebuild must not carry forward

**The launch GIF (HQ-606).** `Extensions.swift:493` decodes every frame into two simultaneous
in-memory arrays. `spring.gif` is 500×288 × 239 frames ≈ **131 MB**; `fall.gif` ≈ 115 MB;
`snowfall.gif` ≈ 90 MB. On the launch screen, every launch, most of the school year. Stream frames
from the `CGImageSource` or use looping video through `AVPlayerLayer`.

**The locale crash (HQ-607).** `Extensions.swift:752` sets `dateFormat` then `dateStyle`, which
silently discards `dateFormat`, then force-unwraps `firstIndex(of: ",")`. French renders
`lundi 15 septembre 2025` with no comma, so the unwrap is nil and the app crashes on launch. Use
`Calendar` components; never parse a display string.

---

## 8. Bug reports (HQ-610)

Reports go to a Google Doc nobody triages.

Route them to a sink a daily scheduled pass reads. The pass decides duplicate or new, files new
ones to `knight-life`, and where the fix is small enough opens a PR against the repo.

**It opens PRs. It never merges.** Opening a PR is a claim about attention, not completion.

---

## 9. Contribution (HQ-611, HQ-624)

The project is deliberately open to student contributors.

This is the structural fix, not a nice-to-have. Requires:

- **A build that works from a clean clone** (HQ-608). `.gitignore` lines 91–94 add `*.cc`, `*.h`,
  `*.inc`, `*.m` with no path prefix, matching at every depth and stripping every header out of
  the committed `Pods/`. Git tracks 1,850 of 7,041 files there and zero `.h` files. A CI job that
  builds from a fresh clone makes this impossible to reintroduce.
- **Onboarding in the repo** (HQ-612), versioned with the code, not in a Google Doc.
- **A visible backlog** — the board, or a mirror of it.
- **Credits** (HQ-624). `AboutUsVC` hardcodes one name across an app several graduating classes
  built. A plaque with contributors and graduation years is the visible half of this: an app that
  shows its lineage reads as something students join.

---

## 10. Sequencing

Each wave leaves the system better than it found it, so stopping between waves is safe.

| Wave | Tickets | Leaves behind |
| --- | --- | --- |
| **0 — done** | HQ-601 | Exposure closed. |
| **1 — foundation** | HQ-608, HQ-602, HQ-612 | Anyone can build it. Data is consistent. Onboarding is true. |
| **2 — schema** | HQ-603, HQ-604, HQ-615 | ISO schema, generated dual-write, admins as data. |
| **3 — the tool** | HQ-605, HQ-613 | Schedules publishable by a non-developer. **Succession no longer depends on Mike.** |
| **4 — the app** | HQ-609, HQ-606, HQ-607 | SwiftUI app on the new schema. |
| **5 — durability** | HQ-610, HQ-611, HQ-624 | Bugs triaged, contributors invited and credited. |

Wave 3 is the one that matters most, and it is worth saying plainly: **if only one wave ever
ships, it should be that one.** A beautiful SwiftUI app nobody can publish a snow day to dies the
same death this one did.

These waves cover the rebuild only. The remaining `knight-life` tickets — HQ-113 through HQ-120,
HQ-614, and HQ-616 through HQ-623 — are feature backlog, unsequenced on purpose. They are what a
student contributor picks up once wave 1 makes the repo buildable, and several (HQ-614, HQ-619,
HQ-620, HQ-621) get substantially easier once the schema in §3 exists.

---

## 11. Open questions

1. **Who maintained schedules through March 2026?** No provenance is recorded, which is why
   `updatedBy` exists in §3.2. Worth asking Kai.
2. **The `classes` collection stays fully writable.** Its ownership logic (`owner`, `isEditable`)
   is spread across `DaySelectVC` and `ClassesOptionsPopupVC`; enforcing it in rules risks locking
   a student out of their schedule. Deliberately deferred, not overlooked.
3. **`ItsMeNoobieboy`'s real name**, for HQ-624.
4. **Does BB&N sanction this?** Determines whether HQ-622 (Veracross) is reachable at all, and
   who owns the App Store listing long term.
