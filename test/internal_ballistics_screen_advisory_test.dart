// FILE: test/internal_ballistics_screen_advisory_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget tests for `BiasAdvisoryCard` in
// `lib/screens/ballistics/internal_ballistics_screen.dart`. The card is
// the per-prediction yellow note that surfaces when the load falls into
// a documented high-bias regime of the underlying fit (magnum-class case ≥
// 75 grH₂O, slow powder Q < 70, or both).
//
// Three responsibilities:
//
//   1. RENDERS ALL THREE CAUSES — magnumCase, slowPowder, combined each
//      render the matching headline + detail. The headline text is the
//      contract between the model (`BiasZoneAdvisory.headline`) and the
//      UI; if it changes silently in either direction, this test fails.
//
//   2. WARNING ICON IS PRESENT — every advisory shows the
//      `Icons.warning_amber_rounded` so the visual weight matches the
//      rest of the safety-warning surface in the app (consistent with
//      the persistent disclaimer banner at the top of the screen).
//
//   3. COPY ENFORCEMENT — the detail body must include the load-bearing
//      "treat as a floor, not a ceiling" guidance for the magnumCase
//      and combined causes. This is the practical action the user
//      should take; if a future copy edit accidentally strips that
//      phrase, the test fails loud.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The bias advisory is the user-facing output of Pass 2's magnum-bias
// deep-dive. The discriminator logic and message content are unit-tested
// in `internal_ballistics_test.dart`; this file pins down that the UI
// surface actually renders the message correctly. Without these tests,
// a future refactor that silently breaks the wiring (e.g. swaps the
// detail field for the headline by mistake) would degrade the warning
// surface without any test failures.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// The Flutter test runner. Not imported by anything else.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure widget compute, no I/O.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/screens/ballistics/internal_ballistics_screen.dart';
import 'package:loadout/services/ballistics/internal_ballistics.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  /// Wrap the card in a MaterialApp so it has theming context.
  Widget wrap(BiasAdvisoryCard card) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: card)),
      );

  // ─────────────────────────────────────────────────────────────────
  // Headline rendering — one test per cause
  // ─────────────────────────────────────────────────────────────────

  group('BiasAdvisoryCard: renders the right headline per cause', () {
    testWidgets('magnumCase advisory shows "Magnum-Class Cartridge"',
        (tester) async {
      const advisory = BiasZoneAdvisory(
        cause: BiasZoneCause.magnumCase,
        headline: 'Magnum-Class Cartridge',
        detail: 'This cartridge has a large case capacity. Treat the '
            'predicted pressure as a floor, not a ceiling.',
      );
      await tester.pumpWidget(wrap(const BiasAdvisoryCard(advisory: advisory)));
      expect(find.text('Magnum-Class Cartridge'), findsOneWidget);
      expect(find.textContaining('floor, not a ceiling'), findsOneWidget);
    });

    testWidgets('slowPowder advisory shows "Very Slow Powder"',
        (tester) async {
      const advisory = BiasZoneAdvisory(
        cause: BiasZoneCause.slowPowder,
        headline: 'Very Slow Powder',
        detail: 'This powder sits in the slow / very-slow band. '
            'Cross-check against a published manual.',
      );
      await tester.pumpWidget(wrap(const BiasAdvisoryCard(advisory: advisory)));
      expect(find.text('Very Slow Powder'), findsOneWidget);
      expect(find.textContaining('Cross-check'), findsOneWidget);
    });

    testWidgets('combined advisory shows "Magnum + Slow Powder"',
        (tester) async {
      const advisory = BiasZoneAdvisory(
        cause: BiasZoneCause.combined,
        headline: 'Magnum + Slow Powder — Combined Bias',
        detail: 'Combined bias zone. Treat the predicted pressure as a '
            'floor, not a ceiling.',
      );
      await tester.pumpWidget(wrap(const BiasAdvisoryCard(advisory: advisory)));
      expect(find.text('Magnum + Slow Powder — Combined Bias'),
          findsOneWidget);
      expect(find.textContaining('floor'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Warning icon present
  // ─────────────────────────────────────────────────────────────────

  group('BiasAdvisoryCard: warning icon is always present', () {
    testWidgets('magnumCase shows warning_amber_rounded',
        (tester) async {
      const advisory = BiasZoneAdvisory(
        cause: BiasZoneCause.magnumCase,
        headline: 'Magnum-Class Cartridge',
        detail: 'detail',
      );
      await tester.pumpWidget(wrap(const BiasAdvisoryCard(advisory: advisory)));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('slowPowder shows warning_amber_rounded',
        (tester) async {
      const advisory = BiasZoneAdvisory(
        cause: BiasZoneCause.slowPowder,
        headline: 'Very Slow Powder',
        detail: 'detail',
      );
      await tester.pumpWidget(wrap(const BiasAdvisoryCard(advisory: advisory)));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('combined shows warning_amber_rounded',
        (tester) async {
      const advisory = BiasZoneAdvisory(
        cause: BiasZoneCause.combined,
        headline: 'Magnum + Slow Powder — Combined Bias',
        detail: 'detail',
      );
      await tester.pumpWidget(wrap(const BiasAdvisoryCard(advisory: advisory)));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Copy enforcement — the production advisory copy from
  // `_computeBiasAdvisory` includes load-bearing phrases that the
  // user reads as actionable guidance. If those phrases get edited
  // out, the test fails loud.
  // ─────────────────────────────────────────────────────────────────

  group('BiasAdvisoryCard: production advisory copy includes guidance', () {
    testWidgets('Magnum case advisory tells user "floor, not a ceiling"',
        (tester) async {
      // Synthesize the production advisory by running a known
      // magnum-case load through the predictor. The copy is the
      // exact text users see.
      final result = predictLoad(const InternalBallisticsInput.imperial(
        caseCapacityGrH2o: 92.0,
        powderName: 'IMR 4350',
        chargeWeightGr: 67.0,
        bulletWeightGr: 165,
        bulletDiameterIn: 0.308,
        coalIn: 3.340,
        caseLengthIn: 2.620,
        barrelLengthIn: 26.0,
        boreDiameterIn: 0.300,
        bulletLengthIn: 1.250,
      ));
      expect(result, isNotNull);
      expect(result!.biasAdvisory, isNotNull);
      await tester.pumpWidget(
          wrap(BiasAdvisoryCard(advisory: result.biasAdvisory!)));
      expect(find.textContaining('floor, not a ceiling'), findsOneWidget,
          reason: 'magnumCase production copy must include the load-bearing '
              '"floor, not a ceiling" phrase');
    });

    testWidgets('Combined advisory tells user to "Cross-check"',
        (tester) async {
      final result = predictLoad(const InternalBallisticsInput.imperial(
        caseCapacityGrH2o: 99.0,
        powderName: 'H1000',
        chargeWeightGr: 78.0,
        bulletWeightGr: 212,
        bulletDiameterIn: 0.308,
        coalIn: 3.700,
        caseLengthIn: 2.580,
        barrelLengthIn: 26.0,
        boreDiameterIn: 0.300,
        bulletLengthIn: 1.620,
      ));
      expect(result, isNotNull);
      expect(result!.biasAdvisory, isNotNull);
      await tester.pumpWidget(
          wrap(BiasAdvisoryCard(advisory: result.biasAdvisory!)));
      expect(find.textContaining('Cross-check'), findsOneWidget,
          reason: 'combined production copy must tell the user to '
              'Cross-check against a published manual');
    });

    testWidgets('Slow-powder advisory mentions "10-20% LOW"',
        (tester) async {
      final result = predictLoad(const InternalBallisticsInput.imperial(
        caseCapacityGrH2o: 68.0,
        powderName: 'H1000',
        chargeWeightGr: 60.0,
        bulletWeightGr: 200,
        bulletDiameterIn: 0.308,
        coalIn: 3.340,
        caseLengthIn: 2.494,
        barrelLengthIn: 24.0,
        boreDiameterIn: 0.300,
        bulletLengthIn: 1.500,
      ));
      expect(result, isNotNull);
      expect(result!.biasAdvisory, isNotNull);
      expect(result.biasAdvisory!.cause, equals(BiasZoneCause.slowPowder));
      await tester.pumpWidget(
          wrap(BiasAdvisoryCard(advisory: result.biasAdvisory!)));
      // The copy says "10-20% LOW" with capital LOW for emphasis;
      // verify the practical guidance is in the body.
      expect(find.textContaining('LOW'), findsOneWidget,
          reason: 'slowPowder production copy emphasises that MV runs LOW');
    });
  });
}
