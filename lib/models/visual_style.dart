// FILE: lib/models/visual_style.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Three-value enum that drives the Range Day scene's visual style.
// `cartoon` is the existing procedural rendering (sky / hills / grass /
// mound / pole / target). `polished` layers atmospheric effects on top
// of the cartoon paint pass — DOF blur on distant elements, ground
// haze, soft target drop shadow, color grade, vignette, film grain.
// `photo` is reserved for Phase 12 / 13's photo-realistic mount stands
// + backdrop library; until those phases ship, the painter aliases
// `photo` to `polished` so the enum's three values can already be
// surfaced in the Settings + Range Day toggle UI without breaking.
//
// Public surface:
//   * `VisualStyle` enum — `cartoon | polished | photo`.
//   * `VisualStyle.persistKey` — the stable string written to
//     SharedPreferences. Equals `enum.name` (`'cartoon'` /
//     `'polished'` / `'photo'`).
//   * `VisualStyle.fromPersistKey(String?)` — parses a stored value
//     back to an enum. Unknown / null / empty values fall back to
//     `cartoon` (the safe default).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Phase 10 introduces a user-controlled visual style. Without this
// file, the choice would live as a magic string inside the
// `_RealisticScenePainter` constructor — leaking the storage shape
// into every call site. Pulling it out lets:
//   * `VisualStyleNotifier` (lib/services/visual_style_notifier.dart)
//     hold the current value, persist changes, and notify listeners.
//   * The painter take a `VisualStyle` parameter without dragging
//     SharedPrefs / String parsing into widget code.
//   * Settings + Range Day toggle UIs use a typed
//     `SegmentedButton<VisualStyle>` instead of string-based switches.
//
// The persistence helper (`persistKey` + `fromPersistKey`) is here
// rather than on the notifier because the value is also referenced
// from tests + (potentially) Cloud Sync export — keeping it on the
// type means the notifier is just I/O orchestration, not protocol.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The persisted string MUST be stable across renames — we store
//     `enum.name`, and `fromPersistKey` tolerates unknown values by
//     returning `cartoon`. Renaming an enum case would silently reset
//     every existing user's preference, so don't rename.
//   * `fromPersistKey` is deliberately permissive on null / empty /
//     unknown. A SharedPreferences entry could be corrupted; a
//     pre-Phase-10 install has no entry at all; a future enum could
//     drop a value before persistence catches up. All three resolve
//     to `cartoon`.
//   * `photo` is in the enum because the UI surfaces (Settings
//     SegmentedButton, Range Day AppBar toggle) need to offer it as a
//     real choice. The painter aliases `photo` → `polished` until
//     Phases 12 / 13 — that alias lives at the painter's dispatch
//     site, not here. Keeping the alias out of the enum means the
//     persistence layer remembers what the user actually picked, so
//     Phase 12 / 13 don't need a migration.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/services/visual_style_notifier.dart` — owns the SharedPrefs
//     I/O and the ChangeNotifier surface.
//   * `lib/screens/range_day/widgets/target_plot.dart` — the painter's
//     constructor parameter + the photo→polished alias.
//   * `lib/screens/settings/...` — the Settings UI's `SegmentedButton`.
//   * `lib/screens/range_day/range_day_detail_screen.dart` — the Range
//     Day AppBar's compact toggle.
//   * `test/visual_style_test.dart` — round-trip tests for the
//     persistKey / fromPersistKey contract.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * None. Pure value type + pure string parsing. SharedPrefs I/O
//     lives in `VisualStyleNotifier`.

/// User-controlled visual style for the Range Day scene. Default
/// `cartoon` matches the pre-Phase-10 rendering. `polished` layers
/// atmospheric effects on top of cartoon. `photo` is reserved for
/// Phases 12 / 13's photo-realistic backdrops; pre-12 it renders as
/// polished (alias lives at the painter's dispatch site).
enum VisualStyle {
  cartoon,
  polished,
  photo;

  /// Stable string written to SharedPreferences. Uses `enum.name` so
  /// the storage shape can't drift from the source. Renaming a value
  /// would invalidate every existing user's stored preference — don't.
  String get persistKey => name;

  /// Parse a SharedPreferences value back into a [VisualStyle].
  /// Unknown / null / empty values fall back to `cartoon` so a
  /// corrupted prefs entry or a future enum-rename can't brick the
  /// scene.
  static VisualStyle fromPersistKey(String? key) => switch (key) {
        'polished' => VisualStyle.polished,
        'photo' => VisualStyle.photo,
        _ => VisualStyle.cartoon,
      };
}

/// SharedPreferences key for the persisted visual-style choice. Lives
/// here so the notifier and any future surface that reads the
/// preference share one constant.
const String kVisualStylePrefKey = 'visual_style';
