// FILE: test/seed_loader_optics_removed_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Regression guard for the v2.3 post-merge hotfix that removed
// `_seedOptics()` and its callers from `lib/database/seed_loader.dart`.
//
// The crash this prevents: on first launch (cleared SharedPreferences
// state), `SeedLoader.seedIfNeeded()` would invoke `_seedOptics()`,
// which tried to load `assets/seed_data/optics.json` — a file that
// was deleted in Phase 2's catalog merge. The result was an
// `Unable to load asset: "assets/seed_data/optics.json"` exception
// bubbling all the way up the cold-start path. The fix removed:
//   * the `opticsReseed` local in `seedIfNeeded`
//   * the `if (opticsReseed) { ... _seedOptics() ... }` branch
//   * the `_seedOptics()` method body
//   * the `clearIf(opticsReseed, 'optics')` flag-clear call
//
// This test asserts the seed loader source file no longer references
// any of those identifiers, so a future merge that drags the old
// code back in trips a unit test instead of crashing a user.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `test/seed_updater_allowlist_test.dart` already guards the manifest
// → allowedKeys correspondence. `test/assets_present_test.dart` walks
// the on-disk seed data and confirms every file is bundle-reachable.
// Neither test covers the inverse failure mode: a code path that
// tries to load a path that no longer exists. This file fills that
// gap with a grep-style assertion.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads `lib/database/seed_loader.dart` from disk via `dart:io`. No
// network, no DB, no asset bundle.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeedLoader — legacy optics.json path retired', () {
    late String src;

    setUpAll(() {
      src = File('lib/database/seed_loader.dart').readAsStringSync();
    });

    test('does not reference the deleted `optics.json` asset path', () {
      // The string can appear in comments (e.g. the hotfix explanatory
      // note) but not in a way that would be picked up by the parser
      // as a quoted path literal. We accept the substring inside `//`
      // line comments by stripping comments first.
      final code = _stripLineComments(src);
      expect(code.contains("'optics.json'"), isFalse,
          reason: 'seed_loader.dart must not load the deleted '
              'assets/seed_data/optics.json — that crashed on '
              'first launch after the Phase 2 catalog merge.');
      expect(code.contains('"optics.json"'), isFalse,
          reason: 'seed_loader.dart must not load the deleted '
              'assets/seed_data/optics.json — that crashed on '
              'first launch after the Phase 2 catalog merge.');
    });

    test('does not declare or call `_seedOptics`', () {
      final code = _stripLineComments(src);
      expect(code.contains('_seedOptics'), isFalse,
          reason: 'The legacy `_seedOptics` method was retired in '
              'the v2.3 hotfix. Re-introducing it without restoring '
              'optics.json would re-introduce the first-launch crash.');
    });

    test('does not reference the `opticsReseed` flag', () {
      final code = _stripLineComments(src);
      expect(code.contains('opticsReseed'), isFalse,
          reason: 'The `opticsReseed` local was retired with '
              'optics.json. Any reference to it in non-comment code '
              'will fail to compile.');
    });
  });

  group('SeedLoader — legacy _seedVerifiedScopes retired', () {
    late String src;

    setUpAll(() {
      src = File('lib/database/seed_loader.dart').readAsStringSync();
    });

    test('does not declare or call `_seedVerifiedScopes`', () {
      final code = _stripLineComments(src);
      expect(code.contains('_seedVerifiedScopes'), isFalse,
          reason: 'The legacy v22 `_seedVerifiedScopes()` was retired '
              'in the v2.3 hotfix — it read scopes.json as a Map (Phase 2 '
              'flattened to List) and reticles_v2.json (deleted). '
              'Re-introducing it without restoring those file shapes '
              'would re-introduce the cold-start crash.');
    });

    test('does not reference `reticles_v2.json`', () {
      final code = _stripLineComments(src);
      expect(code.contains('reticles_v2.json'), isFalse,
          reason: 'reticles_v2.json was deleted in Phase 2 (merged '
              'into reticles.json). The seeder must not load it.');
    });

    test('does not declare a `verifiedScopesReseed` flag', () {
      final code = _stripLineComments(src);
      expect(code.contains('verifiedScopesReseed'), isFalse,
          reason: 'Retired with _seedVerifiedScopes in the v2.3 hotfix.');
    });
  });

  group('SeedLoader._seedReticles — v2.3 columns populated', () {
    late String src;

    setUpAll(() {
      src = File('lib/database/seed_loader.dart').readAsStringSync();
    });

    test('passes subtensionOrigin into ReticlesCompanion.insert', () {
      // The Phase 6 §C per-origin disclaimer feature reads
      // `subtensionOrigin` via the drift picker. If `_seedReticles`
      // omits this column on insert, drift gets NULL and the
      // disclaimer silently falls back to the legacy "LoadOut
      // Original — Interoperability Calibration" string instead of
      // rendering the per-origin template. This regression locks in
      // that the column IS populated at seed time.
      expect(src.contains('subtensionOrigin:'), isTrue,
          reason: '_seedReticles must pass subtensionOrigin to '
              'ReticlesCompanion.insert. Otherwise the Phase 6 §C '
              'per-origin disclaimer silently regresses to the '
              'legacy fixed caption on all installs that seed after '
              'the v2.3 hotfix.');
    });

    test('passes calibrationProvenance into ReticlesCompanion.insert', () {
      // Same reasoning — the published_spec disclaimer template
      // reads manufacturer + reticle_name from the
      // `calibration_provenance` JSON blob. If the drift column is
      // NULL, the template falls through to the generic "Calibrated
      // to manufacturer specification" without naming.
      expect(src.contains('calibrationProvenance:'), isTrue,
          reason: '_seedReticles must pass calibrationProvenance '
              '(as a JSON-encoded string) to ReticlesCompanion.insert.');
    });
  });
}

/// Strip `//`-style line comments so the assertions only see live
/// code, not the hotfix's explanatory comments that legitimately
/// reference the retired identifiers by name.
///
/// Does NOT strip `/* */` block comments — the v2.3 hotfix uses
/// only `//` comments, and stripping `/* */` accurately requires a
/// real lexer (string literals can contain `/*`). The line-comment
/// stripping is sufficient for this test's purpose.
String _stripLineComments(String src) {
  final lines = src.split('\n');
  return lines.map((line) {
    final commentStart = _findLineCommentStart(line);
    return commentStart < 0 ? line : line.substring(0, commentStart);
  }).join('\n');
}

/// Find the index of a `//` line-comment start that's NOT inside a
/// string literal. Returns -1 if no comment on this line. Tracks
/// single-quote and double-quote string state plus raw-string and
/// escape handling well enough for the seed loader file.
int _findLineCommentStart(String line) {
  String? inString;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inString != null) {
      if (c == r'\') {
        i++; // skip escaped char
        continue;
      }
      if (c == inString) inString = null;
    } else {
      if (c == "'" || c == '"') {
        inString = c;
      } else if (c == '/' && i + 1 < line.length && line[i + 1] == '/') {
        return i;
      }
    }
  }
  return -1;
}
