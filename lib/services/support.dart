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
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Hard-coding the support address at every call site (~6 surfaces
// today) would mean a future address change is a 6-grep, 6-edit
// chore. Centralizing it here keeps the rename to a single line and
// gives us a stable name to import.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Trivial today — but the file deliberately stays string-only. If
// future support flows need richer affordances (e.g. a phone number,
// a separate `enterprise@` address, a localized inbox per language),
// add a new typed constant here rather than reaching for a class
// hierarchy. The point of this file is "boring constants we can rip
// without thinking."
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/settings/settings_screen.dart — Email support tile +
//   the support-mailto body the tile composes.
// - lib/screens/auth/login_screen.dart — "Get help signing in" mailto.
// - lib/screens/settings/account_settings_screen.dart — Need help
//   signing in tile.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure constants.

/// Public support inbox. Any flow that needs to surface a contact
/// address to the user should reference this constant rather than
/// hard-coding the address. Centralized so a future address change is
/// a single-line edit.
const String supportEmail = 'support@johnsondigital.com';
