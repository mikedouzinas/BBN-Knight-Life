'use client';

/**
 * How a maintainer connects their own AI agent, without anyone handing them a secret.
 *
 * The token below is the Firebase refresh token of the person already signed in on this
 * page. It authorizes exactly what they can already do here and nothing more, it stops
 * working the moment they are removed from the `admins` collection, and it is theirs
 * rather than a shared credential somebody has to remember to rotate when a senior leaves.
 *
 * It stays hidden until asked for, because a token sitting on screen is a token in a
 * screen-share.
 */
import { useState } from 'react';
import { clientAuth } from '@/lib/firebase/client';
import { Glow } from './Glow';

export function LinkAgent() {
  const [token, setToken] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const reveal = () => {
    const user = clientAuth().currentUser;
    setToken(user?.refreshToken ?? null);
  };

  const copy = async () => {
    if (!token) return;
    await navigator.clipboard.writeText(token);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <details className="card link-agent">
      <summary>Link an AI agent</summary>
      <p className="note">
        Connect Claude, or any MCP client, so you can publish by describing the change instead of
        filling in this page. Your agent still has to show you the schedule and get your yes before
        anything is published.
      </p>

      {token === null ? (
        <button type="button" className="secondary" onClick={reveal}>
          <Glow size={120} intensity={0.22} />
          Show my token
        </button>
      ) : (
        <>
          <p className="note">
            Treat this like a password. It signs in as you, and it stops working when you are
            removed as an admin.
          </p>
          <pre className="token">{token}</pre>
          <button type="button" className="secondary" onClick={copy}>
            <Glow size={120} intensity={0.22} />
            {copied ? 'Copied' : 'Copy token'}
          </button>
          <p className="note">
            Paste it into your MCP client as KNIGHT_LIFE_REFRESH_TOKEN. Setup instructions are in
            mcp/README.md in the Knight Life repository.
          </p>
        </>
      )}
    </details>
  );
}
