/**
 * HQ-634 item 3: whether the published school year is about to lapse. Computed server-side
 * against the server's own clock, so what the admin sees can't be skewed by their device.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';
import { adminDb } from '@/lib/firebase/admin';
import { FirestoreTermStore } from '@/lib/firebase/firestoreStore';
import { termCoverageWarning } from '@/lib/schedule/termCoverage';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    await requireAdmin(request);

    const term = await new FirestoreTermStore(adminDb()).readTerm();
    const today = new Date().toISOString().slice(0, 10);
    const warning = termCoverageWarning(term, today);

    return NextResponse.json({ warning: warning?.message ?? null });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    console.error('[term-coverage]', error);
    return NextResponse.json({ error: 'Could not check term coverage.' }, { status: 500 });
  }
}
