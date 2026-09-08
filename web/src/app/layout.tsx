import type { Metadata } from 'next';
import { IBM_Plex_Sans, IBM_Plex_Mono } from 'next/font/google';
import Link from 'next/link';
import { withBasePath } from '@/lib/basePath';
import './globals.css';

// Plex Sans reads well at the small sizes this tool lives at. Plex Mono carries every bell
// time and block letter, because times have to line up in a column to be scannable, and
// tabular figures are the only thing that makes that happen.
const sans = IBM_Plex_Sans({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  variable: '--font-sans',
  display: 'swap',
});
const mono = IBM_Plex_Mono({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Knight Life',
  description: 'BB&N schedules, for students and for the people who publish them.',
  // metadata.icons is NOT base-path-prefixed by Next. See src/lib/basePath.ts.
  icons: { icon: withBasePath('/knight-life-icon.png') },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable}`}>
      <body>
        <header className="masthead">
          {/* next/link applies the base path; a plain <a href="/"> would leave this app
              entirely and land on the portfolio's homepage. */}
          <Link className="masthead-brand" href="/">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={withBasePath('/knight-life-icon.png')} alt="" width={34} height={34} />
            <span className="wordmark">
              Knight Life
              <span className="wordmark-sub">BB&amp;N</span>
            </span>
          </Link>
        </header>
        <main>{children}</main>
        <footer>
          {/* Deliberately not the admin warning that used to be here. This layout wraps the
              student schedule now, and 640 people do not publish anything. The warning moved
              to the admin page, next to the button it is about. */}
          <p>
            Also an{' '}
            <a href="https://apps.apple.com/us/app/bb-ns-knight-life/id1585503654">iOS app</a>. Both
            read the same schedule.
          </p>
        </footer>
      </body>
    </html>
  );
}
