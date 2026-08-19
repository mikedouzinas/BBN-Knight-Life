# Contributing to Knight Life

Knight Life is the BB&N student app. It shows you your schedule, your classes, special
schedules, and the lunch menu. Around 645 people have accounts and students open it on
school mornings to find out what block it is.

It is an iOS app written in Swift, and it was built by BB&N students.

## You are invited to work on this

From Mike, who maintains it:

> I want to make it very open that people can work on Knight Life. If they have ideas for
> what they want to see in this then reach out and let's get you developing. It's an app
> made for students so if you have a vision for this then build it.

You do not need to have shipped an app before. You do not need permission to start. Clone
it, get it building, change something, and open a pull request.

## What you need

- A Mac. iOS development only works on macOS.
- Xcode, free from the Mac App Store. It is a large download, so start it before you need it.
- An Apple ID signed into Xcode (Xcode, Settings, Accounts). A free one is enough to run the
  app on the Simulator and on your own iPhone.
- CocoaPods, which manages the third party code this project depends on.

### Installing CocoaPods

CocoaPods is a Ruby tool. The official guide is at
https://guides.cocoapods.org/using/getting-started.html and it covers the differences
between Apple Silicon and Intel Macs.

The short version, using Homebrew (https://brew.sh):

```bash
brew install cocoapods
pod --version
```

If `pod --version` prints a version number, you are set.

## Getting the code running

```bash
git clone https://github.com/mikedouzinas/BBN-Knight-Life.git
cd BBN-Knight-Life
pod install
open BBNDaily.xcworkspace
```

Then press Command + R in Xcode to build and run.

Four things worth knowing:

1. **The repo lives at `github.com/mikedouzinas/BBN-Knight-Life`.** Older instructions point
   at `github.com/milobaron/BBN-Knight-Life`. That URL currently redirects, but a different
   person now owns the `milobaron` account, so use the `mikedouzinas` URL.
2. **Always open `BBNDaily.xcworkspace`, never `BBNDaily.xcodeproj`.** The `.xcodeproj` does
   not know about the pods, so it will not build. The `.xcworkspace` is regenerated every
   time you run `pod install`.
3. **`pod install` is not optional on a fresh clone.** It is what puts the dependencies in
   place.
4. The app target is called `BBNDaily`, which is the app's original name.

> **If the build fails on a clean clone, that is a known bug, not you.**
> The `.gitignore` currently strips `.h`, `.m`, `.cc`, and `.inc` files out of the committed
> `Pods/` directory, so a fresh clone is missing headers it needs to compile. This is being
> fixed under ticket HQ-608. If you hit it before that lands, ask Mike, and do not spend an
> afternoon assuming you installed something wrong.

## How the project is laid out

```
BBNDaily/              the app itself
  Login/               sign in and account setup
  Tabs/                the main screens, one folder per tab
  Tabs/Settings/       settings, including AboutUsVC (the credits screen)
  GoogleService-Info.plist   Firebase configuration
BBNDailyWidget/        the home screen widget
BBNDailyTests/         unit tests
BBNDailyUITests/       UI tests
Pods/                  third party dependencies, managed by CocoaPods
firebase/              Firestore and Storage security rules (see docs/FIREBASE.md)
docs/                  this documentation
Podfile                the list of dependencies
```

## Working with pods

A pod is somebody else's code that you get to use instead of writing your own. Knight Life
uses pods for Firebase, Google Sign In, the calendar view, the bubble tab bar, and more. The
full list is in `Podfile`.

### Adding a new pod

1. Quit Xcode (Command + Q) and save your work first.
2. In Terminal, `cd` into the Knight Life folder.
3. Open the Podfile: `open Podfile`
4. Add your pod on its own line, anywhere between `# Pods for BBNDaily` and
   `target 'BBNDailyTests' do`. The pod's own README tells you the exact name. For example,
   the bubble tab bar's line is `pod 'BubbleTabBar'`.
5. Save the Podfile (Command + S) and close it.
6. Back in Terminal, run `pod install`. This takes a minute.
7. Reopen the workspace: `open BBNDaily.xcworkspace`

Commit both the changed `Podfile` and the changed `Podfile.lock`.

### Crediting a new pod

The app is on the App Store, so most dependencies have to be credited. Open
`BBNDaily/Tabs/Settings/AboutUsVC.swift`, find `setData()`, and add a line:

```swift
libraries2.append(Library(name: "Name Of Pod", url: "https://link/to/its/LICENSE"))
```

A few licenses do not require attribution. Check the pod's license before deciding to skip
it, and when in doubt, credit it.

## Firebase

Schedules, classes, and user accounts live in Firebase. The security rules that decide who
can change what are in this repo under `firebase/`, and changing a schedule requires being
on an admin allowlist.

Read `docs/FIREBASE.md` before touching anything in the Firebase console.

## Releasing to the App Store

See `docs/RELEASING.md`.

## Picking something to work on

The old version of this guide ended with a to-do list. That list is now tracked as tickets so
it does not silently rot again. Ask Mike for the current Knight Life backlog, or look at the
open issues on GitHub.

You do not have to pick from the backlog. If you have an idea for something the app should
do, that counts, and it is the better reason to start. Say what you want to build before you
build it, so nobody duplicates work.

To claim something: open an issue saying what you are doing, or comment on the existing one.
Then branch, build, and open a pull request.

### Pull requests

- Branch off `main`.
- Keep a pull request to one change. Small ones get reviewed faster.
- Say what you changed and how you checked it works. A screenshot or a screen recording from
  the Simulator is worth a lot for anything visual.
- Do not commit credentials. Service account keys and anything matching `*-adminsdk-*.json`
  are gitignored on purpose. If you ever find a key in a diff, stop and say so.

## Troubleshooting

App development throws errors for what look like no reason. Work down this list.

1. **Clean the build folder**: Command + Shift + K in Xcode, then build again. This fixes a
   surprising share of problems.
2. **Reinstall the pods**: `pod install` in Terminal. If that does not do it, `pod update`,
   though note that `pod update` can pull newer dependency versions and change
   `Podfile.lock`, so read what it changed.
3. **Check you opened the `.xcworkspace`**, not the `.xcodeproj`.
4. **Search the exact error text.** Copy the error, paste it into a search engine. Someone
   has hit it before. An AI assistant is also decent at Swift build errors, though check what
   it tells you rather than pasting it in.
5. **Xcode version drift.** Every new Xcode deprecates something. An error after an Xcode
   update usually means a setting or an API moved, not that you broke anything.

If none of that works, open an issue on
https://github.com/mikedouzinas/BBN-Knight-Life with the full error text, your Xcode version,
and what you were doing. Write it down in the repo rather than sending a text message. The
last version of this guide said to text the maintainer, and when that maintainer graduated
the app went stale for a year. An issue is visible to whoever picks this up next.

## Keeping this document true

If a step here does not work, that is a bug in this file. Fix it in the same pull request as
whatever you were doing, or open an issue. This guide used to live in a Google Doc only one
person could edit, which is how it got a year out of date. It is in the repo now so that
anyone who trips over a wrong step can correct it.
