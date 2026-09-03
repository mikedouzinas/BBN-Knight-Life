/**
 * HQ-656's last checklist item: let an admin top up a student's schedule-scan budget.
 * The person who drops a class in November is exactly the person the yearly limit
 * will hit, and re-photographing their new schedule should not be blocked on a release.
 */
import { NextResponse } from 'next/server';
import { z } from 'zod';
import { UnauthorizedError, requireAdmin } from '@/lib/firebase/requireAdmin';
import { topUpClassSetupBudget } from '@/lib/firebase/studentBudget';

export const runtime = 'nodejs';

const bodySchema = z.object({
  uid: z.string().min(1),
  additional: z.number().int().min(1).max(50),
});

export async function POST(request: Request) {
  try {
    await requireAdmin(request);

    const parsed = bodySchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.issues.map((i) => i.message).join('; ') }, { status: 400 });
    }

    const status = await topUpClassSetupBudget(parsed.data.uid, parsed.data.additional);
    return NextResponse.json(status);
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    console.error('[student-budget]', error);
    return NextResponse.json({ error: 'Could not update that student\'s budget.' }, { status: 500 });
  }
}
