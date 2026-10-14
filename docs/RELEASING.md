# Releasing to the App Store

This is how a change on `main` becomes an update students actually get. It takes about an
hour of waiting spread across a few steps, plus a few days for Apple's review.

You need to be on the Knight Life App Store Connect team to do this. Ask Mike.

## 0. The access you need, which is more specific than "being on the team"

Being added to the team is not enough on its own, and the way it fails is confusing: everything
works until **Archive → Distribute**, which then refuses because it cannot create a
distribution certificate. The role and the two permissions below are what actually matter.

Ask for, in App Store Connect → **Users and Access** → your name:

- Role: **App Manager** (Admin also works, but is more than this needs)
- **Access to Certificates, Identifiers & Profiles** — a separate checkbox on that screen
- **Access to Cloud Managed Distribution Certificate** — also a separate checkbox

App Manager alone does not include either of those. They are what let Xcode's automatic
signing create the distribution certificate during Archive, which is the step everything else
depends on.

**Check it yourself before you need it**, rather than discovering it the evening you plan to
ship. Go to [developer.apple.com/account](https://developer.apple.com/account) → Certificates,
Identifiers & Profiles → **Certificates** → **+**. If **Apple Distribution** is selectable,
you are set. If it is missing or greyed out, the permissions have not been granted yet.

You will also want **Firebase** access (project `bbn-daily`, at least **Editor**) if you are
touching push notifications or Firestore, though not for a plain release.

## From the command line (and for an agent)

`scripts/release.sh` does steps 1 to 3 below in one command:

```bash
scripts/release.sh 2.6.1 --no-upload   # bump, archive, export and check the build, no upload
scripts/release.sh 2.6.1               # the same, then upload it to App Store Connect
```

It raises the version and the build number in both build configurations, archives, exports,
and refuses to upload a build whose push entitlement is not `production` (such a build
silently breaks notifications for every student). It signs and uploads with the Apple ID
signed into Xcode (Settings, Accounts), so you need no key. An agent with no Xcode login can
set `ASC_KEY_PATH`, `ASC_KEY_ID` and `ASC_ISSUER_ID` to an App Store Connect API key of its
own. Never commit a key; this repository is public.

Then commit the bump on a branch, open a pull request, wait for **Build from a fresh clone**
(about 35 minutes), merge, and carry on from step 4. A release is one cycle: TestFlight first,
check it there, then submit.

## 1. Bump the version number

In Xcode, select the project in the left sidebar, then the `BBNDaily` target, then
**General**. Update **Version**, and raise **Build** by one. App Store Connect rejects an upload whose build
number it has already seen, even under a new version.

The version must be `X.Y.Z`, three non-negative integers, no leading zeroes, and it has to go
up. So `1.9.0` then `1.10.0` then `1.11.0`. If you skip this, the upload fails.

Rough guide: patch (`Z`) for bug fixes, minor (`Y`) for new features, major (`X`) for a
release that changes how the app works.

## 2. Archive

1. In the Xcode toolbar, set the run destination to **Any iOS Device**. You cannot archive
   with a Simulator selected.
2. **Product**, then **Archive**.
3. Wait. This builds the whole app in release configuration.
4. The Organizer window opens when it finishes, showing every archive you have made.

## 3. Upload to App Store Connect

1. With your new archive selected, press **Distribute App**.
2. Take the default options through the whole flow (App Store Connect, Upload).
3. Wait again. Uploading takes a while.

## 4. Clear compliance in TestFlight

1. Go to https://appstoreconnect.apple.com
2. **Apps**, then **BB&N's Knight Life**.
3. Open the **TestFlight** tab. Your new build number should be at the top.
4. Apple takes 10 to 30 minutes to process it. There is no encryption question to answer:
   `Info.plist` declares `ITSAppUsesNonExemptEncryption = false` (Knight Life uses only
   standard HTTPS), so the build goes straight to the internal testers.
5. Install it from TestFlight and check what changed before going further.

## 5. Submit for review

1. Go to the **App Store** tab, which is a separate list from the Xcode versions you were
   just working with.
2. Create a new version, using the same version number you set in step 1.
3. Fill in **What's New in This Version**. Keep it short and student-readable. "Bug fixes" is
   fine for a fix release. Say the actual feature if there is one.
4. Scroll down to **Build** and press **Add Build**. Pick the build you just uploaded. This
   is the step people forget.
5. Press **Save** in the top right.
6. Press **Add for Review**, then **Submit to App Review**.

Apple usually takes one to three days. You get an email either way. If it is rejected, the
message says why, and it is normally something small in the metadata rather than the code.

## Notes

- Steps 1 to 3 are `scripts/release.sh`. Steps 4 and 5 are App Store Connect in a browser.
- Students on old versions do not update automatically, and some never update. Anything you
  change on the Firebase side has to keep working for whatever version is still out there.
