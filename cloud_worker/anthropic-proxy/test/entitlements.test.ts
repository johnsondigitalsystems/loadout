// =============================================================================
// FILE: cloud_worker/anthropic-proxy/test/entitlements.test.ts
//
// Coverage for `verifyProEntitlement`:
//   - cache hits (pro / free)
//   - missing secret → trust-client fallback
//   - live RC happy paths (active subscription, lifetime entitlement)
//   - live RC denial paths (expired, no subscription)
//   - RC error paths (4xx / 5xx, network failure) → trust-client fallback
//   - cache write happens with the documented 5-min TTL
//
// Run with:
//   node --test --experimental-strip-types test/entitlements.test.ts
//
// We run the tests directly with Node's built-in test runner against
// the source TypeScript (no separate build step). This matches the
// project's existing posture of zero-build-tooling beyond `tsc`.
//
// The KV namespace and `fetch` are mocked locally per test — no
// miniflare / wrangler runtime dependency. The Worker code only
// touches `kv.get(key, 'text')` and `kv.put(key, value, opts)` from
// the KV API surface, so the stub is small.
// =============================================================================

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { verifyProEntitlement } from '../src/entitlements.ts';

// ─── helpers ───────────────────────────────────────────────────────────────

interface KvPutCall {
  key: string;
  value: string;
  options?: { expirationTtl?: number };
}

/// Minimal in-memory KV stub. Tracks `put` calls so we can assert
/// cache writes happened with the right TTL.
function makeKv(initial: Record<string, string> = {}): {
  kv: KVNamespace;
  putCalls: KvPutCall[];
  store: Map<string, string>;
} {
  const store = new Map(Object.entries(initial));
  const putCalls: KvPutCall[] = [];
  const kv = {
    get: (async (key: string, _typeOrOpts?: unknown) => {
      return store.has(key) ? store.get(key) ?? null : null;
    }) as KVNamespace['get'],
    put: (async (
      key: string,
      value: string,
      options?: { expirationTtl?: number },
    ) => {
      store.set(key, value);
      putCalls.push({ key, value, options });
    }) as unknown as KVNamespace['put'],
  } as unknown as KVNamespace;
  return { kv, putCalls, store };
}

/// Stub a single `fetch` call. The real `fetch` is restored after the
/// test by an explicit `restore()` call (the tests do this in
/// `t.after`).
function stubFetch(
  responder: (req: Request) => Response | Promise<Response>,
): { calls: Request[]; restore: () => void } {
  const original = globalThis.fetch;
  const calls: Request[] = [];
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const req =
      input instanceof Request
        ? input
        : new Request(input as string, init);
    calls.push(req);
    return responder(req);
  }) as typeof fetch;
  return {
    calls,
    restore: () => {
      globalThis.fetch = original;
    },
  };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

// ─── cache hits ────────────────────────────────────────────────────────────

test('cached pro: returns hasPro=true, source=cache', async () => {
  const { kv } = makeKv({ 'entitlement:uid_pro': 'pro' });
  const result = await verifyProEntitlement('uid_pro', {
    REVENUECAT_SECRET_API_KEY: 'sk_real',
    LOADOUT_QUOTAS: kv,
  });
  assert.equal(result.hasPro, true);
  assert.equal(result.source, 'cache');
});

test('cached free: returns hasPro=false, source=cache', async () => {
  const { kv } = makeKv({ 'entitlement:uid_free': 'free' });
  const result = await verifyProEntitlement('uid_free', {
    REVENUECAT_SECRET_API_KEY: 'sk_real',
    LOADOUT_QUOTAS: kv,
  });
  assert.equal(result.hasPro, false);
  assert.equal(result.source, 'cache');
});

test('cache hit short-circuits: never calls fetch', async () => {
  const { kv } = makeKv({ 'entitlement:uid_pro': 'pro' });
  const fetchStub = stubFetch(() => {
    throw new Error('fetch should not be called on cache hit');
  });
  try {
    const result = await verifyProEntitlement('uid_pro', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.source, 'cache');
    assert.equal(fetchStub.calls.length, 0);
  } finally {
    fetchStub.restore();
  }
});

// ─── missing secret ────────────────────────────────────────────────────────

test('no REVENUECAT_SECRET_API_KEY: hasPro=true, source=fallback, reason=no_secret', async () => {
  const { kv, putCalls } = makeKv();
  const fetchStub = stubFetch(() => {
    throw new Error('fetch should not be called when secret is missing');
  });
  try {
    const result = await verifyProEntitlement('uid_dev', {
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'fallback');
    assert.equal(result.reason, 'no_secret');
    assert.equal(fetchStub.calls.length, 0, 'no live call when secret missing');
    assert.equal(
      putCalls.length,
      0,
      'fallback verdict must NOT be cached — production deploys would otherwise see stale "pro" for 5 min after secret is added',
    );
  } finally {
    fetchStub.restore();
  }
});

test('empty REVENUECAT_SECRET_API_KEY ("") is treated as missing', async () => {
  const { kv } = makeKv();
  const fetchStub = stubFetch(() => {
    throw new Error('fetch should not be called when secret is empty');
  });
  try {
    const result = await verifyProEntitlement('uid_x', {
      REVENUECAT_SECRET_API_KEY: '',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'fallback');
    assert.equal(result.reason, 'no_secret');
  } finally {
    fetchStub.restore();
  }
});

// ─── live RC happy paths ───────────────────────────────────────────────────

test('RC 200 with active expires_date: hasPro=true, source=live', async () => {
  const future = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const { kv, putCalls } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({
      subscriber: {
        entitlements: {
          pro: {
            expires_date: future,
          },
        },
      },
    }),
  );
  try {
    const result = await verifyProEntitlement('uid_active', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'live');
    assert.equal(result.reason, undefined);
    assert.equal(fetchStub.calls.length, 1);
    const url = new URL(fetchStub.calls[0].url);
    assert.equal(url.host, 'api.revenuecat.com');
    assert.equal(url.pathname, '/v1/subscribers/uid_active');
    assert.equal(
      fetchStub.calls[0].headers.get('authorization'),
      'Bearer sk_real',
    );
    // Cache write happened.
    assert.equal(putCalls.length, 1);
    assert.equal(putCalls[0].key, 'entitlement:uid_active');
    assert.equal(putCalls[0].value, 'pro');
    assert.equal(putCalls[0].options?.expirationTtl, 300);
  } finally {
    fetchStub.restore();
  }
});

test('RC 200 with lifetime entitlement (expires_date=null) → hasPro=true', async () => {
  const { kv, putCalls } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({
      subscriber: {
        entitlements: {
          pro: {
            // Lifetime SKU — RevenueCat reports `null` for non-expiring grants.
            expires_date: null,
          },
        },
      },
    }),
  );
  try {
    const result = await verifyProEntitlement('uid_lifetime', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'live');
    assert.equal(result.reason, undefined);
    assert.equal(putCalls[0].value, 'pro');
    assert.equal(putCalls[0].options?.expirationTtl, 300);
  } finally {
    fetchStub.restore();
  }
});

test('RC 200 with lifetime entitlement (expires_date undefined) → hasPro=true', async () => {
  // Some RC payloads omit the expires_date field entirely for lifetime
  // grants instead of returning null. Treat both as lifetime.
  const { kv } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({
      subscriber: {
        entitlements: {
          pro: {},
        },
      },
    }),
  );
  try {
    const result = await verifyProEntitlement('uid_lifetime2', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'live');
  } finally {
    fetchStub.restore();
  }
});

// ─── live RC denial paths ──────────────────────────────────────────────────

test('RC 200 with expired expires_date → hasPro=false, reason=expired', async () => {
  const past = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { kv, putCalls } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({
      subscriber: {
        entitlements: {
          pro: { expires_date: past },
        },
      },
    }),
  );
  try {
    const result = await verifyProEntitlement('uid_expired', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, false);
    assert.equal(result.source, 'live');
    assert.equal(result.reason, 'expired');
    assert.equal(putCalls[0].value, 'free');
    assert.equal(putCalls[0].options?.expirationTtl, 300);
  } finally {
    fetchStub.restore();
  }
});

test('RC 200 with no `pro` entitlement → hasPro=false, reason=no_subscription', async () => {
  const { kv, putCalls } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({
      subscriber: {
        entitlements: {},
      },
    }),
  );
  try {
    const result = await verifyProEntitlement('uid_freeuser', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, false);
    assert.equal(result.source, 'live');
    assert.equal(result.reason, 'no_subscription');
    assert.equal(putCalls[0].value, 'free');
  } finally {
    fetchStub.restore();
  }
});

test('RC 200 with no `subscriber.entitlements` field at all → reason=no_subscription', async () => {
  const { kv } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({
      subscriber: {},
    }),
  );
  try {
    const result = await verifyProEntitlement('uid_brand_new', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, false);
    assert.equal(result.reason, 'no_subscription');
  } finally {
    fetchStub.restore();
  }
});

// ─── RC error paths (graceful degradation) ─────────────────────────────────

test('RC 503 → hasPro=true, source=fallback, reason=http_503', async () => {
  // RevenueCat outage must NOT lock everyone out. Trust the client.
  const { kv, putCalls } = makeKv();
  const fetchStub = stubFetch(() => new Response('outage', { status: 503 }));
  try {
    const result = await verifyProEntitlement('uid_outage', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'fallback');
    assert.equal(result.reason, 'http_503');
    assert.equal(
      putCalls.length,
      0,
      'fallback verdict must NOT be cached on RC outage — would prolong the lockout once RC recovers',
    );
  } finally {
    fetchStub.restore();
  }
});

test('RC 401 (bad/expired secret) → hasPro=true, source=fallback, reason=http_401', async () => {
  const { kv } = makeKv();
  const fetchStub = stubFetch(() => new Response('unauthorized', { status: 401 }));
  try {
    const result = await verifyProEntitlement('uid_badsecret', {
      REVENUECAT_SECRET_API_KEY: 'sk_rotated_out',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'fallback');
    assert.equal(result.reason, 'http_401');
  } finally {
    fetchStub.restore();
  }
});

test('RC 404 (subscriber not in RC yet) → hasPro=true, source=fallback, reason=http_404', async () => {
  // Edge case: a Pro user's purchase hasn't synced to RC yet, or
  // they're using a freshly-installed client that hasn't called
  // `setAppUserID`. Don't lock them out — fall back to trust-client.
  // Once the next request lands and RC has the subscriber, we'll get
  // a 200 and cache the real verdict.
  const { kv } = makeKv();
  const fetchStub = stubFetch(() => new Response('not found', { status: 404 }));
  try {
    const result = await verifyProEntitlement('uid_notyet', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'fallback');
    assert.equal(result.reason, 'http_404');
  } finally {
    fetchStub.restore();
  }
});

test('RC fetch throws (network error) → hasPro=true, source=fallback', async () => {
  const { kv } = makeKv();
  const fetchStub = stubFetch(() => {
    throw new Error('network unreachable');
  });
  try {
    const result = await verifyProEntitlement('uid_offline', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(result.hasPro, true);
    assert.equal(result.source, 'fallback');
    assert.equal(result.reason, 'fetch_failed');
  } finally {
    fetchStub.restore();
  }
});

// ─── cache write semantics ────────────────────────────────────────────────

test('cache write uses the 300s TTL after a live check', async () => {
  const future = new Date(Date.now() + 1000 * 60 * 60).toISOString();
  const { kv, putCalls } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({
      subscriber: {
        entitlements: { pro: { expires_date: future } },
      },
    }),
  );
  try {
    await verifyProEntitlement('uid_ttl', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(putCalls.length, 1);
    assert.equal(putCalls[0].options?.expirationTtl, 300);
  } finally {
    fetchStub.restore();
  }
});

test('UID is URL-encoded in the RC request URL', async () => {
  // Firebase UIDs are typically alphanumeric so this rarely matters in
  // practice — but if a future provider returns one with a `/` we'd
  // otherwise blow the URL parser.
  const { kv } = makeKv();
  const fetchStub = stubFetch(() =>
    jsonResponse({ subscriber: { entitlements: {} } }),
  );
  try {
    await verifyProEntitlement('uid/with slash', {
      REVENUECAT_SECRET_API_KEY: 'sk_real',
      LOADOUT_QUOTAS: kv,
    });
    assert.equal(fetchStub.calls.length, 1);
    // `encodeURIComponent` encodes both `/` (%2F) and ` ` (%20).
    assert.match(fetchStub.calls[0].url, /uid%2Fwith%20slash$/);
  } finally {
    fetchStub.restore();
  }
});
