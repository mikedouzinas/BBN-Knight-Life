/**
 * Authorization, in one place, used by every route under /api/admin.
 *
 * Auth by route placement, borrowed from Cere: the real endpoints all sit under
 * /api/admin and all start with this call; the sandbox sits under /api/demo and has no
 * Firestore client at all. There is no flag anywhere that turns a demo route into a real
 * one, which is the point.
 *
 * Authorized means: a verified Google ID token, and a document at
 * `admins/{lowercase-email}`. No email is hardcoded here or anywhere else in this repo.
 */
import 'server-only';
import { adminAuth, adminDb } from './admin';

export interface AdminIdentity {
  email: string;
  uid: string;
  name?: string;
}

export class UnauthorizedError extends Error {
  readonly status: number;
  constructor(message: string, status = 401) {
    super(message);
    this.name = 'UnauthorizedError';
    this.status = status;
  }
}

export function bearerToken(request: Request): string {
  const header = request.headers.get('authorization') ?? '';
  const match = /^Bearer (.+)$/.exec(header.trim());
  if (!match) throw new UnauthorizedError('Sign in with Google first.');
  return match[1];
}

export async function isAdminEmail(email: string): Promise<boolean> {
  const snapshot = await adminDb().collection('admins').doc(email.toLowerCase()).get();
  return snapshot.exists;
}

export async function requireAdmin(request: Request): Promise<AdminIdentity> {
  // Read the token first. A request with no token is 401 whether or not the server has
  // its credentials, which keeps a misconfigured deploy from reporting 500 to someone
  // who simply was not signed in.
  const token = bearerToken(request);

  const decoded = await adminAuth()
    .verifyIdToken(token)
    .catch(() => {
      throw new UnauthorizedError('That sign-in is not valid any more. Sign in again.');
    });

  const email = decoded.email?.toLowerCase();
  if (!email) throw new UnauthorizedError('That Google account has no email address.', 403);
  if (!decoded.email_verified) throw new UnauthorizedError('That Google account is not verified.', 403);
  if (!(await isAdminEmail(email))) {
    throw new UnauthorizedError(
      `${email} is not a Knight Life admin. An existing admin adds you by creating admins/${email} in Firestore.`,
      403,
    );
  }
  return { email, uid: decoded.uid, name: decoded.name as string | undefined };
}
