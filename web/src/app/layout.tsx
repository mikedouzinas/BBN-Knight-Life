import type { Metadata } from 'next';
import { IBM_Plex_Sans, IBM_Plex_Mono } from 'next/font/google';
import Link from 'next/link';
import { asset } from '@/lib/basePath';
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
  title: 'Knight Life admin',
  description: 'Change what Knight Life shows students for a day.',
  // metadata.icons is NOT base-path-prefixed by Next. See src/lib/basePath.ts.
  icons: { icon: asset('/knight-life-icon.png') },
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
            <img src={asset('/knight-life-icon.png')} alt="" width={34} height={34} />
            <span className="wordmark">
              Knight Life
              <span className="wordmark-sub">admin</span>
            </span>
          </Link>
        </header>
        <main>{children}</main>
        <footer>
          <p>
            Schedules published here reach students on their next app launch. Check the day
            against your source before you publish it.
          </p>
        </footer>
      </body>
    </html>
  );
}
