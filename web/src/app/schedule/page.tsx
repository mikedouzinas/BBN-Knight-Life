/**
 * The student-facing schedule viewer, at /knight-life/schedule.
 *
 * Its own page rather than the root, because the root is the admin tool's front door and
 * that tool is still the reason this deployment exists. Two audiences, two pages, one
 * deployment and one data layer.
 */
import Link from 'next/link';
import { StudentApp } from '@/components/student/StudentApp';

export const metadata = {
  title: 'Your schedule · Knight Life',
  description: 'Your BB&N schedule, on any screen.',
};

export default function SchedulePage() {
  return (
    <>
      <h1>Your schedule</h1>
      <StudentApp />
      <p className="note admin-link">
        Maintainer? <Link href="/admin">The schedule admin tool</Link> is over here.
      </p>
    </>
  );
}
