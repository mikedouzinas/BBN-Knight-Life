// Publishes a bus schedule to Firestore, where the app reads it.
//
// HQ-1042. This is how a bus time changes now. It reaches every student who already has the
// app, the next time they open it. No Xcode, no App Store review, no waiting for anyone to
// update.
//
//   node scripts/publish-bus-schedule.mjs shuttle              publish scripts/bus-schedule/shuttle.json
//   node scripts/publish-bus-schedule.mjs home                 publish scripts/bus-schedule/home.json
//   node scripts/publish-bus-schedule.mjs shuttle --dry-run    show what would go, write nothing
//   node scripts/publish-bus-schedule.mjs --read shuttle       print what is live right now
//
// Editing: open scripts/bus-schedule/<name>.json, change the times, run the command. The file
// is the source you edit; Firestore is where it lands.
//
// It refuses to publish a document with no departures in it. Blanking the schedule is
// indistinguishable from a JSON mistake, and the app's own fallback means a blank publish is
// invisible on the shuttle segment while silently removing every real time from the home one.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const HERE = dirname(fileURLToPath(import.meta.url));
const DOCS = ['shuttle', 'home'];

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const readOnly = args.includes('--read');
const name = args.find((a) => !a.startsWith('--'));

if (!name || !DOCS.includes(name)) {
  console.error(`Usage: node scripts/publish-bus-schedule.mjs <${DOCS.join('|')}> [--dry-run] [--read]`);
  process.exit(1);
}

// The same service account the rest of web/ uses. GOOGLE_APPLICATION_CREDENTIALS is a path on
// a laptop; FIREBASE_SERVICE_ACCOUNT_JSON is the same JSON inline for a host with no
// filesystem. Neither is ever committed - this repository is public.
function credentials() {
  const inline = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (inline && inline.trim()) return cert(JSON.parse(inline));
  const path = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!path) {
    console.error(
      'No credentials. Set GOOGLE_APPLICATION_CREDENTIALS to the service account JSON path,\n' +
        'or FIREBASE_SERVICE_ACCOUNT_JSON to its contents. See docs/ADMIN-TOOL.md.',
    );
    process.exit(1);
  }
  return cert(JSON.parse(readFileSync(path, 'utf8')));
}

initializeApp({ credential: credentials() });
const db = getFirestore();
const ref = db.collection('busSchedule').doc(name);

function describe(sections) {
  let departures = 0;
  for (const section of sections) {
    console.log(`  ${section.title}`);
    for (const bus of section.buses ?? []) {
      const n = (bus.times ?? []).length;
      departures += n;
      console.log(`    ${bus.title} — ${n} departure${n === 1 ? '' : 's'}`);
    }
  }
  return departures;
}

if (readOnly) {
  const snap = await ref.get();
  if (!snap.exists) {
    console.log(`busSchedule/${name} does not exist. The app is using its bundled fallback.`);
    process.exit(0);
  }
  const data = snap.data();
  console.log(`busSchedule/${name} — updatedAt ${data.updatedAt ?? '(not recorded)'}`);
  const departures = describe(data.sections ?? []);
  console.log(`CHECKED ${(data.sections ?? []).length} sections, ${departures} departures live`);
  process.exit(0);
}

const file = join(HERE, 'bus-schedule', `${name}.json`);
const parsed = JSON.parse(readFileSync(file, 'utf8'));
const sections = parsed.sections ?? [];

const departures = describe(sections);
if (departures === 0) {
  console.error(
    `\nRefusing to publish ${name}: it has no departures in it.\n` +
      'An empty publish is what a JSON mistake looks like, and on the shuttle segment the\n' +
      "app's fallback would hide it completely. If you really mean to clear this, delete the\n" +
      'document in the Firebase console instead, where it is an obvious act.',
  );
  process.exit(1);
}

if (dryRun) {
  console.log(`\nDRY RUN. ${sections.length} sections, ${departures} departures. Nothing written.`);
  process.exit(0);
}

await ref.set({ sections, updatedAt: new Date().toISOString() });
console.log(`\nCHECKED published ${sections.length} sections, ${departures} departures to busSchedule/${name}`);

// Read it back rather than trusting the write. A successful set() says the request was
// accepted, which is not the same as the document holding what you meant.
const after = await ref.get();
const live = (after.data()?.sections ?? []).reduce(
  (n, s) => n + (s.buses ?? []).reduce((m, b) => m + (b.times ?? []).length, 0),
  0,
);
if (live !== departures) {
  console.error(`FAIL: wrote ${departures} departures but read back ${live}.`);
  process.exit(1);
}
console.log(`CHECKED read back ${live} departures — they match.`);
