// FILE: lib/services/active_range_day_session.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// In-memory tracker for the Range Day session the user is currently
// editing. Provides a `ValueNotifier<int?>` whose value is the active
// `RangeDaySessions.id` (or `null` when no session is active). The
// Range Day detail screen sets the value when it hydrates / saves a
// session and clears it on `dispose`. Anything outside the screen
// that needs to know "what session is the user looking at right now"
// reads this — currently only the watch bridge's `log_shot` listener
// in `_AuthGate`, but the abstraction is ready for any future
// out-of-screen feature (background wear notifications, share-extension
// inbound, …) that needs the same answer.
//
// Public surface:
//   * `ActiveRangeDaySession.notifier` — `ValueNotifier<int?>`. Read
//     `notifier.value` to get the current id, or `notifier.addListener`
//     to react to changes.
//   * `ActiveRangeDaySession.set(int id)` — mark a session as active.
//     Idempotent — setting the same id twice doesn't fire listeners.
//   * `ActiveRangeDaySession.clear()` — clear the active id (no
//     session is currently being edited).
//   * `ActiveRangeDaySession.id` — convenience getter for the current
//     value.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The watch bridge's `log_shot` listener has to fire from above the
// screen tree (it lives in `_AuthGate` so it stays alive across
// navigation), but the only place that knows "which Range Day session
// is the user editing" is the Range Day detail screen's `State`.
// Plumbing a `BuildContext` from outside the tree into the bridge
// listener would be fragile (the context can deactivate underneath
// us); plumbing a singleton tracker is easy and survives navigation.
//
// Living in its own file keeps the surface tiny — the tracker is just
// a `ValueNotifier<int?>`. Putting it inline in the bridge service
// would muddy the bridge's "I move bytes between phone and watch"
// charter; putting it inline in the Range Day screen would prevent
// `_AuthGate` from reading it without a tight coupling on the screen
// import.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Process-local only, not persistent.** The tracker is a singleton
//    `ValueNotifier`, NOT backed by `SharedPreferences`. A cold app
//    launch starts with `value == null` and the user has to tap into
//    the Range Day screen for the value to be set. This is correct:
//    a watch shot that arrives during cold-start drops to "no active
//    session" — the watch's `transferUserInfo` queue redelivers it
//    when the phone reaches an active session. Persisting an id
//    across launches would surface stale data ("you fired a shot at
//    a session you closed an hour ago, here's your shot") which is
//    worse than dropping cleanly.
//
// 2. **Screen lifecycle owns set/clear.** `_RangeDayDetailScreenState`
//    sets the id at the end of `_hydrateFromSessionInner` (after the
//    save lands) and clears it in `dispose`. A future screen that also
//    wants to claim ownership of the active session should follow the
//    same set-on-mount / clear-on-dispose contract.
//
// 3. **Singleton, not Provider-mounted.** This is the rare service that
//    lives ABOVE the Provider tree because `_AuthGate` reads it before
//    the Provider tree descendants exist. Making it a Provider would
//    mean either provider it twice (once for `_AuthGate`, once for
//    descendants) or restructuring the tree. A static singleton is the
//    pragmatic answer; the `ValueNotifier` is exported directly so
//    callers that want listenable semantics still get them.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/app.dart — `_AuthGate._wireWatchShotIngest` reads the value to
//   resolve which Range Day session to write inbound `log_shot`
//   payloads to.
// - lib/screens/range_day/range_day_detail_screen.dart — sets the
//   value on hydrate/save, clears it on dispose.
// - test/active_range_day_session_test.dart — verifies the set/clear/
//   idempotency contract.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure in-memory state — no disk, no network, no listeners on
// any external resource. Lives for the lifetime of the Dart isolate.

import 'package:flutter/foundation.dart';

/// Singleton tracker for the Range Day session the user is currently
/// editing. See file header for usage.
class ActiveRangeDaySession {
  ActiveRangeDaySession._();

  /// Backing notifier. Exposed so callers can `addListener` if they
  /// want to react to changes; most call sites just read `.value`.
  static final ValueNotifier<int?> notifier = ValueNotifier<int?>(null);

  /// Convenience getter — returns the current active session id, or
  /// `null` when no session is active.
  static int? get id => notifier.value;

  /// Mark [sessionId] as the active Range Day session. Idempotent —
  /// setting the same id again is a no-op (won't fire listeners).
  static void set(int sessionId) {
    if (notifier.value == sessionId) return;
    notifier.value = sessionId;
  }

  /// Clear the active session id. Called from
  /// `_RangeDayDetailScreenState.dispose` when the user leaves the
  /// screen.
  static void clear() {
    if (notifier.value == null) return;
    notifier.value = null;
  }
}
