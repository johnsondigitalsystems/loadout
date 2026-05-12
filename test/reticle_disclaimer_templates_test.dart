// FILE: test/reticle_disclaimer_templates_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Covers Phase 6 Part C of the Range Day v2.3 rewrite — the §7.7
// per-origin disclaimer templates rendered by
// `ReticleInteroperabilityLabel` (lib/widgets/reticle_renderer.dart).
// The widget picks one of three templates based on a reticle's
// `subtensionOrigin`:
//
//   * `'original'`       → "LoadOut Original" + engineered tagline.
//   * `'public_domain'`  → "Public Domain Reticle" + traditional-pattern
//                          tagline (no trademark / copyright).
//   * `'published_spec'` → "Calibrated to <Manufacturer> <Reticle Name>"
//                          + "Not a reproduction" tagline.
//
// Tests:
//   1. `'original'`        renders the LoadOut Original label + tooltip.
//   2. `'public_domain'`   renders the Public Domain Reticle label.
//   3. `'published_spec'`  + valid provenance → name-substituted label.
//   4. `'published_spec'`  + missing / malformed provenance → generic
//      "Calibrated to manufacturer specification" fallback (no NPE).
//   5. Null origin (legacy callers)   → fixed back-compat string.
//   6. Catalog smoke test — every `'published_spec'` row in
//      `assets/seed_data/reticles.json` has a non-empty `manufacturer`
//      + `reticle_name` inside its `calibration_provenance` blob, so
//      no production row falls through to the generic fallback.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The disclaimer is the load-bearing IP safety net described in
// CLAUDE.md § 30. The "Not a reproduction" framing on
// `'published_spec'` rows is legally important — Horus Vision / HVRT
// Corp has historically sued over reticle reproduction; the honest
// "calibrated subtensions, LoadOut-original artwork, verify against
// your scope sheet" wording is the right posture. These tests guard
// against an accidental copy edit that paraphrases the legal language.
//
// The catalog smoke test (case 6) is the §7.7 data-integrity gate: if
// a future agent introduces a `'published_spec'` row without a valid
// `calibration_provenance` block, this test fails BEFORE the change
// ever reaches a user, so the picker can never render a row that
// silently degrades to the name-free fallback in production.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The widget uses a `Tooltip` to carry the per-origin tagline.
//     Tooltips are part of the widget tree but their text only renders
//     when the user hovers / long-presses; we assert tooltip content
//     via the `Tooltip.message` property, not by searching for
//     `find.text(...)`.
//   * For the catalog smoke test we read the JSON directly from disk
//     via `dart:io` + `dart:convert`. The flutter test CWD is the repo
//     root, so the relative path `assets/seed_data/reticles.json` is
//     stable across machines. Using `rootBundle` would require a
//     fully-bound binding which isn't worth the harness cost for a
//     pure data-integrity assertion.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// `flutter test` (CI + local).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads `assets/seed_data/reticles.json` from disk in the catalog
// smoke test. No DB, no network, no shared preferences.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/widgets/reticle_renderer.dart';

void main() {
  group('ReticleInteroperabilityLabel template selection', () {
    /// Tiny harness — wraps the widget in the minimal MaterialApp +
    /// Scaffold stack a Tooltip / Text needs to mount.
    Future<void> pumpLabel(
      WidgetTester tester, {
      String? subtensionOrigin,
      Map<String, dynamic>? calibrationProvenance,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ReticleInteroperabilityLabel(
                subtensionOrigin: subtensionOrigin,
                calibrationProvenance: calibrationProvenance,
              ),
            ),
          ),
        ),
      );
    }

    /// Locate the single `Tooltip` that wraps the disclaimer Text and
    /// return its `message`. The widget only ever has one Tooltip —
    /// any others on the screen would mean a regression in the
    /// widget's structure.
    String findTooltipMessage(WidgetTester tester) {
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget,
          reason: 'ReticleInteroperabilityLabel should wrap its caption '
              'in exactly one Tooltip carrying the per-origin tagline.');
      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      return tooltip.message ?? '';
    }

    testWidgets("'original' renders LoadOut Original + engineered tagline",
        (tester) async {
      await pumpLabel(tester, subtensionOrigin: 'original');
      expect(find.text('LoadOut Original'), findsOneWidget);
      expect(
        findTooltipMessage(tester),
        "Engineered for your scope's subtensions",
      );
    });

    testWidgets(
        "'public_domain' renders Public Domain Reticle + traditional tagline",
        (tester) async {
      await pumpLabel(tester, subtensionOrigin: 'public_domain');
      expect(find.text('Public Domain Reticle'), findsOneWidget);
      expect(
        findTooltipMessage(tester),
        'Traditional duplex / hash / dot pattern; not subject to '
        'trademark or copyright',
      );
    });

    testWidgets(
        "'published_spec' with valid provenance substitutes name + 'Not a reproduction'",
        (tester) async {
      await pumpLabel(
        tester,
        subtensionOrigin: 'published_spec',
        calibrationProvenance: const {
          'manufacturer': 'Vortex Optics',
          'reticle_name': 'EBR-7D MRAD',
          'published_url': 'https://vortexoptics.com/',
          'verified_at': '2026-05-11',
        },
      );
      expect(
        find.text('Calibrated to Vortex Optics EBR-7D MRAD'),
        findsOneWidget,
      );
      expect(
        findTooltipMessage(tester),
        'Subtensions calibrated to the published manufacturer '
        'specification. Not a reproduction. Verify against your '
        "scope's specification sheet for precision use.",
      );
    });

    testWidgets(
        "'published_spec' with missing provenance falls back to generic label",
        (tester) async {
      // Case 4a: provenance null entirely.
      await pumpLabel(tester, subtensionOrigin: 'published_spec');
      expect(
        find.text('Calibrated to manufacturer specification'),
        findsOneWidget,
      );
      // Tooltip still carries the "Not a reproduction" framing — that
      // language is legally load-bearing and must NOT be dropped when
      // the provenance is missing.
      expect(
        findTooltipMessage(tester),
        contains('Not a reproduction'),
      );

      // Case 4b: provenance present but the expected keys are missing.
      await pumpLabel(
        tester,
        subtensionOrigin: 'published_spec',
        calibrationProvenance: const {
          'unrelated_field': 'whatever',
        },
      );
      expect(
        find.text('Calibrated to manufacturer specification'),
        findsOneWidget);

      // Case 4c: provenance has the expected keys but their values are
      // empty strings — treat empties as missing rather than rendering
      // a dangling "Calibrated to  ".
      await pumpLabel(
        tester,
        subtensionOrigin: 'published_spec',
        calibrationProvenance: const {
          'manufacturer': '',
          'reticle_name': '   ',
        },
      );
      expect(
        find.text('Calibrated to manufacturer specification'),
        findsOneWidget);

      // Case 4d: provenance has only one of the two keys.
      await pumpLabel(
        tester,
        subtensionOrigin: 'published_spec',
        calibrationProvenance: const {
          'manufacturer': 'Burris Optics',
        },
      );
      expect(
        find.text('Calibrated to manufacturer specification'),
        findsOneWidget);
    });

    testWidgets(
        'Null subtensionOrigin renders the legacy back-compat string',
        (tester) async {
      await pumpLabel(tester); // both null
      expect(
        find.text('LoadOut Original — Interoperability Calibration'),
        findsOneWidget,
      );
      // Legacy tooltip text is preserved verbatim too — back-compat
      // call sites that haven't migrated yet should keep their old
      // tooltip wording rather than silently flipping to a new copy.
      expect(
        findTooltipMessage(tester),
        'LoadOut original artwork, calibrated to match real-world scope '
        'subtensions for accuracy. The reticle name and design are '
        'LoadOut-original.',
      );
    });

    test(
      'resolveTemplate also exposes the resolution without a render',
      () {
        // Pure-Dart resolution path so callers can compute the label
        // without spinning up a widget tester. Kept symmetric with the
        // widget output above so any future copy edit must touch both
        // the widget and the smoke-test assertion below.
        expect(
          ReticleInteroperabilityLabel.resolveTemplate(
            subtensionOrigin: 'original',
            calibrationProvenance: null,
          ).label,
          'LoadOut Original',
        );
        expect(
          ReticleInteroperabilityLabel.resolveTemplate(
            subtensionOrigin: 'public_domain',
            calibrationProvenance: null,
          ).label,
          'Public Domain Reticle',
        );
        expect(
          ReticleInteroperabilityLabel.resolveTemplate(
            subtensionOrigin: 'published_spec',
            calibrationProvenance: const {
              'manufacturer': 'Leupold & Stevens, Inc.',
              'reticle_name': 'CDS-ZL BR',
            },
          ).label,
          'Calibrated to Leupold & Stevens, Inc. CDS-ZL BR',
        );
        expect(
          ReticleInteroperabilityLabel.resolveTemplate(
            subtensionOrigin: 'unknown_value_we_dont_recognize',
            calibrationProvenance: null,
          ).label,
          // Unknown origins fall through to the 'original' template so
          // we can never render an empty caption.
          'LoadOut Original',
        );
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────
  // §7.7 catalog data-integrity smoke test
  // ────────────────────────────────────────────────────────────────────
  group('reticles.json catalog data integrity', () {
    test(
      'every published_spec reticle has a non-empty manufacturer + '
      'reticle_name in calibration_provenance',
      () {
        final file = File('assets/seed_data/reticles.json');
        expect(file.existsSync(), isTrue,
            reason: 'assets/seed_data/reticles.json must exist at the '
                'repo root for this test to read it.');
        final raw = file.readAsStringSync();
        final decoded = json.decode(raw);
        // The seed file is a flat top-level array of reticle objects.
        expect(decoded, isA<List<dynamic>>(),
            reason: 'reticles.json should be a JSON array of reticle '
                'rows; got ${decoded.runtimeType} instead. If the seed '
                'shape changed, update this test to walk the new root.');
        final items = decoded as List<dynamic>;

        final publishedSpec = items.where((row) {
          if (row is! Map) return false;
          return row['subtension_origin'] == 'published_spec';
        }).toList();

        // Sanity: we expect at least one published_spec row to exercise
        // the fallback gate. If the catalog ever drops to zero
        // published_spec rows we still want the test to remain green
        // (so we don't fail a future "we removed all the calibrated
        // reticles" commit), but log a soft notice via expect.
        expect(publishedSpec, isNotEmpty,
            reason: "Expected at least one 'published_spec' reticle in "
                'the catalog (Phase 6 ships 10).');

        for (final row in publishedSpec.cast<Map>()) {
          final id = row['id'];
          final provenance = row['calibration_provenance'];
          expect(provenance, isA<Map>(),
              reason: "Reticle '$id' carries subtension_origin "
                  "'published_spec' but its calibration_provenance is "
                  '${provenance == null ? 'null' : provenance.runtimeType}. '
                  'Every published_spec row must have a populated '
                  'calibration_provenance block (CLAUDE.md § 30 rule 3).');

          final provMap = provenance as Map;
          final manufacturer = provMap['manufacturer'];
          final reticleName = provMap['reticle_name'];

          expect(manufacturer, isA<String>(),
              reason: "Reticle '$id' calibration_provenance.manufacturer "
                  'must be a string.');
          expect((manufacturer as String).trim(), isNotEmpty,
              reason: "Reticle '$id' calibration_provenance.manufacturer "
                  'is empty / whitespace-only; the disclaimer would '
                  'fall through to the generic name-free label.');

          expect(reticleName, isA<String>(),
              reason: "Reticle '$id' calibration_provenance.reticle_name "
                  'must be a string.');
          expect((reticleName as String).trim(), isNotEmpty,
              reason: "Reticle '$id' calibration_provenance.reticle_name "
                  'is empty / whitespace-only; the disclaimer would '
                  'fall through to the generic name-free label.');
        }
      },
    );
  });
}
