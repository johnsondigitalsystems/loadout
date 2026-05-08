// =============================================================================
// FILE: cloud_worker/anthropic-proxy/src/index.ts
//
// Cloudflare Worker entrypoint for the LoadOut AI Smart Import proxy.
// One endpoint:
//
//   POST /v1/smart-import
//
// Pipeline:
//   1. Verify the `Authorization: Bearer <firebase_id_token>` header
//      against the Firebase project's public JWKs.
//   2. Read the per-user monthly counter from KV. If at cap, return
//      429 with the current quota state so the client can render a
//      "you've used 30 / 30 this month" UI.
//   3. Increment the counter (we count attempts, not just successes —
//      this keeps quota arithmetic simple and prevents abuse via
//      malformed-on-purpose requests).
//   4. Forward to Anthropic with the secret API key.
//   5. Return the structured response shape.
//
// Logging policy: never log request bodies. Only telemetry
// (timestamp, uid, status, latency, token count) goes to
// `console.log`. Cloudflare Workers send those to the dashboard's
// real-time logs by default.
// =============================================================================

import { TokenVerificationError, verifyFirebaseIdToken } from './auth';
import { verifyProEntitlement } from './entitlements';
import {
  MONTHLY_CAP,
  monthResetAt,
  readQuota,
  incrementQuota,
} from './quota';
import { AnthropicError, callAnthropic, diffFields } from './proxy';

/// Workers Rate Limiting binding shape. The runtime exposes `.limit({key})`
/// returning `{success: boolean}`. Cloudflare may add fields here over time;
/// we only consume `success`.
interface RateLimit {
  limit(opts: { key: string }): Promise<{ success: boolean }>;
}

interface Env {
  ANTHROPIC_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
  /// Optional. When set, the Worker verifies the caller's `pro`
  /// entitlement against RevenueCat's REST API before forwarding to
  /// Anthropic. When unset, the Worker falls back to trusting the
  /// Flutter client's `ensurePro` gate (current behavior). See
  /// `entitlements.ts` for the trade-off and `README.md` for the
  /// `wrangler secret put` operator step.
  REVENUECAT_SECRET_API_KEY?: string;
  LOADOUT_QUOTAS: KVNamespace;

  /// Workers Rate Limiting bindings — declared in `wrangler.toml` under
  /// `[[unsafe.bindings]]`. The traditional dashboard "Rate Limits"
  /// feature requires a customer zone (custom domain); workers.dev
  /// URLs aren't a customer zone, so the only way to rate-limit a
  /// Worker on workers.dev is via these bindings + `.limit({key})`
  /// calls in code. Each is an independent counter scoped by the
  /// `key` we pass in.
  ///
  ///   PER_IP_LIMITER       — 30 req/min per source IP
  ///   PER_TOKEN_LIMITER    — 5 req/min per Authorization header value
  ///   ACCOUNT_LIMITER      — 1000 req/min total across the Worker
  ///
  /// All optional at the type level so the Worker still runs (with no
  /// rate limiting) if the bindings are removed from `wrangler.toml`
  /// during a future config experiment.
  PER_IP_LIMITER?: RateLimit;
  PER_TOKEN_LIMITER?: RateLimit;
  ACCOUNT_LIMITER?: RateLimit;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const startedAt = Date.now();
    const url = new URL(request.url);

    // CORS preflight for any browser-side direct calls (we don't
    // actually use them — the Flutter web build talks via the same
    // package:http client — but it's cheap to support).
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    if (url.pathname !== '/v1/smart-import') {
      return jsonResponse({ error: 'Not found.' }, 404);
    }
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed.' }, 405);
    }

    // ─────────────── rate limiting ───────────────
    // Run BEFORE auth / entitlement / quota so attackers can't burn
    // Worker CPU (and our Anthropic budget through any future code
    // path that bypasses the cap) by hammering the endpoint with
    // unauthenticated requests. Three layers, evaluated in order from
    // cheapest to broadest:
    //
    //   1. Per-IP — single attacker from one machine
    //   2. Per-token — stolen Firebase ID token across many machines
    //   3. Account-wide — anything that sneaks past the keyed rules
    //
    // Each rule's parameters are documented in `wrangler.toml`'s
    // `[[unsafe.bindings]]` blocks. If any binding is missing (e.g.
    // `wrangler.toml` was edited to remove rate limiting for a debug
    // session), that specific rule is skipped — defense degrades
    // gracefully rather than failing closed.
    //
    // We return 429 with a `Retry-After: 60` hint so well-behaved
    // clients pause for a minute. The current minute's bucket clears
    // at the next minute boundary, not 60 seconds after the violating
    // request — Workers Rate Limiting uses a sliding window — but the
    // header is still a useful courtesy.
    const clientIp =
      request.headers.get('cf-connecting-ip') ??
      request.headers.get('x-forwarded-for') ??
      'unknown';
    if (env.PER_IP_LIMITER) {
      const { success } = await env.PER_IP_LIMITER.limit({ key: clientIp });
      if (!success) {
        logEvent(uid_unknown(), 429, Date.now() - startedAt, 0, 0);
        return jsonResponse(
          { error: 'Too many requests from this IP.', code: 'rate_limit_ip' },
          429,
          { 'Retry-After': '60' },
        );
      }
    }
    const tokenForLimit = request.headers.get('authorization') ?? '';
    if (env.PER_TOKEN_LIMITER && tokenForLimit) {
      const { success } = await env.PER_TOKEN_LIMITER.limit({
        key: tokenForLimit,
      });
      if (!success) {
        logEvent(uid_unknown(), 429, Date.now() - startedAt, 0, 0);
        return jsonResponse(
          {
            error: 'Too many requests for this account.',
            code: 'rate_limit_token',
          },
          429,
          { 'Retry-After': '60' },
        );
      }
    }
    if (env.ACCOUNT_LIMITER) {
      // Constant key — counts ALL requests Worker-wide.
      const { success } = await env.ACCOUNT_LIMITER.limit({ key: 'global' });
      if (!success) {
        logEvent(uid_unknown(), 429, Date.now() - startedAt, 0, 0);
        return jsonResponse(
          {
            error: 'Service is currently rate-limited.',
            code: 'rate_limit_account',
          },
          429,
          { 'Retry-After': '60' },
        );
      }
    }

    // ─────────────── auth ───────────────
    const authHeader = request.headers.get('authorization') ?? '';
    const match = /^Bearer\s+(.+)$/i.exec(authHeader);
    if (!match) {
      return jsonResponse(
        { error: 'Missing Authorization header.' },
        401,
      );
    }
    const token = match[1].trim();
    let uid: string;
    try {
      const payload = await verifyFirebaseIdToken(
        token,
        env.FIREBASE_PROJECT_ID,
      );
      uid = payload.sub;
    } catch (e) {
      const msg = e instanceof TokenVerificationError ? e.message : 'auth failed';
      logEvent(uid_unknown(), 401, Date.now() - startedAt, 0, 0);
      return jsonResponse({ error: `Unauthorized: ${msg}` }, 401);
    }

    // ─────────────── Pro entitlement check ───────────────
    // Defense against compromised Firebase accounts: a bare signed-in
    // token (any user, including freshly-minted anonymous) shouldn't
    // be enough to burn the LoadOut-owned Anthropic budget. When the
    // RevenueCat secret is configured, we verify the `pro` entitlement
    // server-side. When it isn't, we fall back to trusting the
    // client (current behavior — preserves dev / CI / pre-rollout
    // operation). Errors talking to RevenueCat are NOT cached and
    // also fall back to trust-client (a 5-minute RC outage shouldn't
    // lock everyone out).
    const ent = await verifyProEntitlement(uid, env);
    // Short UID prefix only — same redaction as `logEvent`.
    const shortUid = uid.length > 6 ? `${uid.slice(0, 6)}..` : uid;
    console.log(
      `verifyProEntitlement uid=${shortUid} hasPro=${ent.hasPro} source=${ent.source}${ent.reason ? ` reason=${ent.reason}` : ''}`,
    );
    if (!ent.hasPro) {
      logEvent(uid, 403, Date.now() - startedAt, 0, 0);
      return jsonResponse(
        {
          error: 'Pro entitlement required.',
          code: 'pro_required',
          reason: ent.reason,
        },
        403,
      );
    }

    // ─────────────── quota check ───────────────
    const used = await readQuota(env.LOADOUT_QUOTAS, uid);
    if (used >= MONTHLY_CAP) {
      logEvent(uid, 429, Date.now() - startedAt, 0, 0);
      return jsonResponse(
        {
          error: 'Monthly limit reached.',
          code: 'quota_exceeded',
          quota: {
            used_this_month: used,
            monthly_cap: MONTHLY_CAP,
            resets_at: monthResetAt(),
          },
        },
        429,
      );
    }

    // ─────────────── parse body ───────────────
    let body: Record<string, unknown>;
    try {
      body = (await request.json()) as Record<string, unknown>;
    } catch {
      logEvent(uid, 400, Date.now() - startedAt, 0, 0);
      return jsonResponse({ error: 'Body is not valid JSON.' }, 400);
    }
    if (typeof body.ocr_text !== 'string' || body.ocr_text.trim().length === 0) {
      logEvent(uid, 400, Date.now() - startedAt, 0, 0);
      return jsonResponse({ error: 'ocr_text is required.' }, 400);
    }
    const initialDraft = (body.initial_draft as Record<string, unknown>) ?? {};
    const catalogHints = (body.catalog_hints as Record<string, unknown>) ?? undefined;
    const model = typeof body.model === 'string' ? body.model : undefined;

    // ─────────────── increment + call ───────────────
    // We count the attempt FIRST so a runaway client can't burn
    // unlimited Anthropic spend. The counter ratchets even if the
    // Anthropic call fails.
    const newUsed = await incrementQuota(env.LOADOUT_QUOTAS, uid);

    try {
      const result = await callAnthropic(
        {
          ocr_text: body.ocr_text,
          initial_draft: initialDraft,
          catalog_hints: catalogHints,
          model,
        },
        env.ANTHROPIC_API_KEY,
      );

      const fieldsChanged = diffFields(initialDraft, result.improved);
      logEvent(
        uid,
        200,
        Date.now() - startedAt,
        result.inputTokens,
        result.outputTokens,
      );
      return jsonResponse({
        improved_draft: result.improved,
        fields_changed: fieldsChanged,
        quota: {
          used_this_month: newUsed,
          monthly_cap: MONTHLY_CAP,
          resets_at: monthResetAt(),
        },
      });
    } catch (e) {
      const status = e instanceof AnthropicError ? e.status : 502;
      const msg = e instanceof Error ? e.message : 'Anthropic error.';
      logEvent(uid, status, Date.now() - startedAt, 0, 0);
      return jsonResponse(
        {
          error: msg,
          quota: {
            used_this_month: newUsed,
            monthly_cap: MONTHLY_CAP,
            resets_at: monthResetAt(),
          },
        },
        status,
      );
    }
  },
};

function corsHeaders(): Record<string, string> {
  return {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'authorization, content-type',
    'access-control-max-age': '86400',
  };
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  /// Extra headers merged on top of the defaults. Used by the
  /// rate-limit branches to set `Retry-After`. Caller-supplied keys
  /// win over the defaults — same precedence as a regular spread.
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json',
      ...corsHeaders(),
      ...extraHeaders,
    },
  });
}

function uid_unknown(): string {
  return 'unknown';
}

/// Telemetry-only log line. Deliberately no body content. The
/// Cloudflare dashboard's real-time logs surface these.
function logEvent(
  uid: string,
  status: number,
  latencyMs: number,
  inputTokens: number,
  outputTokens: number,
): void {
  // Use the 12-character prefix of the UID so logs are still useful
  // for debugging without exposing the full anonymous identifier.
  const shortUid = uid.length > 12 ? uid.slice(0, 12) + '…' : uid;
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      uid: shortUid,
      status,
      latency_ms: latencyMs,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
    }),
  );
}
