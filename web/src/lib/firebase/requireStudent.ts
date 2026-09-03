/**
 * Authorization for the one route under /api/student, mirroring requireAdmin.ts.
 *
 * Deliberately smaller: a verified Firebase ID token is the whole check. No admins
 * lookup - any signed-in student is a signed-in student. Auth by route placement, same
 * reasoning as /api/admin: this is the only thing that gates /api/student, and there is
 * no flag anywhere that widens what an admin route accepts into what this accepts.
 */
import 'server-only';
import { adminAuth } from './admin';
import { UnauthorizedError, bearerToken } from './requireAdmin';

export interface StudentIdentity {
  email: string;
  uid: string;
}

export async function requireStudent(request: Request): Promise<StudentIdentity> {
  const token = bearerToken(request);

  const decoded = await adminAuth()
    .verifyIdToken(token)
    .catch(() => {
      throw new UnauthorizedError('That sign-in is not valid any more. Sign in again.');
    });

  const email = decoded.email?.toLowerCase();
  if (!email) throw new UnauthorizedError('That Google account has no email address.', 403);
  if (!decoded.email_verified) throw new UnauthorizedError('That Google account is not verified.', 403);

  return { email, uid: decoded.uid };
}
