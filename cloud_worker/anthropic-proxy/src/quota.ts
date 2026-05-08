// =============================================================================
// FILE: cloud_worker/anthropic-proxy/src/quota.ts
//
// Per-Pro-user-per-calendar-month counter, backed by Cloudflare KV.
//
// Why KV and not Durable Objects?
//   - KV writes are eventually consistent across regions (up to ~60s of
//     replication lag). For a "20 imports per month" quota, that's
//     plenty: even if a single user double-spent during a network blip,
//     the worst case is a couple of free extra imports — far less
//     blast radius than a real billing system would tolerate, and
//     KV's flat fee makes it cheaper than a Durable Object per user.
//   - Old months expire on their own: the key includes `YYYY-MM`, so
//     once the calendar rolls over the previous month's key is just
//     orphaned data we never read again. No GC needed.
//
// Region-pinning the read:
//   `readQuota` passes `cacheTtl: 60` so each Cloudflare PoP holds the
//   value for at most a minute. This is the practical bound — KV
//   doesn't expose a strong-consistency knob, but a 60s edge cache
//   tightens the worst case from "~60s replication lag" to "~60s
//   stale read", and writes propagate within that window. The
//   trade-off only matters in the extreme edge case of a user firing
//   20+ requests in <60s from multiple regions; for the 20-imports/
//   month cap it's effectively a no-op for normal users.
//
// Public API:
//
//   - `quotaKey(uid, monthKey)` — construct the KV key.
//   - `monthKey(now)` — produce the `YYYY-MM` slug from a Date in UTC.
//   - `monthResetAt(now)` — produce the UTC timestamp of the 1st of
//     next month, used for the "resets_at" field in responses.
//   - `readQuota(kv, uid)` — read the current value (default 0).
//   - `incrementQuota(kv, uid)` — bump the counter; returns the new
//     value.
// =============================================================================

// Lowered 30 → 20 on 2026-05-08. Reasoning: the free on-device OCR
// import path handles most users; AI Smart Import is the fallback
// for messy handwriting, not the default ingest path. 20/month is
// generous for that "I tried the OCR import on a tough page and the
// confidence was low so I clicked Improve with AI" flow.
export const MONTHLY_CAP = 20;

export function monthKey(now: Date = new Date()): string {
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

export function monthResetAt(now: Date = new Date()): string {
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  const next =
    month === 11
      ? new Date(Date.UTC(year + 1, 0, 1, 0, 0, 0))
      : new Date(Date.UTC(year, month + 1, 1, 0, 0, 0));
  return next.toISOString();
}

export function quotaKey(uid: string, monthSlug: string): string {
  return `user:${uid}:smart_import:${monthSlug}`;
}

export async function readQuota(
  kv: KVNamespace,
  uid: string,
  now: Date = new Date(),
): Promise<number> {
  const key = quotaKey(uid, monthKey(now));
  // `cacheTtl: 60` — see header comment block on region-pinning. Each
  // Cloudflare PoP caches the value for at most 60s, bounding the
  // staleness window between regions. Writes don't take a `cacheTtl`
  // option (they always propagate), so `incrementQuota` stays as-is.
  const raw = await kv.get(key, { type: 'text', cacheTtl: 60 });
  if (raw == null) return 0;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

export async function incrementQuota(
  kv: KVNamespace,
  uid: string,
  now: Date = new Date(),
): Promise<number> {
  const slug = monthKey(now);
  const key = quotaKey(uid, slug);
  const current = await readQuota(kv, uid, now);
  const next = current + 1;
  // Set with a 60-day TTL so old months expire automatically. Avoids
  // a long tail of dead keys without a separate cron job.
  await kv.put(key, String(next), { expirationTtl: 60 * 24 * 60 * 60 });
  return next;
}
