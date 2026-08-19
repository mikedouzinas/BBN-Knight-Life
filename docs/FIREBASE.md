# Firebase

Everything Knight Life can change without shipping an app update lives in Firebase: special
schedules, the default weekly schedule, class rosters, user accounts, and the schedule and
lunch menu images.

The Firebase project is called **BBN Daily** (project id `bbn-daily`).

## Getting in

1. Go to https://firebase.google.com
2. Sign in with an account that has been given Knight Life access. Ask Mike if you need it.
3. Press **Go to console** in the top right.
4. Open **BBN Daily**.

The tab that matters is **Firestore Database**. **Storage** holds the schedule and lunch
menu images.

## What the collections hold

| Collection | What it is |
| --- | --- |
| `schedules` | Special schedules, keyed by date |
| `special-schedules` | The older special schedule format the shipped app still reads |
| `default-schedules` | The normal weekly schedule, one document per weekday |
| `ifstatements` | App-wide switches, read at launch |
| `users` | One document per student: grade, classes, locker, settings |
| `classes` | Class rosters that students create and join |

`ifstatements` is where the bus number and the toggle for using online default schedules
live. It is read once in `AuthVC.swift` at sign in.

If you change a default schedule, **make the same change to Lunch 1 and Lunch 2**. They are
separate documents and they go out of sync easily.

## Who is allowed to change schedules

Schedule data is read-only for students. Writing to `schedules`, `special-schedules`,
`default-schedules`, `ifstatements`, or to Storage requires being an admin.

Admins are documents in the **`admins` collection in Firestore**, one per person, with the
document ID being their lowercase email. Both the Firestore rules and the Storage rules read
that same collection, so there is one list rather than two copies that can disagree.

The list is readable in the console by admins. It is deliberately not readable by students,
so it cannot be used as a directory.

If you are not an admin, the console will let you type an edit and then reject the save. That
is the rules working, not a bug. Ask an admin to make the change, or to add you.

### Adding an admin

Create a document in the `admins` collection with the person's lowercase email as the
document ID. That is the whole thing. No code change, no deploy, and it works before they
have ever signed in, which is usually when you want to add someone.

Clients cannot write to this collection at all, so it has to be done from the Firebase
console or with the Admin SDK.

Two things worth knowing. Someone's school address stops working when they leave, so add a
personal address as well if their access should outlive graduation. And if someone changes
their Google username, their sign-in token carries the new address while Firebase's stored
record still shows the old one, so keep both until they have signed in again.

Before 2026-08-19 any signed-in account could rewrite the school schedule and read every
student's record. That is what these rules closed.

## The rules are code, in this repo

- `firebase/firestore.rules`
- `firebase/storage.rules`

These files are the source of truth. They are commented, and reading them is the fastest way
to understand exactly who can do what.

### Changing the rules

1. Edit `firebase/firestore.rules` or `firebase/storage.rules` in the repo.
2. Open a pull request. Rules changes get reviewed, because a mistake here either locks 645
   students out of their schedules or opens the database back up.
3. Once merged, publish them: in the Firebase console, go to **Firestore Database**, then the
   **Rules** tab, paste in the file contents, and press **Publish**. Storage rules are under
   **Storage**, then **Rules**.
4. Check it worked. Sign in as a normal student account and confirm you can still see your
   schedule and your classes, and that you cannot write to `schedules`.

Adding or removing an admin is not a rules change. It is a document in the `admins`
collection, described above.

Never edit the rules only in the console. The console version and the repo version have to
match, and the repo is what the next person reads.

## Credentials

The app's `GoogleService-Info.plist` is committed and is meant to be. It is client
configuration, not a secret, and the security rules are what protect the data.

Service account keys are different. They bypass every rule on this page. They are gitignored
(`*serviceAccount*.json`, `*-adminsdk-*.json`) and must never be committed, pasted into a
message or a ticket, or checked into any branch. If you need admin scripting access, ask Mike rather than
generating a key and leaving it in the project folder.
