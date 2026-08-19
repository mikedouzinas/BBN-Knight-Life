'use client';

/**
 * The real tool. Auth is by route placement: everything this page calls lives under
 * /api/admin, and every one of those handlers starts with `requireAdmin`. There is no
 * flag on this page that turns the writes off, and none on the demo page that turns
 * them on.
 */
import { useCallback, useEffect, useState } from 'react';
import { IngestTool } from '@/components/IngestTool';
import { LinkAgent } from '@/components/LinkAgent';
import { clientAuth, firebaseConfigured, signInWithGoogle, signOutOfGoogle } from '@/lib/firebase/client';
import { withBasePath } from '@/lib/basePath';

type Status =
  | { kind: 'loading' }
  | { kind: 'unconfigured' }
  | { kind: 'signed-out' }
  | { kind: 'denied'; message: string }
  | { kind: 'admin'; email: string };

export default function AdminPage() {
  const [status, setStatus] = useState<Status>({ kind: 'loading' });

  const getToken = useCallback(async () => {
    const user = clientAuth().currentUser;
    return user ? user.getIdToken() : null;
  }, []);

  const check = useCallback(async () => {
    const token = await getToken();
    if (!token) {
      setStatus({ kind: 'signed-out' });
      return;
    }
    const res = await fetch(withBasePath('/api/admin/session'), { headers: { Authorization: `Bearer ${token}` } });
    const data = (await res.json().catch(() => ({}))) as { email?: string; error?: string };
    if (res.ok && data.email) setStatus({ kind: 'admin', email: data.email });
    else setStatus({ kind: 'denied', message: data.error ?? `HTTP ${res.status}` });
  }, [getToken]);

  useEffect(() => {
    if (!firebaseConfigured()) {
      setStatus({ kind: 'unconfigured' });
      return;
    }
    return clientAuth().onAuthStateChanged(() => {
      void check();
    });
  }, [check]);

  if (status.kind === 'unconfigured') {
    return (
      <div className="card">
        <h1>Not configured</h1>
        <p>
          The NEXT_PUBLIC_FIREBASE_* variables are not set, so there is nothing to sign in to. Copy
          web/.env.local.example to web/.env.local and fill it in.
        </p>
      </div>
    );
  }

  if (status.kind === 'loading') return <p className="card note">Checking your account...</p>;

  if (status.kind !== 'admin') {
    return (
      <div className="card">
        <h1>Sign in</h1>
        <p className="note">Use your BB&N account (name@bbns.org).</p>
        {status.kind === 'denied' && <p className="error">{status.message}</p>}
        <div className="signin">
          <button type="button" className="primary" onClick={() => signInWithGoogle().then(check)}>
            Sign in with your BB&N Google account
          </button>
          {status.kind === 'denied' && (
            <button type="button" className="secondary" onClick={() => signOutOfGoogle().then(check)}>
              Use a different account
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <>
      <h1>Publish a schedule</h1>
      <div className="signin card">
        <span className="who">Signed in as {status.email}</span>
        <button type="button" className="link" onClick={() => signOutOfGoogle().then(check)}>
          Sign out
        </button>
      </div>
      <IngestTool options={{ getToken }} />
      <LinkAgent />
    </>
  );
}
