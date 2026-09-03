import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
if (!getApps().length) initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS!, 'utf8'))) });
const db = getFirestore();
const uid = 'CAISOSZD8MQrlipaHoUPrq0DHyN2';
const backup = process.argv[2];
const mode = process.argv[3];
const ref = db.collection('users').doc(uid);

if (mode === '--restore') {
  if (!existsSync(backup)) { console.error('no backup file'); process.exit(1); }
  await ref.set(JSON.parse(readFileSync(backup, 'utf8')));
  console.log('restored from backup');
} else {
  const snap = await ref.get();
  if (!snap.exists) { console.log('document already absent - you are already a "new user"'); process.exit(0); }
  writeFileSync(backup, JSON.stringify(snap.data(), null, 2));
  console.log(`backed up ${Object.keys(snap.data()!).length} field(s) to ${backup}`);
  await ref.delete();
  console.log('deleted users/' + uid);
}
console.log('exists now:', (await ref.get()).exists);
