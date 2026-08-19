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

/**
 * The setup instructions live in the repository rather than being restated here, because
 * they change with the code and a copy on this page would go stale silently. Linked rather
 * than named: "the instructions are in mcp/README.md" tells someone a filename and leaves
 * them to go find it.
 */
const SETUP_URL = 'https://github.com/mikedouzinas/BBN-Knight-Life/blob/main/mcp/README.md#setting-it-up';

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
        filling in this page. Say &ldquo;no school Thursday and Friday, snow&rdquo;, or forward the
        email, and it reads the source and shows you the days. It cannot publish anything until you
        say yes.
      </p>
      <p className="note">
        Two steps: show your token below, then point your client at the Knight Life MCP server.{' '}
        <a href={SETUP_URL} target="_blank" rel="noreferrer">
          Setup instructions
        </a>{' '}
        take about a minute.
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
            Paste it into your MCP client as <code>KNIGHT_LIFE_REFRESH_TOKEN</code>, following the{' '}
            <a href={SETUP_URL} target="_blank" rel="noreferrer">
              setup instructions
            </a>
            . Then ask your agent to run <code>whoami</code>; it should answer with your school
            email.
          </p>
        </>
      )}
    </details>
  );
}
