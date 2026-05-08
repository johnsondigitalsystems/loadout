// =============================================================================
// FILE: cloud_worker/anthropic-proxy/src/entitlements.ts
//
// Server-side verification of a caller's RevenueCat `pro` entitlement,
// keyed by Firebase UID. The Flutter client links the two via
// `Purchases.setAppUserID(firebaseUid)` (see CLAUDE.md "Linking
// RevenueCat to Firebase Auth"), so RevenueCat maintains a customer
// record we can query directly.
//
// Why not just trust the client?
//   The client-side `ensurePro` gate is enough for casual users, but a
//   malicious actor with ANY signed-in Firebase ID token (including a
//   fresh anonymous account) could bypass the Flutter gate and burn
//   the LoadOut-owned Anthropic API budget. Verifying entitlement
//   server-side is the cheapest defense — one HTTP call to RevenueCat
//   per uncached request.
//
// Caching strategy:
//   - 5-minute KV cache per UID (`entitlement:<uid>`).
//   - At the 20-imports/month cap, the cache cuts RevenueCat API
//     traffic by an order of magnitude — most retries / rapid-fire
//     requests inside a single session hit the cache.
//   - 5 minutes is short enough that a cancellation lands quickly
//     (worst case: one extra Smart Import after canceling Pro), but
//     long enough to amortize across a typical session.
//
// Failure mode:
//   - **No `REVENUECAT_SECRET_API_KEY` configured** → fall back to
//     trust-client (current behavior). Lets dev/CI/operators-without-
//     secret-yet keep working. Production deploys MUST set the secret.
//   - **RevenueCat returns a non-2xx status** → fall back to
//     trust-client and log loudly. A 5-minute RC outage shouldn't
//     lock every Pro user out of AI Smart Import.
//   - **RevenueCat returns 2xx but no `pro` entitlement** → return
//     `hasPro=false`. This is the only path that denies the request.
//
// We deliberately do NOT cache RC failures as "free" — that would
// turn a transient outage into a multi-minute Pro lockout for every
// user.
// =============================================================================

export interface EntitlementResult {
  hasPro: boolean;
  /// Where the verdict came from. Useful for telemetry / debugging
  /// without exposing the underlying API response.
  source: 'cache' | 'live' | 'fallback';
  /// Optional refinement of `hasPro=false` or `source=fallback`. One of:
  ///   'expired'         — RC returned an entitlement whose expires_date is in the past.
  ///   'no_subscription' — RC returned a subscriber record with no `pro` entitlement.
  ///   'no_secret'       — REVENUECAT_SECRET_API_KEY is not configured.
  ///   'http_<code>'     — RC returned a non-2xx status (e.g. 'http_503').
  reason?: string;
}

interface RevenueCatEnv {
  REVENUECAT_SECRET_API_KEY?: string;
  LOADOUT_QUOTAS: KVNamespace;
}

/// 5 minutes. See header comment for trade-off rationale.
const ENTITLEMENT_CACHE_TTL_SECONDS = 300;

function cacheKey(uid: string): string {
  return `entitlement:${uid}`;
}

/// Verify a Firebase UID has the active `pro` entitlement in
/// RevenueCat. Returns a structured result so callers can log the
/// `source` for observability and decide whether to short-circuit.
export async function verifyProEntitlement(
  uid: string,
  env: RevenueCatEnv,
): Promise<EntitlementResult> {
  // 1. Cache hit?
  const cached = await env.LOADOUT_QUOTAS.get(cacheKey(uid), 'text');
  if (cached === 'pro') {
    return { hasPro: true, source: 'cache' };
  }
  if (cached === 'free') {
    return { hasPro: false, source: 'cache' };
  }

  // 2. No secret? Fall back to trust-client (current behavior). This
  //    keeps dev / CI / pre-rollout operators working. Production
  //    deploys MUST set the secret for the entitlement check to take
  //    effect — log it so the absence is obvious in `wrangler tail`.
  if (!env.REVENUECAT_SECRET_API_KEY) {
    console.log(
      'verifyProEntitlement: no REVENUECAT_SECRET_API_KEY; trusting client',
    );
    return { hasPro: true, source: 'fallback', reason: 'no_secret' };
  }

  // 3. Live RevenueCat check.
  let resp: Response;
  try {
    resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      {
        headers: {
          'Authorization': `Bearer ${env.REVENUECAT_SECRET_API_KEY}`,
          'X-Platform': 'cloudflare-worker',
        },
      },
    );
  } catch (e) {
    // Network-level failure (DNS, TLS, abort). Treat the same as a
    // 5xx — graceful degradation, log loudly, do NOT cache.
    const msg = e instanceof Error ? e.message : 'unknown';
    console.error(`RevenueCat fetch failed: ${msg}`);
    return { hasPro: true, source: 'fallback', reason: 'fetch_failed' };
  }

  if (!resp.ok) {
    // RevenueCat outage / API error → fall back to trusting the
    // client. Don't cache — a 5-minute outage would lock everyone out.
    console.error(`RevenueCat API error: ${resp.status}`);
    return { hasPro: true, source: 'fallback', reason: `http_${resp.status}` };
  }

  const body = (await resp.json()) as {
    subscriber?: {
      entitlements?: {
        pro?: {
          expires_date?: string | null;
        };
      };
    };
  };
  const entitlement = body?.subscriber?.entitlements?.pro;
  const proExpires = entitlement?.expires_date;

  let hasPro = false;
  let reason: string | undefined;

  if (!entitlement) {
    // No `pro` entitlement at all — user has never purchased, or
    // their subscription was fully removed by RC.
    reason = 'no_subscription';
  } else if (proExpires === null || proExpires === undefined) {
    // Lifetime entitlement: RevenueCat reports `expires_date: null`
    // for non-expiring grants (the `loadout_pro_lifetime` SKU). The
    // entitlement object is present, just without an expiry.
    hasPro = true;
  } else {
    const expiresMs = new Date(proExpires).getTime();
    if (Number.isFinite(expiresMs) && expiresMs > Date.now()) {
      hasPro = true;
    } else {
      reason = 'expired';
    }
  }

  // 4. Cache the verdict. 5-min TTL — see header comment.
  await env.LOADOUT_QUOTAS.put(cacheKey(uid), hasPro ? 'pro' : 'free', {
    expirationTtl: ENTITLEMENT_CACHE_TTL_SECONDS,
  });

  return { hasPro, source: 'live', reason };
}
