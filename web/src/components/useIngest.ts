'use client';

/**
 * The tool's state, with the two seams that let the same components run against the real
 * backend or against nothing at all.
 *
 * Borrowed from Cere's `useCere({ plannerUrl, applyAction })`: `ingestUrl` chooses which
 * planner reads the source, and `publishDay` replaces the write. The demo passes a
 * `publishDay` that only mutates local state, so a sandboxed run cannot reach Firestore
 * no matter what the model emits. That is what makes the public demo (HQ-613) a prop
 * rather than a fork.
 */
import { useCallback, useState } from 'react';
import type { DatedScheduleDay } from '@/lib/schedule/types';

export interface CandidateDay extends DatedScheduleDay {
  warnings: string[];
}

export interface RejectedDay {
  input: unknown;
  issues: string[];
}

export interface PublishOutcome {
  ok: boolean;
  /** What to show under the day once it is done. */
  detail?: string;
  error?: string;
}

export interface IngestRequest {
  text?: string;
  attachments?: { mediaType: string; data: string; filename?: string }[];
  hintDate?: string;
  notes?: string;
}

export interface UseIngestOpts {
  /** Planner endpoint. Defaults to the real one. */
  ingestUrl?: string;
  /**
   * Override the write. When omitted, publishing POSTs to /api/admin/publish, which is
   * the only route in the app that writes. The demo supplies a local-state version.
   */
  publishDay?: (day: DatedScheduleDay) => Promise<PublishOutcome>;
  /** How to get a Firebase ID token for the real routes. The demo needs none. */
  getToken?: () => Promise<string | null>;
}

interface State {
  days: CandidateDay[];
  rejected: RejectedDay[];
  message: string;
  reading: boolean;
  publishing: string | null;
  published: Record<string, string>;
  error: string | null;
}

const EMPTY: State = {
  days: [],
  rejected: [],
  message: '',
  reading: false,
  publishing: null,
  published: {},
  error: null,
};

async function readError(res: Response): Promise<string> {
  try {
    const data = (await res.json()) as { error?: unknown; issues?: unknown };
    const issues = Array.isArray(data.issues) ? ` (${(data.issues as string[]).join('; ')})` : '';
    if (typeof data.error === 'string' && data.error) return `${data.error}${issues}`;
  } catch {
    // fall through to the status
  }
  return `HTTP ${res.status}`;
}

export function useIngest(opts: UseIngestOpts = {}) {
  const { ingestUrl = '/api/admin/ingest', publishDay, getToken } = opts;
  const [state, setState] = useState<State>(EMPTY);

  const authHeaders = useCallback(async (): Promise<Record<string, string>> => {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    const token = getToken ? await getToken() : null;
    if (token) headers.Authorization = `Bearer ${token}`;
    return headers;
  }, [getToken]);

  const read = useCallback(
    async (request: IngestRequest) => {
      setState((s) => ({ ...s, reading: true, error: null, days: [], rejected: [], message: '' }));
      try {
        const res = await fetch(ingestUrl, {
          method: 'POST',
          headers: await authHeaders(),
          body: JSON.stringify(request),
        });
        if (!res.ok) throw new Error(await readError(res));
        const data = (await res.json()) as { days: CandidateDay[]; message: string; rejected: RejectedDay[] };
        setState((s) => ({
          ...s,
          reading: false,
          days: data.days ?? [],
          rejected: data.rejected ?? [],
          message: data.message ?? '',
        }));
      } catch (error) {
        setState((s) => ({ ...s, reading: false, error: (error as Error).message }));
      }
    },
    [ingestUrl, authHeaders],
  );

  const publish = useCallback(
    async (day: DatedScheduleDay) => {
      setState((s) => ({ ...s, publishing: day.date, error: null }));
      try {
        let outcome: PublishOutcome;
        if (publishDay) {
          outcome = await publishDay(day);
        } else {
          const res = await fetch('/api/admin/publish', {
            method: 'POST',
            headers: await authHeaders(),
            body: JSON.stringify(day),
          });
          if (!res.ok) throw new Error(await readError(res));
          const data = (await res.json()) as { published: { canonicalKey: string; legacyId: string } };
          outcome = { ok: true, detail: `Wrote schedules/special.${data.published.canonicalKey} and special-schedules/${data.published.legacyId}` };
        }
        if (!outcome.ok) throw new Error(outcome.error ?? 'The publish was refused.');
        setState((s) => ({
          ...s,
          publishing: null,
          published: { ...s.published, [day.date]: outcome.detail ?? 'Published.' },
        }));
      } catch (error) {
        setState((s) => ({ ...s, publishing: null, error: (error as Error).message }));
      }
    },
    [publishDay, authHeaders],
  );

  const discard = useCallback((date: string) => {
    setState((s) => ({ ...s, days: s.days.filter((d) => d.date !== date) }));
  }, []);

  const reset = useCallback(() => setState(EMPTY), []);

  return { ...state, read, publish, discard, reset };
}
