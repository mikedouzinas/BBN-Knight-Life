/**
 * Who am I, and am I allowed in. The page calls this once after Google sign-in so the
 * answer comes from the same check the write routes use, not from a client guess.
 */
import { NextResponse } from 'next/server';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    const identity = await requireAdmin(request);
    return NextResponse.json({ email: identity.email, name: identity.name ?? null });
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    return NextResponse.json({ error: (error as Error).message }, { status: 500 });
  }
}
