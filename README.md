# Knight Life

The BB&N app. Your schedule, your classes, special schedules, and the lunch menu.
About 645 people have accounts, and students open it in the morning to find out what block
it is.

Students built it. **If you want to work on it, you can.** → [How to start](docs/CONTRIBUTING.md)

---

## Post a snow day (or any schedule change)

Go to **[mikeveson.com/knight-life/admin](https://mikeveson.com/knight-life/admin)** and sign
in with your BB&N account.

Paste in whatever the school sent. An email, a photo of a printout, a PDF, or just type
*"no school Thursday, snow"*. It reads it, shows you the schedule it got, and you hit publish.
Students see it the next time they open the app.

You need permission first: someone who already has it adds you. That takes about ten seconds
and it's explained in [the full guide](docs/ADMIN-TOOL.md).

## Or just tell an AI to do it

You can hook this up to Claude and skip the form entirely. Then you just say *"no school
Thursday and Friday, snow"* and it does the rest. It always shows you what it's about to do and
waits for you to say yes.

It takes about a minute to set up.

**1. Get your key.** On [the admin page](https://mikeveson.com/knight-life/admin), scroll to
the bottom and click **Link an AI agent**. Copy what it gives you. Treat it like a password:
anything published with it says it was you.

**2. Build it.**

```bash
cd mcp
npm install
npm run build
```

**3. Hook it up.** In a terminal:

```bash
claude mcp add knight-life \
  --env KNIGHT_LIFE_REFRESH_TOKEN=paste-your-key-here \
  -- node /full/path/to/BBN-Knight-Life/mcp/dist/index.js
```

Using the Claude desktop app instead? Add this to
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "knight-life": {
      "command": "node",
      "args": ["/full/path/to/BBN-Knight-Life/mcp/dist/index.js"],
      "env": { "KNIGHT_LIFE_REFRESH_TOKEN": "paste-your-key-here" }
    }
  }
}
```

**4. Test it.** Restart Claude and ask it to run `whoami`. It should say your school email
back. If it does, you're done.

Now just talk to it. *"No school tomorrow, snow day."* Or paste the whole email from the
office. A week-long vacation comes back as one entry, not seven.

**Read the times before you say yes.** That one check is the only thing between a typo and 582
people showing up an hour early.

More detail: [mcp/README.md](mcp/README.md)

---

## Want to work on the app?

```bash
git clone https://github.com/mikedouzinas/BBN-Knight-Life.git
cd BBN-Knight-Life
pod install
open BBNDaily.xcworkspace
```

You need a Mac and Xcode. That's it.

If `pod install` fails, or Xcode complains about something, [the setup
guide](docs/CONTRIBUTING.md) has the fix. It also lists the handful of annoying environment
problems that will otherwise eat an hour of your evening.

You don't need to have built an app before, and you don't need to ask permission. Clone it,
change something, open a pull request.

## Guides

| | |
| --- | --- |
| **[Getting set up](docs/CONTRIBUTING.md)** | Xcode, pods, how the project is organised, what to work on, what to do when something breaks. **Start here.** |
| [Changing the schedule](docs/ADMIN-TOOL.md) | The admin page, adding people, vacations, and what to do when it goes wrong. |
| [Using an AI to publish](mcp/README.md) | Setup, what it can do, and what the confirm step actually protects. |
| [How the admin page works](web/README.md) | For anyone changing the tool itself. |
| [The database](docs/FIREBASE.md) | Where the schedules live, who can edit them, and the security rules. |
| [Shipping an update](docs/RELEASING.md) | Getting a new version onto the App Store. |
| [Where this is going](docs/REBUILD.md) | The plan for rebuilding the app, and why in that order. Argue with it. |

## What's in here

| | |
| --- | --- |
| `BBNDaily/` | the iOS app itself |
| `BBNDailyTests/` | its tests |
| `web/` | the admin page, a separate website |
| `mcp/` | the bit that lets an AI publish for you |
| `firebase/` | the rules for who can read and change what |
| `scripts/` | automated checks |

## Links

- [Firebase](https://console.firebase.google.com/u/0/project/bbn-daily/overview) — the database
- [App Store Connect](https://appstoreconnect.apple.com/apps/1585503654/distribution) — releases
- [The app on the App Store](https://apps.apple.com/us/app/bb-ns-knight-life/id1585503654)
