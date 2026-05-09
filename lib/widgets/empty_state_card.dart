// FILE: lib/widgets/empty_state_card.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// A small reusable empty-state card. Renders inside any space where the
// data behind a list / dropdown / grid is empty and the user needs a
// nudge toward a productive next step. Three slots:
//
//   * `heading` — short title ("No saved loads yet"). Required.
//   * `body` — one-paragraph explanation. Required.
//   * `actions` — zero or more buttons (`FilledButton`,
//     `OutlinedButton`, `TextButton`). Rendered in a `Wrap` so the
//     widget never asks Flutter to lay out infinite-width children
//     inside a `Column.stretch` parent (the bug class the Range Day
//     screen has been fighting — see the file-header note in
//     `lib/screens/range_day/range_day_detail_screen.dart`).
//
// The card uses the surrounding theme's `colorScheme.surfaceContainer`
// for its background so it sits visually a notch above plain card
// stacks; the heading uses `titleMedium` and the body uses `bodyMedium`
// against `onSurfaceVariant` for subtle hierarchy.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Empty-state design is repetitive. Every list screen (Recipes,
// Firearms, Brass Lots, Range Day pickers) needs a "nothing here yet —
// here's how to make something" card. Centralizing the layout +
// typography here ensures consistency without each screen
// hand-rolling its own Card / Column / Row.
//
// Returning a `Card` lets the widget plug into any column layout
// without an extra wrapper. The card body is wrapped in `Padding` so
// the caller doesn't have to remember to add their own.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * **Wrap, not Row + Expanded.** Several Range Day layouts have
//     crashed in the past because a Row + Expanded chain ended up
//     inside a `Column.stretch`, which passes infinite-width
//     constraints to its children. The action row in this widget
//     uses `Wrap` deliberately; the buttons ALSO must not be
//     `Expanded` themselves. Don't "fix" this back to a Row if a
//     designer asks for two same-width buttons.
//   * `crossAxisAlignment: CrossAxisAlignment.start` on the column
//     so the heading + body sit left-aligned regardless of the
//     parent's alignment. Aligns with the rest of the LoadOut form
//     visual language.
//   * No emojis. The brand voice is reloader-skeptic and tactical;
//     emojis would feel out of place. If a future redesign wants
//     iconography, pass a leading `Icon` widget via a new optional
//     slot rather than embedding it in the heading string.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/screens/range_day/range_day_detail_screen.dart` — the load
//     picker's empty-state branch.
//   * Potentially many places — any screen with an empty-list state
//     should reuse this rather than rolling its own.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure presentational widget.

import 'package:flutter/material.dart';

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.heading,
    required this.body,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.all(16),
  });

  final String heading;
  final String body;

  /// Zero or more action buttons. Rendered in a [Wrap] so multi-button
  /// rows never inherit infinite-width constraints from a stretched
  /// column ancestor.
  final List<Widget> actions;

  /// Padding inside the card. Default 16 on all sides matches the rest
  /// of the LoadOut form layouts.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Wrap, not Row + Expanded — every action button stays
              // intrinsic-width. See file-header note for why.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
