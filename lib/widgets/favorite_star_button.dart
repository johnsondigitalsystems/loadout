// FILE: lib/widgets/favorite_star_button.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Defines [FavoriteStarButton], the reusable star-icon affordance every
// list screen and picker uses to toggle a row's favorite state. The
// widget is purely presentational — it doesn't know what kind of entity
// it represents (a recipe, firearm, ballistic profile, cartridge,
// reticle, or target). The caller passes a `Future<void> Function()`
// that flips the appropriate persistent flag (either a per-row
// `isFavorite` boolean on a user-data table, or a `(entityType,
// entityId)` row in `UserFavorites`), and this widget handles the
// visual state plus error reporting.
//
// Public API:
//   * `isFavorite`   — the current state. The caller is responsible for
//                       reading it (via stream / setState / provider) so
//                       the widget rebuilds when the underlying flag
//                       changes.
//   * `onToggle()`   — async callback fired on tap. The widget catches
//                       errors thrown by this callback and surfaces a
//                       snackbar fallback ("Could not update favorite")
//                       so every call site doesn't have to repeat the
//                       error-handling boilerplate.
//   * `size`         — icon size in logical pixels. Defaults to 22 to
//                       fit a standard `ListTile` trailing slot.
//   * `tooltip`      — optional override; defaults to "Favorite" /
//                       "Unfavorite" based on the current state.
//   * `compact`      — when true, wraps the button with
//                       `VisualDensity.compact` and a tighter
//                       padding so it sits inside a dense `ListTile`
//                       trailing area without crowding adjacent
//                       widgets (chevron, shots-fired chip, etc.).
//
// Visuals:
//   * `isFavorite == true`  → `Icons.star` filled, in
//     `colorScheme.primary` (the brass tone).
//   * `isFavorite == false` → `Icons.star_border` outlined, in
//     `colorScheme.onSurfaceVariant` (muted).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Without a shared widget every consumer (Recipes list, Firearms list,
// Ballistics profile picker, SAAMI cartridge list, Range Day target /
// reticle pickers, future pickers) would re-implement the same six-line
// IconButton + try/catch + tooltip block, and the resulting visual
// drift would be subtle but real — different sizes, different padding,
// different color buckets, slightly different snackbar copy. By
// centralizing here, the brass-toned filled star and the
// passthrough-on-tap contract are guaranteed identical everywhere.
//
// The widget does NOT call any repository directly. The caller is
// responsible for wiring `onToggle` to the right `toggleFavorite(...)`
// method (per-row boolean for user data, [FavoritesRepository] for
// reference data). That keeps this file zero-dependency on the
// database layer and trivially testable in isolation.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Async tap handling.** The `onToggle` callback is async because
//    every concrete implementation hits SQLite. If the widget didn't
//    capture errors, a transient failure (e.g. drift transaction
//    contention during a Cloud Sync pull) would surface as an
//    unhandled exception in the calling screen. Wrapping in try/catch
//    means the user sees a friendly snackbar and the calling screen
//    doesn't have to thread error handling through every list row.
//
// 2. **Mounted-guard around `ScaffoldMessenger`.** The widget might be
//    disposed between the moment the user taps and the moment the
//    async toggle returns (e.g. they tapped on a row that was about
//    to be deleted by a cloud-sync pull). Reading the messenger
//    BEFORE the await and only calling `showSnackBar` if `context.mounted`
//    is the safe pattern.
//
// 3. **Deliberate StatelessWidget.** The widget owns no internal
//    "isFavorite" state — it always reflects the prop the parent
//    passes in. This is intentional: optimistic toggling inside the
//    widget would race with the live stream that drives the parent's
//    rebuild, and a failed write would leave the icon stuck in the
//    wrong state. Keeping it stateless means the source of truth is
//    always the database stream.
//
// 4. **`VisualDensity.compact` quirk.** `IconButton` honors
//    `VisualDensity` differently from most Material widgets — passing
//    a `VisualDensity.compact` shrinks the tap target to roughly 36px
//    instead of the default 48px. That's exactly what we want inside
//    a `ListTile` trailing slot (where 48px would push the chevron
//    off the right edge), but it's NOT what we want as a standalone
//    affordance — hence the `compact` flag controlled by the caller.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/recipes/recipes_list_screen.dart — trailing star on
//   each recipe row.
// - lib/screens/firearms/firearms_list_screen.dart — trailing star on
//   each firearm row.
// - lib/screens/ballistics/ballistics_screen.dart — star on the
//   profile picker rows.
// - lib/screens/saami/saami_screen.dart — star on the cartridge
//   list / picker rows.
// - lib/widgets/component_field.dart — visual indicator only (the
//   widget shows a star icon, but tap toggles selection in that
//   context, so this is rendered as a non-interactive `Icon` next to
//   the option text rather than a full button).
// - Future Range Day pickers (target / reticle / load / firearm /
//   profile) — that work is owned by the parallel Range Day agent.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Calls the `onToggle` callback on tap. Any database side effects
//   live there.
// - May surface a `SnackBar` via the nearest `ScaffoldMessenger` when
//   `onToggle` throws. Soft-fail policy: never re-throws.

import 'package:flutter/material.dart';

/// Reusable star-icon affordance for toggling a row's favorite state.
///
/// The widget is purely presentational: it renders the icon based on
/// [isFavorite], and on tap fires [onToggle]. The caller is responsible
/// for performing the persistent toggle (e.g. calling the appropriate
/// repository's `toggleFavorite(...)` method) and for ensuring
/// [isFavorite] reflects the latest persistent state.
///
/// Errors thrown by [onToggle] are caught and surfaced as a snackbar
/// ("Could not update favorite") so every list site doesn't have to
/// repeat that error-handling boilerplate.
class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 22,
    this.tooltip,
    this.compact = false,
  });

  /// Whether the entity is currently favorited. Drives the icon
  /// (filled vs outlined) and the default tooltip text.
  final bool isFavorite;

  /// Async callback fired on tap. Should perform the persistent
  /// toggle (typically by calling the appropriate repository's
  /// `toggleFavorite(...)`). Errors are caught and reported via
  /// snackbar; the callback should NOT pop them itself.
  final Future<void> Function() onToggle;

  /// Icon size in logical pixels. Defaults to 22 (a hair smaller than
  /// the Material default of 24) so the star sits cleanly inside a
  /// standard `ListTile` trailing slot without crowding the chevron.
  final double size;

  /// Optional tooltip override. When null, the button defaults to
  /// "Favorite" / "Unfavorite" based on [isFavorite].
  final String? tooltip;

  /// When true, wraps the button with `VisualDensity.compact` and a
  /// tighter padding so it fits inside a dense `ListTile` trailing
  /// slot alongside other widgets (chevron, shots-fired chip, etc.).
  /// Standard density (the default) is appropriate for standalone
  /// affordances.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isFavorite
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final icon = isFavorite ? Icons.star : Icons.star_border;
    final resolvedTooltip = tooltip ?? (isFavorite ? 'Unfavorite' : 'Favorite');

    return IconButton(
      tooltip: resolvedTooltip,
      icon: Icon(icon, size: size, color: color),
      // Compact density pulls the tap target from 48px → ~36px so the
      // button fits inside a dense `ListTile` trailing slot. The
      // tight padding follows the same intent — without it, the
      // default 8px symmetric padding pushes adjacent widgets off
      // the right edge.
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      padding: compact
          ? const EdgeInsets.all(4)
          : const EdgeInsets.all(8),
      constraints: compact
          ? const BoxConstraints(minWidth: 32, minHeight: 32)
          : const BoxConstraints(),
      onPressed: () => _handleTap(context),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    // Capture the messenger BEFORE the await so we don't reach into
    // a context that may be unmounted by the time the toggle returns.
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await onToggle();
    } catch (_) {
      // Soft-fail: surface a snackbar instead of letting the error
      // bubble out and crash the calling screen. Common cause is
      // drift transaction contention during a Cloud Sync pull.
      if (messenger == null || !context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update favorite')),
      );
    }
  }
}
