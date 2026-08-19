/**
 * The HTTP client. Every call carries a Firebase ID token, which is exactly what the
 * browser sends, so `requireAdmin` on the server is unchanged and there is no second way
 * into this app. An agent is not a new kind of principal; it is a signed-in admin.
 *
 * Removing someone from the `admins` collection revokes their agent at the same instant it
 * revokes their browser, because it is the same check.
 */
import type { Config } from './config.js';

/** Refresh a little early. A token that expires mid-request reads as a mystery 401. */
const EXPIRY_MARGIN_MS = 60_000;

export class KnightLifeError extends Error {
  readonly status: number;
  constructor(message: string, status = 0) {
    super(message);
    this.name = 'KnightLifeError';
    this.status = status;
  }
}

export interface ProposedRange {
  startDate: string;
  endDate: string;
  reason: string;
  dayCount?: number;
}

export interface IngestResult {
  days: { date: string; day: unknown; display?: string; warnings?: string[] }[];
  ranges?: ProposedRange[];
  message?: string;
  rejected?: string[];
  attempts?: number;
}

export interface RangePublishResult {
  published: {
    breakKey: string;
    startDate: string;
    endDate: string;
    reason: string;
    dayCount: number;
    updatedBy: string;
    updatedAt: string;
  };
}

export interface PublishResult {
  published: {
    date: string;
    canonicalKey: string;
    legacyId: string;
    updatedBy: string;
    updatedAt: string;
  };
}

export class KnightLifeClient {
  private token: string | null = null;
  private expiresAt = 0;

  constructor(
    private readonly config: Config,
    private readonly fetchImpl: typeof fetch = fetch,
    private readonly now: () => number = Date.now,
  ) {}

  /** Trade the long-lived refresh token for a short-lived ID token, and cache it. */
  private async idToken(): Promise<string> {
    if (this.token && this.now() < this.expiresAt - EXPIRY_MARGIN_MS) return this.token;

    const response = await this.fetchImpl(
      `https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(this.config.webApiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'refresh_token',
          refresh_token: this.config.refreshToken,
        }).toString(),
      },
    );

    if (!response.ok) {
      throw new KnightLifeError(
        'That saved sign-in is no longer valid. Open the admin tool, sign in, and link the agent again.',
        response.status,
      );
    }

    const body = (await response.json()) as { id_token?: string; expires_in?: string };
    if (!body.id_token) {
      throw new KnightLifeError('Firebase returned no ID token.', 502);
    }
    this.token = body.id_token;
    this.expiresAt = this.now() + Number(body.expires_in ?? 3600) * 1000;
    return this.token;
  }

  private async call<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await this.fetchImpl(`${this.config.baseUrl}${path}`, {
      ...init,
      headers: {
        ...(init.headers ?? {}),
        Authorization: `Bearer ${await this.idToken()}`,
        ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      },
    });

    const text = await response.text();
    let body: unknown = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      // A non-JSON body means something upstream answered instead of the app: a proxy
      // error page, or a login redirect. Say that, rather than reporting a parse failure.
      throw new KnightLifeError(
        `${this.config.baseUrl}${path} did not return JSON (HTTP ${response.status}). Check KNIGHT_LIFE_URL.`,
        response.status,
      );
    }

    if (!response.ok) {
      const record = (body ?? {}) as { error?: string; issues?: string[] };
      const detail = record.issues?.length ? `${record.error} ${record.issues.join('; ')}` : record.error;
      throw new KnightLifeError(detail || `Request failed (HTTP ${response.status}).`, response.status);
    }
    return body as T;
  }

  whoami(): Promise<{ email: string; name: string | null }> {
    return this.call('/api/admin/session');
  }

  readDay(date: string): Promise<{ date: string; day: unknown; published: boolean }> {
    return this.call(`/api/admin/schedule?date=${encodeURIComponent(date)}`);
  }

  ingest(body: unknown): Promise<IngestResult> {
    return this.call('/api/admin/ingest', { method: 'POST', body: JSON.stringify(body) });
  }

  publish(date: string, day: unknown): Promise<PublishResult> {
    return this.call('/api/admin/publish', { method: 'POST', body: JSON.stringify({ date, day }) });
  }

  publishRange(range: ProposedRange): Promise<RangePublishResult> {
    return this.call('/api/admin/publish-range', {
      method: 'POST',
      body: JSON.stringify({ startDate: range.startDate, endDate: range.endDate, reason: range.reason }),
    });
  }
}
