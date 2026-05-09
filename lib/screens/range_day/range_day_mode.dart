// FILE: lib/screens/range_day/range_day_mode.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Two-value enum + small helper for the Range Day Detail screen's "Quick
// vs Full" mode toggle in the AppBar. Quick mode shows only the Setup
// and Firing Solution cards — the bare minimum a shooter needs at the
// firing line. Full mode reveals every advanced card (target plot,
// group statistics, hit probability, DOPE, moving target, wind bracket,
// notes). The user picks a mode once and the choice persists across
// visits via SharedPreferences (key `range_day_mode`).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Range Day is the most surface-heavy screen in the app — eleven cards
// scrolling past on a phone. Most users at the range only need the
// Solution card; the rest is for analysis after the shot. Pulling the
// mode out into its own file keeps `range_day_detail_screen.dart`
// clean and gives any future Range Day surface (the watch app, a wide
// tablet variant) a single source of truth for the toggle.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The persisted string MUST be stable across renames — we store the
//     enum's `name` (`quick` / `full`), and the parser tolerates an
//     unknown / missing value by returning [RangeDayMode.quick] (the
//     beginner-friendly default). Renaming enum cases would silently
//     reset every existing user's preference, so don't.
//   * SharedPreferences I/O is async; the screen reads it once during
//     initState and writes it on every change. The default before the
//     read completes is [RangeDayMode.quick] so users on a fresh
//     install see the calmer surface immediately.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/range_day/range_day_detail_screen.dart
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None — pure value type + parsing helper. The screen is responsible
// for the SharedPreferences I/O.

/// User-controlled visibility mode for the Range Day Detail screen.
/// `quick` collapses the screen to Setup + Firing Solution. `full`
/// shows every card (matches v1 behavior).
enum RangeDayMode {
  quick,
  full,
}

/// SharedPreferences key for the persisted mode choice. Lives here so
/// the screen and any future surface that reads the preference share
/// one constant.
const String kRangeDayModePrefKey = 'range_day_mode';

/// Parse the persisted value back into a [RangeDayMode]. Tolerates
/// missing / unknown strings by returning [RangeDayMode.quick] — that
/// way a corrupted prefs entry or a future enum-rename can't brick the
/// screen.
RangeDayMode rangeDayModeFromString(String? raw) {
  switch (raw) {
    case 'full':
      return RangeDayMode.full;
    case 'quick':
    default:
      return RangeDayMode.quick;
  }
}
