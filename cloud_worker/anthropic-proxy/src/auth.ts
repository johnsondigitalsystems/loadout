// =============================================================================
// FILE: cloud_worker/anthropic-proxy/src/auth.ts
//
// Verifies a Firebase ID token against the Firebase project's public
// JWKs. The Worker uses this to identify the caller before applying
// the per-user quota and forwarding to Anthropic.
//
// Why JWKs and not a Firebase Admin SDK?
//   - Cloudflare Workers don't ship a Node runtime; the Firebase Admin
//     SDK won't run there.
//   - Firebase publishes its public signing keys as a static JSON
//     document at the well-known URL below. We fetch + cache them and
//     verify the token's RS256 signature with the Web Crypto API,
//     which IS available in the Workers runtime.
//
// The verification surface is intentionally narrow: we only check what
// the project README documents — issuer, audience, expiry, signature.
// We do NOT do email-verified gating, because anonymous Firebase users
// don't have an email and they're still legitimate LoadOut callers.
// The Pro entitlement check is enforced client-side (see CLAUDE.md
// "needs hardening before scale" caveat).
//
// `verifyFirebaseIdToken(token, env)` returns the decoded payload on
// success and throws on failure. Callers translate the throw into a
// 401 response.
// =============================================================================

interface FirebaseJwk {
  kid: string;
  n: string;
  e: string;
  kty: string;
  alg: string;
  use: string;
}

const FIREBASE_JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

/// Cache the JWKs across requests so we don't refetch on every call.
/// Cloudflare Workers reuse the same isolate across requests in the
/// same region, so this cache survives long enough to matter.
let cachedJwks: { keys: FirebaseJwk[]; fetchedAt: number } | null = null;
const JWKS_TTL_MS = 60 * 60 * 1000; // 1 hour

export interface FirebaseIdTokenPayload {
  iss: string;
  aud: string;
  auth_time: number;
  user_id: string;
  sub: string;
  iat: number;
  exp: number;
  email?: string;
  email_verified?: boolean;
  firebase: {
    sign_in_provider: string;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

export class TokenVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TokenVerificationError';
  }
}

/// Pull (and cache) Firebase's current set of public signing keys.
async function getJwks(): Promise<FirebaseJwk[]> {
  const now = Date.now();
  if (cachedJwks && now - cachedJwks.fetchedAt < JWKS_TTL_MS) {
    return cachedJwks.keys;
  }
  const res = await fetch(FIREBASE_JWKS_URL);
  if (!res.ok) {
    throw new TokenVerificationError(
      `Failed to fetch Firebase JWKs: ${res.status}`,
    );
  }
  const json = (await res.json()) as { keys?: FirebaseJwk[] } | Record<string, string>;

  // Firebase actually serves these in two shapes — sometimes as
  // `{ keys: [...] }`, sometimes as `{ kid: pem-string }`. Handle
  // both. The PEM shape isn't directly importable into Web Crypto, so
  // we prefer the `{ keys }` shape and fall back to throwing if we
  // get the legacy PEM shape.
  if (json && typeof json === 'object' && 'keys' in json && Array.isArray(json.keys)) {
    cachedJwks = { keys: json.keys, fetchedAt: now };
    return json.keys;
  }
  throw new TokenVerificationError(
    'Firebase JWKs returned an unsupported format. Check the JWKS URL.',
  );
}

/// Decode a JWT into its three parts: header, payload, signature.
/// Throws if the structure is wrong; returns the raw bytes the
/// signature covers as `signedBytes`.
function decodeJwt(token: string) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new TokenVerificationError('Token is not a valid JWT.');
  }
  const [headerB64, payloadB64, signatureB64] = parts;
  const header = JSON.parse(atob(b64urlToB64(headerB64))) as {
    alg: string;
    kid: string;
    typ: string;
  };
  const payload = JSON.parse(
    atob(b64urlToB64(payloadB64)),
  ) as FirebaseIdTokenPayload;
  const signature = b64urlDecodeBytes(signatureB64);
  const signedBytes = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  return { header, payload, signature, signedBytes };
}

function b64urlToB64(s: string): string {
  return s.replace(/-/g, '+').replace(/_/g, '/');
}

function b64urlDecodeBytes(s: string): Uint8Array {
  const b64 = b64urlToB64(s);
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/// Verify a Firebase ID token against the project's JWKs. Returns the
/// decoded payload on success.
export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
): Promise<FirebaseIdTokenPayload> {
  const { header, payload, signature, signedBytes } = decodeJwt(token);

  // Algorithm check.
  if (header.alg !== 'RS256') {
    throw new TokenVerificationError(
      `Unsupported alg: ${header.alg}; expected RS256.`,
    );
  }

  // Issuer / audience checks.
  const expectedIssuer = `https://securetoken.google.com/${projectId}`;
  if (payload.iss !== expectedIssuer) {
    throw new TokenVerificationError(
      `Bad issuer: ${payload.iss}; expected ${expectedIssuer}.`,
    );
  }
  if (payload.aud !== projectId) {
    throw new TokenVerificationError(
      `Bad audience: ${payload.aud}; expected ${projectId}.`,
    );
  }

  // Expiry / iat.
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp <= now) {
    throw new TokenVerificationError('Token expired.');
  }
  if (payload.iat > now + 300) {
    // 5-minute clock skew tolerance.
    throw new TokenVerificationError('Token issued in the future.');
  }

  // sub must be present and non-empty.
  if (!payload.sub) {
    throw new TokenVerificationError('Token has no subject.');
  }

  // Find the matching JWK and verify the signature.
  const jwks = await getJwks();
  const jwk = jwks.find((k) => k.kid === header.kid);
  if (!jwk) {
    throw new TokenVerificationError(
      `No matching JWK for kid=${header.kid}.`,
    );
  }
  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    {
      kty: jwk.kty,
      n: jwk.n,
      e: jwk.e,
      alg: 'RS256',
      ext: true,
    },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    signature,
    signedBytes,
  );
  if (!valid) {
    throw new TokenVerificationError('Token signature is invalid.');
  }
  return payload;
}
