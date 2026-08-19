# Knight Life

The BB&N student app. Schedules, classes, special schedules, and the lunch menu, on iOS.

Built by BB&N students, and open to students who want to work on it.

## Docs

- [Contributing](docs/CONTRIBUTING.md) starts here: setup, project layout, pods, how to pick
  something up.
- [Firebase](docs/FIREBASE.md) covers the data, the admins collection, and the security rules.
- [Releasing](docs/RELEASING.md) covers shipping an update through App Store Connect.

## Quick start

```bash
git clone https://github.com/mikedouzinas/BBN-Knight-Life.git
cd BBN-Knight-Life
pod install
open BBNDaily.xcworkspace
```

This repo does not vendor `Pods/`. `Podfile.lock` pins every dependency to an exact version
and checksum, so `pod install` reproduces the tree exactly, and it is required on a fresh
clone.

See [Contributing](docs/CONTRIBUTING.md) if any of that does not work.
