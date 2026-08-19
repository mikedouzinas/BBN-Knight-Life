import type { Metadata } from 'next';
import { IBM_Plex_Sans, IBM_Plex_Mono } from 'next/font/google';
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
  description: 'Publish a BB&N schedule change to the Knight Life app.',
  icons: { icon: '/knight-life-icon.png' },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable}`}>
      <body>
        <header className="masthead">
          <a className="masthead-brand" href="/">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/knight-life-icon.png" alt="" width={34} height={34} />
            <span className="wordmark">
              Knight Life
              <span className="wordmark-sub">admin</span>
            </span>
          </a>
        </header>
        <main>{children}</main>
        <footer>
          <p>
            Schedules published here reach students on their next app launch. Check the day
            against the email before you publish it.
          </p>
        </footer>
      </body>
    </html>
  );
}
