// FILE: lib/services/ai_proxy_config.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Holds configuration constants for the LoadOut AI proxy — the thin
// LoadOut-operated backend that mediates between the app and Anthropic's
// Messages API. The proxy itself does not exist yet; this file exists so
// the client side can be wired up first and a real backend dropped in by
// editing one constant.
//
// What lives here:
//
//   - `backendUrl` — the base URL of the proxy server. Default is the
//     placeholder `https://api.loadout.example.com`. The client appends
//     `/v1/chat` (or other paths) to this base.
//   - `chatPath` — path appended to [backendUrl] for chat requests
//     (`/v1/chat`).
//   - `requestTimeout` — HTTP timeout for proxy calls.
//   - `isPlaceholder` — getter returning `true` whenever the backend URL
//     still points at the placeholder host. While true, `AiChatService`
//     keeps showing its "Coming soon" state instead of attempting a
//     network call.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Centralising the proxy URL in one place follows the same pattern as
// `revenue_cat_config.dart`. When the real backend ships (Cloudflare
// Workers, Firebase Functions, a small Node service, anything that can
// validate a RevenueCat user-id and forward to Anthropic), a single
// edit here flips the entire app from "coming soon" to live. No screen
// or service code needs to learn about the URL change.
//
// The proxy model replaces the previous "key in the binary" approach
// (still configured in `ai_chat_config.dart` for back-compat). Putting
// the Anthropic key on the server eliminates the leaked-key blast
// radius and lets the server check the RevenueCat entitlement plus the
// monthly quota authoritatively, instead of trusting the client.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Not particularly tricky — pure constants. The non-obvious bit is the
// `isPlaceholder` indirection: checking the host against the
// `example.com` sentinel means we can drop in any domain without
// remembering to flip a separate "ready" flag.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/services/ai_proxy_client.dart` — reads `backendUrl`, `chatPath`,
//   and `requestTimeout` to build the HTTP request.
// - `lib/services/ai_chat_service.dart` — reads `isPlaceholder` to decide
//   whether to short-circuit to the "coming soon" state.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure compile-time constants.

/// Configuration for the LoadOut AI proxy backend. The proxy itself is
/// not yet deployed — when it is, replace [backendUrl] with the real
/// host (e.g. `https://api.loadout.app`) and [isPlaceholder] flips to
/// false automatically.
class AiProxyConfig {
  /// Base URL of the AI proxy server. The client appends [chatPath] to
  /// this for chat requests.
  ///
  /// Until the real backend ships this points at a placeholder host;
  /// `isPlaceholder` returns `true` and `AiChatService` keeps showing
  /// the "Coming soon" state.
  static const String backendUrl = 'https://api.loadout.example.com';

  /// Path appended to [backendUrl] for chat completion requests.
  static const String chatPath = '/v1/chat';

  /// HTTP request timeout for proxy calls. Streaming responses can take
  /// a while to complete; this caps the total wall-clock duration.
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Whether the proxy URL is still a placeholder. When true, callers
  /// should bail out gracefully instead of attempting the network call.
  ///
  /// Treats any host containing `example.com` as a placeholder so we can
  /// experiment with multiple sentinel values during development.
  static bool get isPlaceholder => backendUrl.contains('example.com');
}
