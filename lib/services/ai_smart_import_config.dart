// FILE: lib/services/ai_smart_import_config.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Configuration constants for the **AI Smart Import** feature — the
// scoped Pro-gated capability that takes raw OCR'd text from the photo-
// import flow and lets a hosted Anthropic-backed proxy (or the user's
// own Anthropic key) tighten up a low-confidence parse.
//
// What lives here:
//
//   - `proxyBaseUrl` — base URL of the Cloudflare Worker that fronts
//     Anthropic for hosted-mode Smart Import requests. Defaults to the
//     placeholder `https://anthropic-proxy.loadout.workers.dev`. The
//     operator deploys the Worker at `cloud_worker/anthropic-proxy/`
//     and either keeps this default subdomain or edits this constant
//     to match their deployment.
//   - `smartImportPath` — path appended to [proxyBaseUrl] for the
//     actual Smart Import endpoint (`/v1/smart-import`).
//   - `byokSecureStorageKey` — the [FlutterSecureStorage] key under
//     which the user's own Anthropic API key is cached when BYOK is
//     enabled. We deliberately use the OS-backed Keychain / Keystore
//     so the key never touches `SharedPreferences` or the on-device
//     SQLite database.
//   - `defaultModel` — Claude model identifier the proxy and BYOK
//     paths both ask for.
//   - `monthlyCap` — soft per-Pro-user-per-calendar-month quota the
//     Worker enforces. The client mirrors this number for usage UI.
//   - `byokTestTokens` — the `max_tokens` value used for the "Test
//     connection" button in BYOK mode so the cost of a sanity check
//     stays in the single-digit-cents range.
//   - `requestTimeout` — wall-clock timeout for any single Smart
//     Import call.
//   - `isPlaceholder` — getter returning true while [proxyBaseUrl]
//     still points at the default placeholder host. While true, the
//     hosted mode short-circuits with a "AI Smart Import is being
//     set up" status so dev / CI builds don't accidentally hit a
//     production endpoint.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// AI Smart Import is intentionally narrower than AI Chat. It only ever
// reads OCR text the user just produced and returns a structured
// `RecipeDraft` patch. Splitting its config into its own file keeps it
// from being entangled with `AiProxyConfig` (which fronts the AI Chat
// proxy on a different endpoint shape) and lets the AI Chat surface
// stay in its existing "Coming Soon" state without any of these
// constants leaking in.
//
// The Cloudflare Worker the URL points at applies a Pro-only monthly
// cap server-side and is the only place the LoadOut Anthropic key
// lives. BYOK mode bypasses the proxy entirely — a user's own key
// goes straight to `api.anthropic.com` and the Worker is never
// involved. See `lib/services/ai_smart_import_service.dart` for the
// mode-selection logic.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Not particularly tricky — pure constants. The non-obvious bit is
// the [isPlaceholder] indirection: the `loadout.workers.dev` default
// subdomain is real Cloudflare-owned territory but is treated as a
// placeholder until an operator confirms the Worker is deployed. To
// signal "deployed", the operator either flips this constant to a
// custom domain or replaces the default explicitly. This avoids
// silently hitting a Worker that may or may not exist.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/services/ai_smart_import_service.dart` — reads every constant
//   to decide hosted vs BYOK and to build outbound requests.
// - `lib/screens/settings/ai_settings_screen.dart` — reads
//   [byokSecureStorageKey] and [monthlyCap] for the BYOK UI and the
//   usage display.
// - `cloud_worker/anthropic-proxy/` — the README documents the same
//   default URL so the operator can keep them in sync.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure compile-time constants.

/// Configuration for AI Smart Import — the scoped Pro feature that
/// improves a low-confidence `RecipeDraft` by sending the OCR'd text
/// either through LoadOut's Cloudflare Worker proxy (hosted mode) or
/// straight to Anthropic on the user's own key (BYOK mode).
class AiSmartImportConfig {
  /// Base URL of the LoadOut-operated Cloudflare Worker that fronts
  /// Anthropic for hosted-mode Smart Import. Default points at the
  /// `loadout.workers.dev` subdomain produced by `wrangler deploy`.
  /// Until the operator deploys the Worker, [isPlaceholder] returns
  /// true and the service routes accordingly.
  // Live as of 2026-05-08. `loadout-precision-reloading` is the
  // account-wide workers.dev subdomain (renamed from the auto-assigned
  // `holy-breeze-9fa5` to match our brand and Firebase project ID).
  //
  // Renaming the workers.dev subdomain in the Cloudflare dashboard is
  // an account-level operation that takes effect immediately; the old
  // host stops resolving the moment the new one goes live. To rename
  // again later: Cloudflare dashboard → Compute → Workers & Pages →
  // Settings → Subdomain → edit. Then update this constant + the
  // `isPlaceholder` check below in lockstep, rebuild the Flutter app,
  // and ship a new release before existing TestFlight / Play Store
  // installs hit the old URL.
  static const String proxyBaseUrl =
      'https://anthropic-proxy.loadout-precision-reloading.workers.dev';

  /// Path appended to [proxyBaseUrl] for the smart-import endpoint.
  static const String smartImportPath = '/v1/smart-import';

  /// Secure-storage key under which the user's own Anthropic API key
  /// is cached when they enable BYOK. Used as the secure-storage key
  /// across iOS Keychain and Android Keystore.
  static const String byokSecureStorageKey = 'byok_anthropic_key';

  /// Default Claude model. The Worker is allowed to override this
  /// server-side; BYOK mode uses it verbatim.
  static const String defaultModel = 'claude-sonnet-4-5';

  /// Soft cap the Cloudflare Worker enforces on hosted-mode requests
  /// per Pro user per calendar month. Mirrored client-side for
  /// usage UI in Settings → AI. Must equal `MONTHLY_CAP` in
  /// `cloud_worker/anthropic-proxy/src/quota.ts` — keep them in sync
  /// when changing.
  ///
  /// Lowered 30 → 20 on 2026-05-08. Free on-device OCR import covers
  /// most users; AI Smart Import is the fallback for messy
  /// handwriting on a tough page, not the default ingest path.
  static const int monthlyCap = 20;

  /// `max_tokens` used by the BYOK "Test connection" button. Kept
  /// tiny so the user's account is barely charged for the sanity
  /// check.
  static const int byokTestTokens = 5;

  /// Wall-clock timeout for a single Smart Import call (proxy or
  /// BYOK). The model itself is fast on this payload (~2 KB in,
  /// ~1 KB out) so a 30-second cap is generous.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Whether the proxy URL still points at a not-yet-deployed Worker
  /// host. While true, hosted-mode calls fall back to a "feature is
  /// being set up" status instead of hitting the network.
  ///
  /// Returns false now that the Worker is deployed at
  /// `anthropic-proxy.holy-breeze-9fa5.workers.dev` (2026-05-08).
  /// The check looks for the historical placeholder hostname so that
  /// any future config-revert that re-points at the placeholder fails
  /// loudly (calls fall back to the Coming-Soon path) rather than
  /// silently 404'ing on a nonexistent endpoint.
  static bool get isPlaceholder =>
      proxyBaseUrl.contains('anthropic-proxy.loadout.workers.dev');
}
