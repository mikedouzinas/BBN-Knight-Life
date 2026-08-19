/**
 * Firebase Admin, server side only.
 *
 * The service account is referenced by path or by an env-injected JSON string. It is
 * never read from the repo, never logged, and never sent to the browser. This repo is
 * public; assume every committed byte is world-readable.
 */
import 'server-only';
import fs from 'node:fs';
import { cert, getApp, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getAuth, type Auth } from 'firebase-admin/auth';

const APP_NAME = 'knight-life-admin';

function credentials() {
  const inline = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (inline) return JSON.parse(inline);

  const path = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!path) {
    throw new Error(
      'No Firebase credentials. Set GOOGLE_APPLICATION_CREDENTIALS to the service account path, or FIREBASE_SERVICE_ACCOUNT_JSON to its contents.',
    );
  }
  return JSON.parse(fs.readFileSync(path, 'utf8'));
}

export function adminApp(): App {
  const existing = getApps().find((app) => app.name === APP_NAME);
  if (existing) return getApp(APP_NAME);
  return initializeApp({ credential: cert(credentials()) }, APP_NAME);
}

export function adminDb(): Firestore {
  return getFirestore(adminApp());
}

export function adminAuth(): Auth {
  return getAuth(adminApp());
}
