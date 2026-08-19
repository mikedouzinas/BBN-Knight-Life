# Knight Life

The BB&N student app. Schedules, classes, special schedules, and the lunch menu, on iOS.

Built by BB&N students, and open to students who want to work on it.

## Publishing a schedule change

A snow day, a delayed start, an assembly schedule, a whole vacation.

**[mikeveson.com/knight-life/admin](https://mikeveson.com/knight-life/admin)** takes the
announcement in whatever form it arrived, as pasted text, a PDF, or a photo, shows you the day
it read, and publishes it once you say so. Sign in with your BB&N account; you need to be in
the `admins` collection.

**[Or connect your own AI agent](mcp/README.md).** The MCP server lets you publish by
describing the change, or by forwarding the email. It reads the source, shows you the days,
and cannot publish anything until you say yes. Setup is about a minute.

Everything about both, including adding and removing maintainers, is in
**[docs/ADMIN-TOOL.md](docs/ADMIN-TOOL.md)**.

## Docs

- [Contributing](docs/CONTRIBUTING.md) starts here: setup, project layout, pods, how to pick
  something up, and the environment traps that will otherwise cost you an hour.
- [Publishing schedules](docs/ADMIN-TOOL.md) covers the admin tool, adding maintainers, breaks,
  and what to do when it breaks.
- [The MCP server](mcp/README.md) covers publishing from an AI agent, and what the confirm
  step does and does not protect.
- [Firebase](docs/FIREBASE.md) covers the data, the admins collection, and the security rules.
- [Releasing](docs/RELEASING.md) covers shipping an update through App Store Connect.
- [The rebuild](docs/REBUILD.md) is the design for where this is going, and the argument for
  the order it should happen in. Disagree with it in a pull request.

## Layout

| | |
| --- | --- |
| `BBNDaily/` | the iOS app |
| `BBNDailyTests/` | its tests. `xcodebuild test` runs them; CI runs the whole target |
| `web/` | the admin tool, a Next.js app deployed separately, needing no access to the iOS project |
| `mcp/` | the MCP server, so an admin's own AI agent can publish |
| `firebase/` | Firestore and Storage security rules |
| `scripts/` | the checks CI runs |

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
