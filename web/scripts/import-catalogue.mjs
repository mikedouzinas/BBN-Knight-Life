#!/usr/bin/env node
/**
 * Load the school's class list into Firestore.
 *
 * BB&N exports an xlsx with one row per class: id, description, block, teacher, room,
 * grading period. That file is the only place the block a class meets in and the room it
 * meets in are both written down, which is what lets a student pick their schedule from a
 * list instead of typing seven names and seven rooms from memory.
 *
 * The catalogue goes to Firestore, NOT into this repository. This repo is public and the
 * export carries every teacher's name and room number. Firestore also means Kai can
 * re-import next trimester without a deploy.
 *
 *   node scripts/import-catalogue.mjs "../../Classes as of 9.07,26.xlsx" [--year 2026-2027] [--dry]
 *
 * Re-running replaces the document, so a corrected export is a re-run and never a merge.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const args = process.argv.slice(2);
const dry = args.includes('--dry');
const yearFlag = args.indexOf('--year');
const year = yearFlag === -1 ? '2026-2027' : args[yearFlag + 1];
const source = args.find((a) => !a.startsWith('--') && a !== year);
if (!source) {
  console.error('usage: import-catalogue.mjs <path-to-xlsx> [--year 2026-2027] [--dry]');
  process.exit(2);
}

/* ---- xlsx, without a dependency -------------------------------------------
 * An xlsx is a zip of XML. Adding a spreadsheet library to a public web app to read one
 * file once a year is a worse trade than sixty lines that only handle the shape this
 * export actually has: one sheet, shared strings, no formulas.
 */
function unzip(file) {
  const buf = fs.readFileSync(file);
  const entries = new Map();
  // Walk the central directory backwards from the end-of-central-directory record.
  let eocd = buf.length - 22;
  while (eocd >= 0 && buf.readUInt32LE(eocd) !== 0x06054b50) eocd--;
  if (eocd < 0) throw new Error(`not a zip: ${file}`);
  let offset = buf.readUInt32LE(eocd + 16);
  const count = buf.readUInt16LE(eocd + 10);
  for (let i = 0; i < count; i++) {
    const nameLen = buf.readUInt16LE(offset + 28);
    const extraLen = buf.readUInt16LE(offset + 30);
    const commentLen = buf.readUInt16LE(offset + 32);
    const localOffset = buf.readUInt32LE(offset + 42);
    const name = buf.toString('utf8', offset + 46, offset + 46 + nameLen);

    const lnameLen = buf.readUInt16LE(localOffset + 26);
    const lextraLen = buf.readUInt16LE(localOffset + 28);
    const dataStart = localOffset + 30 + lnameLen + lextraLen;
    const compSize = buf.readUInt32LE(offset + 20);
    const method = buf.readUInt16LE(offset + 10);
    const raw = buf.subarray(dataStart, dataStart + compSize);
    entries.set(name, method === 0 ? raw : zlib.inflateRawSync(raw));
    offset += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

const decode = (s) =>
  s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&');

function sheetRows(entries) {
  const sharedXml = entries.get('xl/sharedStrings.xml')?.toString('utf8') ?? '';
  const shared = [...sharedXml.matchAll(/<si>([\s\S]*?)<\/si>/g)].map((m) =>
    decode([...m[1].matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)].map((t) => t[1]).join('')),
  );

  const sheetName = [...entries.keys()].find((k) => /^xl\/worksheets\/sheet1\.xml$/.test(k));
  const xml = entries.get(sheetName).toString('utf8');
  const rows = [];
  for (const rowMatch of xml.matchAll(/<row[^>]*>([\s\S]*?)<\/row>/g)) {
    const cells = [];
    // Match the cell whole, then read `t` off its opening tag separately. Folding the
    // attribute into one pattern with an optional group lets that group match empty and
    // silently returns the shared-string INDEX instead of the string, so the header row
    // reads as "0, 1, 2, 3" and every lookup fails on a column that is plainly there.
    for (const c of rowMatch[1].matchAll(/<c\b([^>]*)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
      const type = /\bt="([^"]+)"/.exec(c[1])?.[1];
      const value = c[2] === undefined ? undefined : /<v>([\s\S]*?)<\/v>/.exec(c[2])?.[1];
      if (value === undefined) {
        // An inline string carries its text directly rather than through the shared table.
        const inline = c[2] === undefined ? null : [...c[2].matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)].map((t) => t[1]).join('');
        cells.push(inline ? decode(inline) : '');
        continue;
      }
      cells.push(type === 's' ? shared[Number(value)] ?? '' : decode(value));
    }
    rows.push(cells);
  }
  return rows;
}

const rows = sheetRows(unzip(path.resolve(source)));
const header = rows[0].map((h) => h.trim());
const idx = (name) => header.findIndex((h) => h.toLowerCase() === name);
const col = { id: idx('class id'), desc: idx('description'), block: idx('block'), teacher: idx('teacher'), room: idx('room'), period: idx('grading period') };
for (const [k, v] of Object.entries(col)) {
  if (v === -1) throw new Error(`the export has no "${k}" column. Columns found: ${header.join(', ')}`);
}

/** "G-US" -> "G". Anything without a single leading letter is not a block. */
function blockLetter(raw) {
  const m = /^([A-G])\b/i.exec((raw ?? '').trim());
  return m ? m[1].toUpperCase() : null;
}

const classes = [];
const skipped = [];
for (const row of rows.slice(1)) {
  if (!row.some((c) => c && c.trim())) continue;
  const block = blockLetter(row[col.block]);
  const entry = {
    id: (row[col.id] ?? '').trim(),
    name: (row[col.desc] ?? '').trim(),
    block,
    teacher: (row[col.teacher] ?? '').trim(),
    room: (row[col.room] ?? '').trim(),
    period: (row[col.period] ?? '').trim(),
  };
  if (!entry.id || !entry.name) continue;
  // A class with no letter block (After school, and anything like it) is real but cannot
  // appear in a block picker. Keep it out rather than making up a block for it.
  if (!block) { skipped.push(entry); continue; }
  classes.push(entry);
}

classes.sort((a, b) => (a.block === b.block ? a.name.localeCompare(b.name) : a.block.localeCompare(b.block)));

const byBlock = {};
for (const c of classes) byBlock[c.block] = (byBlock[c.block] ?? 0) + 1;
console.log(`read ${classes.length} classes from ${path.basename(source)}`);
console.log('per block:', byBlock);
if (skipped.length) console.log(`skipped ${skipped.length} with no letter block:`, skipped.map((s) => s.name).join(', '));

if (dry) {
  console.log('\n--dry, nothing written. Sample:');
  console.log(JSON.stringify(classes.slice(0, 3), null, 1));
  process.exit(0);
}

/* ---- write ---------------------------------------------------------------- */
const env = {};
for (const line of fs.readFileSync(new URL('../.env.local', import.meta.url), 'utf8').split('\n')) {
  const t = line.trim();
  if (!t || t.startsWith('#') || !t.includes('=')) continue;
  const i = t.indexOf('=');
  env[t.slice(0, i).trim()] = t.slice(i + 1).trim().replace(/^["']|["']$/g, '');
}
const credential = env.FIREBASE_SERVICE_ACCOUNT_JSON
  ? JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON)
  : JSON.parse(fs.readFileSync(env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'));

const { cert, initializeApp } = await import('firebase-admin/app');
const { getFirestore } = await import('firebase-admin/firestore');
initializeApp({ credential: cert(credential) });
const db = getFirestore();

await db.doc(`catalogue/${year}`).set({
  year,
  classes,
  count: classes.length,
  source: path.basename(source),
  updatedAt: new Date().toISOString(),
});
console.log(`\nwrote catalogue/${year}: ${classes.length} classes`);
process.exit(0);
