import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Constant-time comparison of an inbound webhook's HMAC-SHA256 signature
 * against the value computed from the raw body and shared secret.
 */
export function verifySignature(
  rawBody: string,
  header: string,
  secret: string,
): boolean {
  const expected = createHmac('sha256', secret).update(rawBody).digest('hex');
  const expectedBuf = Buffer.from(expected, 'utf8');
  const headerBuf = Buffer.from(header, 'utf8');

  if (expectedBuf.length !== headerBuf.length) {
    return false;
  }

  return timingSafeEqual(expectedBuf, headerBuf);
}
