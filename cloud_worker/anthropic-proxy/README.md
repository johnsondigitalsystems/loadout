# LoadOut Anthropic Proxy (Cloudflare Worker)

The thin Worker that fronts Anthropic for **AI Smart Import**. The
client (`lib/services/ai_smart_import_service.dart`) sends an OCR'd
recipe payload here; the Worker validates the caller's Firebase ID
token, checks a per-user monthly quota stored in KV, forwards the
request to Anthropic on the LoadOut secret key, and returns the
structured response.

The Worker is the **only** server-side component in the LoadOut
architecture. Everything else (recipes, firearms, brass, ballistic
profiles) lives on-device. See `CLAUDE.md` §13 / §20 for the privacy
contract this Worker has to honor.

## Privacy contract

- **No request body logging.** The Worker logs only timestamp, short
  UID prefix, status code, latency, and token counts (see
  `logEvent` in `src/index.ts`). Cloudflare's default request log
  redacts headers and bodies; we do not opt into raw-request capture.
- **No persistent storage of OCR text.** The body is forwarded to
  Anthropic and the response is returned to the client. Nothing
  about the request or response is persisted in KV.
- **Anthropic does not train on API requests.** This is part of
  Anthropic's API terms; verify before each renewal that the
  language hasn't changed.
- **Quota state is the only thing in KV.** Keys are
  `user:<uid>:smart_import:<YYYY-MM>` with a 60-day TTL.

## One-time deploy

1. Install Wrangler:

   ```sh
   npm install -g wrangler
   # or: cd cloud_worker/anthropic-proxy && npm install
   ```

2. Authenticate:

   ```sh
   wrangler login
   ```

3. **Create the KV namespace AND paste the returned ID into
   `wrangler.toml`** — this step is easy to skip and produces a
   confusing deploy failure (`KV namespace 'REPLACE_WITH_KV_NAMESPACE_ID'
   is not valid. [code: 10042]`):

   ```sh
   # Wrangler v4+ syntax (no colon)
   wrangler kv namespace create LOADOUT_QUOTAS

   # If you're on Wrangler v3 or older, the old syntax still works:
   #   wrangler kv:namespace create LOADOUT_QUOTAS
   ```

   Wrangler prints a snippet like:

   ```toml
   [[kv_namespaces]]
   binding = "LOADOUT_QUOTAS"
   id = "abcdef0123456789abcdef0123456789"
   ```

   Open `wrangler.toml` and replace the placeholder
   `id = "REPLACE_WITH_KV_NAMESPACE_ID"` (line ~36) with the real
   `id` string Wrangler just printed. Save. **You only do this
   once per environment** — the namespace persists across deploys.

   To verify after pasting:

   ```sh
   grep '^id = ' wrangler.toml   # should NOT contain "REPLACE_WITH_"
   ```

4. Set secrets (these are stored encrypted by Cloudflare; never
   commit them to the repo):

   ```sh
   wrangler secret put ANTHROPIC_API_KEY     # sk-ant-...
   wrangler secret put FIREBASE_PROJECT_ID   # 'loadout-precision-reloading'
   ```

5. Deploy:

   ```sh
   wrangler deploy
   ```

6. **(Optional, recommended) Add the RevenueCat secret API key for
   server-side entitlement verification:**

   ```sh
   # Get the key from app.revenuecat.com → Project settings → API keys
   # → "Secret API key" (NOT the public iOS/Android key — that one is
   # safe to ship in the Flutter app, the secret one is server-side
   # only).
   wrangler secret put REVENUECAT_SECRET_API_KEY
   ```

   Without this secret, the Worker trusts the Flutter client's Pro
   gate (current behavior — preserves dev / CI / pre-rollout
   operation). With it, the Worker verifies the caller's `pro`
   entitlement against RevenueCat directly — defense against a
   compromised or anonymous Firebase account trying to bypass the
   client gate and burn Anthropic spend. Verdicts are cached 5 min
   per UID in KV (`entitlement:<uid>`), and RevenueCat outages /
   non-2xx responses fall back to trust-client (don't lock everyone
   out on a transient RC issue). See `src/entitlements.ts` for the
   full state machine.

7. Wrangler will print the deployed URL. By default this is
   `https://anthropic-proxy.<account>.workers.dev`. The Flutter
   client expects `https://anthropic-proxy.loadout.workers.dev`
   (set in `lib/services/ai_smart_import_config.dart`). If yours
   differs, edit `proxyBaseUrl` to match — the client treats that
   exact host as a placeholder and won't make calls until it's
   replaced.

## Local development

```sh
cd cloud_worker/anthropic-proxy
npm install
wrangler dev
```

Wrangler starts a local server (default `http://localhost:8787`).
Point the Flutter client at it by temporarily editing
`AiSmartImportConfig.proxyBaseUrl`.

## Type-check

```sh
npx tsc --noEmit
```

CI should run this before any deploy. The Worker is a small surface
but a runtime crash would break Smart Import for every Pro user.

## Tests

```sh
npm test
```

Runs `node --test --experimental-strip-types test/*.test.ts`. Uses
Node's built-in test runner and TypeScript stripping (Node 22+) so
there's no Jest / Vitest dependency to maintain. Each test file
mocks the KV namespace and `globalThis.fetch` locally — no
miniflare / wrangler runtime is required.

CI should run `npm test` alongside `npx tsc --noEmit` before any
deploy.

## Endpoint contract

```
POST /v1/smart-import
Authorization: Bearer <firebase_id_token>
Content-Type: application/json

{
  "ocr_text": "...",
  "initial_draft": { ... },
  "catalog_hints": { ... },          // optional
  "model": "claude-sonnet-4-5"       // optional
}
```

Success (200):

```json
{
  "improved_draft": { ... },
  "fields_changed": ["powder", "powderChargeGr"],
  "quota": {
    "used_this_month": 8,
    "monthly_cap": 20,
    "resets_at": "2026-06-01T00:00:00.000Z"
  }
}
```

Quota exhausted (429):

```json
{
  "error": "Monthly limit reached.",
  "code": "quota_exceeded",
  "quota": { ... }
}
```

Auth failure (401):

```json
{ "error": "Unauthorized: <reason>" }
```

## Cost ceiling (rough)

Anthropic's Claude Sonnet 4.5 prices ~$3 / 1M input tokens and ~$15 /
1M output tokens. A typical Smart Import payload is ~2 KB in (~500
tokens) and ~1 KB out (~250 tokens). At those rates each call costs
about $0.014.

- 1,000 Pro users × 20 imports/mo × $0.014 ≈ **$280/mo worst case**.
- Realistic average usage (~3 imports/Pro/mo) ≈ **$42/mo** at the
  same user count. AI Smart Import is the fallback for messy
  handwriting; the free on-device OCR import handles most users
  without ever touching the proxy.
- Free tier of Workers + KV covers our expected request volume; the
  Anthropic spend is the line item that matters.

## Hardening backlog

- ~~**Per-user RevenueCat entitlement check**~~ — done (2026-05-08).
  When `REVENUECAT_SECRET_API_KEY` is set, every request is verified
  server-side against RevenueCat's REST API and cached 5 min per UID
  in KV. See `src/entitlements.ts` and the deploy step 6 above.
  Without the secret, the Worker still falls back to trusting the
  client (preserves dev / CI). Production deploys MUST set the
  secret.
- ~~**Region-pinning for KV**~~ — done (2026-05-08). `readQuota`
  now passes `cacheTtl: 60` so each Cloudflare PoP holds the value
  for at most a minute. KV doesn't expose strong consistency, but
  this bounds the staleness window without hurting normal-user
  latency.
- **Rate-limit beyond the monthly cap** — a single user can't exceed
  20 / month, but a botnet of compromised Firebase accounts could.
  Cloudflare's rate-limit rules in the dashboard are the right knob.
- **Custom domain** — the default `*.workers.dev` host is fine for
  v1. Bind a custom subdomain (e.g. `ai-proxy.loadout.app`) once
  the marketing domain ships.

## Troubleshooting

- **401 from every request:** the Firebase ID token isn't reaching
  the Worker, or the project ID secret is wrong. Verify with
  `wrangler tail` while issuing a known-good test.
- **429 immediately after deploy:** likely the KV namespace ID in
  `wrangler.toml` doesn't match a real namespace; reads return null,
  the `MONTHLY_CAP` check passes, but writes fail and… actually
  that would cause 502s, not 429s. If you see 429s without expected
  use, check `wrangler kv:key list` for stale counters.
- **Anthropic 401:** rotate the API key and `wrangler secret put`
  again. Old key on the Worker means every call returns
  Anthropic-401, which surfaces to the client as a generic 502.
