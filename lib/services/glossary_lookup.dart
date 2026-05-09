// FILE: lib/services/glossary_lookup.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Resolves a UI label string (e.g. "Drop", "CBTO", "Density altitude
// (caption)") to a canonical `GlossaryTerm` from the same authoritative
// table the Glossary screen renders. The class exposes a single static
// method, `GlossaryLookup.find(String)`, which returns either a
// matching entry or `null` (soft-fail — never throws).
//
// Resolution rules, applied in order:
//
//   1. Exact case-insensitive match against `term`.
//   2. Exact case-insensitive match against `acronym` (acronyms are
//      stored as raw strings — e.g. "BC G1", "MV / FPS"; the matcher
//      strips trailing parenthetical disambiguation like "SD
//      (statistics)" before comparing).
//   3. Substring match where the label is contained in `term` or
//      `acronym`, ranked: term-prefix > term-contains > acronym-contains.
//   4. Reverse substring match where `term` is contained in the label
//      (handles cases like a label "Wind drift (yd)" hitting "Wind
//      drift").
//
// To keep label lookups O(1) for the common case, this service builds
// a `Map<String, GlossaryTerm>` keyed by lowercased term and acronym
// at first call and caches it in a static field. Substring matching
// falls back to a linear scan, which is still cheap (~80 entries).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Form labels appear hundreds of times across the recipe form,
// ballistics screen, range-day detail, group stats, moving target,
// load development, and elsewhere. Each label benefits from a tap-to-
// learn affordance, but we don't want every screen to carry its own
// definition strings — that's a recipe for drift between the in-form
// help and the glossary screen.
//
// This file exists so `GlossaryLabel` (the user-visible widget) has a
// single, cheap, soft-failing way to resolve a free-form label into a
// real glossary entry. If the lookup misses, the widget renders as a
// plain Text — never a broken `(?)` glyph.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - Acronyms in the glossary are stored as human-readable strings
//   ("MV / FPS", "SD (statistics)"). A label of "MV" should match;
//   the matcher splits acronyms on "/" and "(" boundaries, trims, and
//   tries each fragment as an exact key.
// - The same acronym can map to two glossary entries (the canonical
//   case is "SD" — Sectional Density vs. Standard Deviation). The
//   lookup picks the first inserted entry; callers that need
//   disambiguation should pass a more specific `glossaryTerm` to
//   `GlossaryLabel`.
// - The cache MUST be lazy: tests and tools sometimes load this file
//   without a Flutter binding, and we don't want to materialize a
//   Map at import time if we can avoid it.
// - The glossary table is `const`, so its identity never changes
//   across hot reload. The cache is therefore safe to live for the
//   process lifetime.
// - Performance: `GlossaryLabel.build()` calls `find()` once per
//   build, and a Range Day screen renders ~50 labels. The exact-match
//   path is a Map lookup; the fallback path scans ~80 entries. Total
//   per-frame cost stays under a millisecond.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/glossary_label.dart` — the only direct consumer. The
//   widget calls `GlossaryLookup.find(label)` once per build to decide
//   whether to render the `(?)` glyph and what to show in the modal.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure in-memory lookup against the compile-time `kGlossaryTerms`
// list. No I/O, no logging beyond optional `debugPrint` for cache
// instrumentation in debug mode.

import 'package:flutter/foundation.dart';

import '../screens/glossary/glossary_screen.dart';

/// Lookup helper that resolves a free-form label string to a
/// `GlossaryTerm` entry. Soft-fails to `null` when no match exists.
class GlossaryLookup {
  GlossaryLookup._();

  /// Lazy-initialized index of lowercased term + acronym → GlossaryTerm.
  /// Built once on first call to `find` and reused for the process
  /// lifetime since the glossary table is `const`.
  static Map<String, GlossaryTerm>? _exactIndex;

  /// Set of lowercased labels we've already failed to match. Used to
  /// suppress the `debugPrint` noise on subsequent calls so a screen
  /// with 50 labels and 5 unmatched ones doesn't log 5× per build.
  /// Reset by `debugResetCache` for tests.
  static final Set<String> _missedLabels = <String>{};

  /// Build (or return cached) exact-match index. Only called from
  /// `find` so importing this file has no startup cost.
  static Map<String, GlossaryTerm> _index() {
    final cached = _exactIndex;
    if (cached != null) return cached;
    final map = <String, GlossaryTerm>{};
    for (final entry in kGlossaryTerms) {
      // Term first so it wins ties when an acronym from a different
      // entry collides with a term elsewhere.
      final termKey = entry.term.toLowerCase().trim();
      map.putIfAbsent(termKey, () => entry);
      final acronym = entry.acronym;
      if (acronym != null) {
        // Acronyms in the data sometimes carry disambiguation in
        // parentheses ("SD (statistics)") or list separators
        // ("MV / FPS"). Index every reasonable fragment.
        for (final piece in _splitAcronym(acronym)) {
          final key = piece.toLowerCase().trim();
          if (key.isEmpty) continue;
          map.putIfAbsent(key, () => entry);
        }
      }
    }
    _exactIndex = map;
    return map;
  }

  /// Split an acronym string into the individual tokens a user might
  /// type as a label. "MV / FPS" → ["MV / FPS", "MV", "FPS"]; "SD
  /// (statistics)" → ["SD (statistics)", "SD"]. Always includes the
  /// raw input so an exact-match against the original string still
  /// works.
  static List<String> _splitAcronym(String acronym) {
    final result = <String>[acronym];
    final base = acronym.split('(').first.trim();
    if (base.isNotEmpty && base != acronym) result.add(base);
    for (final piece in base.split('/')) {
      final p = piece.trim();
      if (p.isNotEmpty) result.add(p);
    }
    return result;
  }

  /// Resolve `label` to a `GlossaryTerm`. Returns `null` if no entry
  /// matches — never throws. Strips trailing parenthetical units like
  /// "(yd)" or "(°F)" before searching so a label "Distance (yd)"
  /// matches "Distance" (or whatever live entry exists).
  static GlossaryTerm? find(String label) {
    if (label.trim().isEmpty) return null;
    final cleaned = _strip(label);
    if (cleaned.isEmpty) return null;
    final index = _index();
    final lower = cleaned.toLowerCase();

    // 1. Exact match against indexed term/acronym keys.
    final exact = index[lower];
    if (exact != null) return exact;

    // 2. Term-prefix substring scan. Cheap on a ~80-entry table.
    for (final entry in kGlossaryTerms) {
      if (entry.term.toLowerCase().startsWith(lower)) return entry;
    }

    // 3. Term-contains.
    for (final entry in kGlossaryTerms) {
      if (entry.term.toLowerCase().contains(lower)) return entry;
    }

    // 4. Acronym-contains (already indexed exact, so this only
    // triggers when the user's label is a prefix of an acronym).
    for (final entry in kGlossaryTerms) {
      final acronym = entry.acronym?.toLowerCase();
      if (acronym != null && acronym.contains(lower)) return entry;
    }

    // 5. Reverse contains: label CONTAINS the term. Helps when the
    // visible label decorates the term ("Wind drift overlay").
    for (final entry in kGlossaryTerms) {
      final term = entry.term.toLowerCase();
      if (term.length >= 3 && lower.contains(term)) return entry;
    }

    if (kDebugMode && _missedLabels.add(lower)) {
      // First-time miss only — don't spam the console once per build
      // for the same unmatched label.
      debugPrint('[GlossaryLookup] no match for "$label"');
    }
    return null;
  }

  /// Strip trailing parenthetical units, surrounding punctuation, and
  /// trailing colons from a UI label so "Distance (yd):" → "Distance".
  static String _strip(String label) {
    var s = label.trim();
    // Drop trailing colon used in some labels.
    if (s.endsWith(':')) s = s.substring(0, s.length - 1).trim();
    // Drop a single trailing parenthetical group (units, qualifiers).
    final paren = RegExp(r'\s*\([^)]*\)\s*$');
    s = s.replaceAll(paren, '').trim();
    return s;
  }

  /// Test-only: reset the cached index. Allows tests to validate the
  /// lazy-build path without process state leaking between cases.
  @visibleForTesting
  static void debugResetCache() {
    _exactIndex = null;
    _missedLabels.clear();
  }
}
