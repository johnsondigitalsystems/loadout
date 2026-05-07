// FILE: lib/services/support.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Single source of truth for support contact details. Kept tiny on
// purpose — anything that needs to reach a user-facing email or web
// address should import from here so a future change only touches one
// constant.
//
// Currently exports:
//
//   * `supportEmail` — the inbox we publish in Help & Support, the
//     "Get help signing in" affordance on the login screen, and any
//     mailto: handlers we ship.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/settings/settings_screen.dart — Email support tile +
//   the support-mailto body the tile composes.
// - lib/screens/auth/login_screen.dart — "Get help signing in" mailto.

/// Public support inbox. Any flow that needs to surface a contact
/// address to the user should reference this constant rather than
/// hard-coding the address. Centralized so a future address change is
/// a single-line edit.
const String supportEmail = 'support@johnsondigital.com';
