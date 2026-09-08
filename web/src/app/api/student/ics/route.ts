/**
 * The student's schedule as a downloadable .ics.
 *
 * The token arrives as a query parameter rather than an Authorization header, because a
 * calendar download is a plain navigation and a navigation carries no headers. The token is
 * a short-lived Firebase ID token (one hour), it is verified exactly as it is everywhere
 * else, and the response is not cacheable. It is not a durable credential and it is not a
 * subscription URL: this returns a file once.
 */
import { UnauthorizedError } from '@/lib/firebase/requireAdmin';
import { requireStudent } from '@/lib/firebase/requireStudent';
import { readProfile, readSchoolYear } from '@/lib/firebase/studentStore';
import { ISO_DATE_RE } from '@/lib/schedule/dates';
import { buildIcs } from '@/lib/student/ics';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/** A whole school year at most, so a bad `to` cannot ask for ten thousand days. */
const MAX_DAYS = 400;

export async function GET(request: Request) {
  const url = new URL(request.url);
  const token = url.searchParams.get('token') ?? '';

  try {
    const identity = await requireStudent(
      new Request(request.url, { headers: { authorization: `Bearer ${token}` } }),
    );

    const from = url.searchParams.get('from') ?? '';
    let to = url.searchParams.get('to') ?? '';
    if (!ISO_DATE_RE.test(from)) return json({ error: 'Pass ?from=YYYY-MM-DD.' }, 400);
    if (!ISO_DATE_RE.test(to)) {
      to = new Date(Date.parse(`${from}T00:00:00Z`) + 180 * 86_400_000).toISOString().slice(0, 10);
    }
    const span = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000;
    if (span < 0) return json({ error: '`to` is before `from`.' }, 400);
    if (span > MAX_DAYS) return json({ error: `That is more than ${MAX_DAYS} days.` }, 400);

    const [year, profile] = await Promise.all([readSchoolYear(), readProfile(identity.uid)]);
    const { text, events } = buildIcs(year, profile, {
      from,
      to,
      uidNamespace: identity.uid.slice(0, 12),
      includeUnnamedBlocks: url.searchParams.get('all') === '1',
    });

    return new Response(text, {
      headers: {
        'content-type': 'text/calendar; charset=utf-8',
        'content-disposition': 'attachment; filename="knight-life.ics"',
        'cache-control': 'no-store',
        'x-event-count': String(events),
      },
    });
  } catch (error) {
    if (error instanceof UnauthorizedError) return json({ error: error.message }, error.status);
    return json({ error: (error as Error).message }, 500);
  }
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });
}
