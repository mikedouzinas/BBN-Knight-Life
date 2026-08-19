'use client';

/**
 * Firebase Web SDK, browser side. Google sign-in only.
 *
 * This config is public by design. Nothing here grants access: authorization is a
 * document at `admins/{lowercase-email}`, checked on the server against the same
 * collection the Firestore rules read, so the tool and the rules agree by construction.
 */
import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, signInWithPopup, signOut, type Auth } from 'firebase/auth';

function config() {
  return {
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '',
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? '',
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? '',
    appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID ?? '',
  };
}

export function firebaseConfigured(): boolean {
  const c = config();
  return Boolean(c.apiKey && c.authDomain && c.projectId && c.appId);
}

export function clientApp(): FirebaseApp {
  return getApps().length ? getApp() : initializeApp(config());
}

export function clientAuth(): Auth {
  return getAuth(clientApp());
}

export async function signInWithGoogle(): Promise<string> {
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: 'select_account' });
  const result = await signInWithPopup(clientAuth(), provider);
  return result.user.getIdToken();
}

export async function signOutOfGoogle(): Promise<void> {
  await signOut(clientAuth());
}
