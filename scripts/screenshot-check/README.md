# Screenshot check

Before a release goes to review, every "NOT verified" item in the PRs being shipped gets checked on screen with a screenshot. This folder holds the harness for that check. It runs the app on a simulator against the Firebase emulators, signed in as a seeded test student, and it never touches production.

## Pieces

- `firebase.json`: the Auth (9099) and Firestore (8080) emulators, loaded with the repo's `firestore.rules`.
- `seed.py`: wipes the emulators, then seeds a test student with a full schedule and planner items dated relative to today. The next school day gets a class with 3 homework and a test (Math), a class with only tests (History), and a homework with a long title (English). Overdue items, including one with a step, fill the Past section.
- `emu-patch.py <repo root>`: patches `AppDelegate.swift` so that a launch with `KL_EMU=1` points at the emulators and signs in the test student. **Apply it to a scratch copy only. Never commit it.**
- `DriverUITests.swift.txt`: a UI test that reads commands from a file (`launch`, `tap <label>`, `tapc <part of a label>`, `tapxy x y`, `type`, `swipeup`, `drag`, `wait`, `shot <name>`, `dump`, `quit`). To use it, copy it over `BBNDailyUITests/BBNDailyUITests.swift` in the scratch copy.
- `drv.sh "cmd" "cmd" ...`: sends one batch of commands to the running driver and prints its reply. `KL_DRV` sets the command folder, which must match `base` in the driver.

## Run

1. Start the emulators where Java is installed: `firebase emulators:start --project bbn-daily --config scripts/screenshot-check/firebase.json`. Hestia has no Java, so on 2026-10-23 they ran on the laptop and reached Hestia through `ssh -R 8080:127.0.0.1:8080 -R 9099:127.0.0.1:9099`.
2. `python3 scripts/screenshot-check/seed.py`
3. On the simulator machine (never the 16GB laptop), make a scratch copy of the repo, apply `emu-patch.py`, swap in the driver, and run `xcodebuild test -only-testing:BBNDailyUITests/BBNDailyUITests/testDrive` on the simulator you want.
4. Drive it: `drv.sh "launch" "wait 3" "shot home"`. Screenshots land in `$KL_DRV/shots/`.
5. Change the look with `xcrun simctl ui <device> appearance dark` and `xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large`.
