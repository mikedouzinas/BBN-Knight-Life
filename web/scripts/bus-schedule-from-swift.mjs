// Generates the seed JSON for busSchedule/* from the schedule bundled in the app.
//
// HQ-1042. The bundled Swift literals and the Firestore documents hold the same times, which
// is the N-copies problem: two places that must agree, with nothing able to see the other.
// So the JSON is never typed by hand. It is derived from BusScheduleVC.swift, which means a
// transcription error is not one of the ways this can go wrong.
//
// Usage:
//   node scripts/bus-schedule-from-swift.mjs           print the JSON
//   node scripts/bus-schedule-from-swift.mjs --check    compare against the checked-in seed
//
// --check is the drift guard: it fails when the bundled schedule and scripts/bus-schedule/
// shuttle.json disagree, so editing one and forgetting the other is caught rather than
// discovered by a student standing at a bus stop.

import { readFileSync } from 'node:fs';
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
    const busRe = /Bus\(title:\s*"([^"]+)",\s*times:\s*\[/g;
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
      buses.push({ title: bm[1], times });
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

if (process.argv.includes('--check')) {
  let onDisk;
  try {
    onDisk = readFileSync(SEED, 'utf8');
  } catch {
    console.error(`FAIL: ${SEED} does not exist. Run without --check and write it.`);
    process.exit(1);
  }
  if (onDisk.trim() !== json.trim()) {
    console.error(
      'FAIL: the bundled Swift schedule and scripts/bus-schedule/shuttle.json disagree.\n' +
        'Regenerate with: node scripts/bus-schedule-from-swift.mjs > scripts/bus-schedule/shuttle.json',
    );
    process.exit(1);
  }
  console.log(
    `CHECKED ${sections.length} sections, ${totalTimes} departures: bundled schedule matches the seed`,
  );
} else {
  console.log(json);
}
