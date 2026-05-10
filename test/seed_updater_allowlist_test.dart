// FILE: test/seed_updater_allowlist_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Regression test that asserts the bundled `assets/seed_data/manifest.json`
// declares only keys that `SeedUpdater.allowedKeys` recognises. The
// failure mode this catches is "engineer added a new seed JSON to the
// bundle and forgot to whitelist its key in `seed_updater.dart`" — at
// runtime a SeedUpdater fetch for that key would be silently dropped at
// the `if (!allowedKeys.contains(key)) continue;` guard.
//
// Also asserts the inverse: every `allowedKeys` entry has a corresponding
// row in the bundled manifest. This catches the symmetric bug —
// "removed a JSON file but left its allowlist entry behind."
//
// ============================================================================
// WHY IT EXISTS
// ============================================================================
// The cost of a missed key is "live updates silently don't work for that
// table." That's the kind of bug nobody notices until a user reports
// stale data months after a SeedUpdater publish. CI catches it instead.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - flutter test (CI gate)
//   - Engineers adding a new seed JSON file
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Reads the bundled manifest from the asset bundle.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/seed_updater.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedUpdater allowlist <-> bundled manifest', () {
    test('every manifest key is in allowedKeys', () async {
      final raw = await rootBundle.loadString('assets/seed_data/manifest.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      final missing = <String>[];
      for (final key in files.keys) {
        if (!allowedKeys.contains(key)) {
          missing.add(key);
        }
      }
      expect(missing, isEmpty,
          reason:
              'These manifest keys are not in `allowedKeys` in '
              'lib/services/seed_updater.dart — the runtime would '
              'silently drop their updates:\n  ${missing.join("\n  ")}');
    });

    test('every allowedKeys entry is in the bundled manifest', () async {
      final raw = await rootBundle.loadString('assets/seed_data/manifest.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final files = (decoded['files'] as Map<String, dynamic>).keys.toSet();
      final orphans = <String>[];
      for (final key in allowedKeys) {
        if (!files.contains(key)) {
          orphans.add(key);
        }
      }
      expect(orphans, isEmpty,
          reason:
              'These `allowedKeys` entries have no matching row in '
              'assets/seed_data/manifest.json — either add the file '
              'and bump the manifest, or remove the orphan from '
              '`allowedKeys`:\n  ${orphans.join("\n  ")}');
    });

    test('every manifest filename points at a file that exists in the bundle',
        () async {
      final raw = await rootBundle.loadString('assets/seed_data/manifest.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      final missing = <String>[];
      for (final entry in files.entries) {
        final spec = entry.value as Map<String, dynamic>;
        final filename = spec['filename'] as String;
        try {
          // rootBundle.load() throws FlutterError when the asset isn't
          // declared in pubspec — same crash signature a fresh-install
          // user would see on launch.
          await rootBundle.load('assets/seed_data/$filename');
        } catch (_) {
          missing.add('${entry.key} → $filename');
        }
      }
      expect(missing, isEmpty,
          reason:
              'These manifest entries point at files that are not '
              'reachable through rootBundle. Either the file is '
              'missing from disk, or pubspec.yaml is missing the '
              "asset declaration (CLAUDE.md § 12a):\n"
              '  ${missing.join("\n  ")}');
    });
  });
}
