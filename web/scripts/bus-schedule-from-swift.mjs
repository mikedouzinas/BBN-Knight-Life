// Generates the seed JSON for busSchedule/* from the schedule bundled in the app.
//
// HQ-1042. The bundled Swift literals and the Firestore documents hold the same times, which
// is the N-copies problem: two places that must agree, with nothing able to see the other.
// So the JSON is never typed by hand. It is derived from BusScheduleVC.swift, which means a
// transcription error is not one of the ways this can go wrong.
//
// Usage:
//   node scripts/bus-schedule-from-swift.mjs             print the JSON
//   node scripts/bus-schedule-from-swift.mjs --snapshot  rewrite the seed from the Swift
//   node scripts/bus-schedule-from-swift.mjs --check     validate both, report any drift
//
// WHAT --check DOES AND DELIBERATELY DOES NOT DO.
//
// It first shipped comparing the two for equality and failing on any difference. That was
// wrong, and wrong in the way that matters: the entire point of HQ-1042 is that Kai edits
// shuttle.json and publishes without touching Swift, so the FIRST real use of the feature
// would have turned CI red. A guard that fires on the intended workflow does not get fixed,
// it gets deleted, and then nothing is guarding anything.
//
// The two are allowed to differ. The Swift literals are a snapshot taken at release time and
// used only when Firestore cannot be read; the JSON is what students actually get. A snapshot
// lagging the live document is the normal, correct state between releases.
//
// So --check enforces what must actually hold, and both of these can fail:
//   - the bundled Swift schedule parses and is not empty
//   - the seed JSON parses and is not empty
// and it REPORTS drift with counts, so whoever cuts a release sees how stale the fallback is
// and can run --snapshot on purpose rather than discovering it later.

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const SWIFT = join(HERE, '..', '..', 'BBNDaily', 'Tabs', 'BusScheduleVC.swift');
const SEED = join(HERE, 'bus-schedule', 'shuttle.json');

// Pull one `static let <name>: [BusSection] = [ ... ]` literal out of the file by walking
// brackets, rather than with a regex, because the literal nests three levels deep.
function extractLiteral(source, name) {
  const start = source.indexOf(`static let ${name}: [BusSection] = [`);
  if (start === -1) throw new Error(`could not find ${name} in ${SWIFT}`);
  const open = source.indexOf('[', start + `static let ${name}: [BusSection] = `.length - 1);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '[') depth++;
    else if (source[i] === ']') {
      depth--;
      if (depth === 0) return source.slice(open, i + 1);
    }
  }
  throw new Error(`unbalanced brackets in ${name}`);
}

// Every Time(...) form in the file is some subset of the same labelled arguments, so one
// pass over `label: "value"` pairs handles all eight initialisers uniformly. `nil` is
// skipped, which is why departureSpot: nil does not become a key.
function parseTime(call) {
  const time = {};
  const arg = /(\w+)\s*:\s*(?:"([^"]*)"|nil)/g;
  let m;
  while ((m = arg.exec(call)) !== null) {
    if (m[2] !== undefined) time[m[1]] = m[2];
  }
  if (!time.departure || !time.arrival) {
    throw new Error(`a Time with no departure or arrival: ${call}`);
  }
  return time;
}

function parseSections(literal) {
  const sections = [];
  // BusSection(title: "X", buses: [ ... ])
  const sectionRe = /BusSection\(title:\s*"([^"]+)",\s*buses:\s*\[/g;
  let sm;
  while ((sm = sectionRe.exec(literal)) !== null) {
    const title = sm[1];
    // Walk to the matching close bracket of this section's buses array.
    let depth = 1;
    let i = sectionRe.lastIndex;
    for (; i < literal.length && depth > 0; i++) {
      if (literal[i] === '[') depth++;
      else if (literal[i] === ']') depth--;
    }
    const busesBlock = literal.slice(sectionRe.lastIndex, i - 1);

    const buses = [];
    // `note:` is optional and sits between title and times. It MUST be part of this pattern:
    // a regex that only matched `Bus(title: ..., times: [` would skip any bus carrying a note
    // entirely, and the seed would quietly lose a whole route while still looking well-formed.
    const busRe = /Bus\(title:\s*"([^"]+)",\s*(?:note:\s*"([^"]*)",\s*)?times:\s*\[/g;
    let bm;
    while ((bm = busRe.exec(busesBlock)) !== null) {
      let d = 1;
      let j = busRe.lastIndex;
      for (; j < busesBlock.length && d > 0; j++) {
        if (busesBlock[j] === '[') d++;
        else if (busesBlock[j] === ']') d--;
      }
      const timesBlock = busesBlock.slice(busRe.lastIndex, j - 1);
      const times = [...timesBlock.matchAll(/Time\(([^)]*)\)/g)].map((t) => parseTime(t[1]));
      if (times.length === 0) throw new Error(`bus "${bm[1]}" parsed to zero times`);
      const bus = { title: bm[1], times };
      if (bm[2]) bus.note = bm[2];
      buses.push(bus);
    }
    if (buses.length === 0) throw new Error(`section "${title}" parsed to zero buses`);
    sections.push({ title, buses });
  }
  return sections;
}

const source = readFileSync(SWIFT, 'utf8');
const sections = parseSections(extractLiteral(source, 'defaultShuttleSchedule'));

const totalTimes = sections.reduce(
  (n, s) => n + s.buses.reduce((m, b) => m + b.times.length, 0),
  0,
);
if (sections.length === 0 || totalTimes === 0) {
  console.error('CHECKED 0 sections. Zero is a broken parse, not an empty schedule.');
  process.exit(1);
}

const json = JSON.stringify({ sections }, null, 2);

function countDepartures(secs) {
  return secs.reduce(
    (n, s) => n + (s.buses ?? []).reduce((m, b) => m + (b.times ?? []).length, 0),
    0,
  );
}

if (process.argv.includes('--snapshot')) {
  writeFileSync(SEED, json + '\n');
  console.log(`CHECKED wrote ${sections.length} sections, ${totalTimes} departures to ${SEED}`);
} else if (process.argv.includes('--check')) {
  console.log(`CHECKED bundled Swift schedule: ${sections.length} sections, ${totalTimes} departures`);

  let seed;
  try {
    seed = JSON.parse(readFileSync(SEED, 'utf8'));
  } catch (err) {
    console.error(`FAIL: cannot read or parse ${SEED} — ${err.message}`);
    process.exit(1);
  }
  const seedSections = seed.sections ?? [];
  const seedDepartures = countDepartures(seedSections);
  if (seedDepartures === 0) {
    console.error(
      `FAIL: ${SEED} has 0 departures in it. Zero is a broken seed, not an empty schedule.`,
    );
    process.exit(1);
  }
  console.log(`CHECKED seed JSON: ${seedSections.length} sections, ${seedDepartures} departures`);

  // Drift is reported, never fatal. See the note at the top of this file.
  if (JSON.stringify({ sections }) === JSON.stringify({ sections: seedSections })) {
    console.log('CHECKED the bundled fallback and the seed are identical.');
  } else {
    console.log(
      `NOTE: the bundled fallback and the seed differ ` +
        `(${totalTimes} vs ${seedDepartures} departures). That is expected between releases: ` +
        `the seed is what students get, the bundled copy is the offline fallback. ` +
        `Run --snapshot to refresh the fallback when cutting a release.`,
    );
  }
} else {
  console.log(json);
}
