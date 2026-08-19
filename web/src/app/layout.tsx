import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Knight Life admin',
  description: 'Publish a BB&N schedule change to the Knight Life app.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="masthead">
          <a href="/">
            <span className="mark">KL</span>
            <span>Knight Life admin</span>
          </a>
        </header>
        <main>{children}</main>
        <footer>
          <p>BB&amp;N Knight Life. Schedules published here reach the app on the students&rsquo; next launch.</p>
        </footer>
      </body>
    </html>
  );
}
