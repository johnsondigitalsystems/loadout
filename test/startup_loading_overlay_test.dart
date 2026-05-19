// FILE: test/startup_loading_overlay_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget regression test for [StartupLoadingScreen]
// (lib/widgets/startup_loading_overlay.dart) — the branded rotating-emblem
// loading view that replaced the two bare CircularProgressIndicator
// placeholders in lib/app.dart. Asserts the structural contract that the
// app.dart gates depend on: it renders the branded asset, the emblem is
// driven by a continuously-running RotationTransition, it exposes a single
// 'Loading' semantics node, and it tears its ticker down cleanly when the
// gate rebuilds into the real UI.
//
// ============================================================================
// WHY IT EXISTS
// ============================================================================
// The screen is shown on every cold start, so a regression here (no
// rotation, leaked ticker, wrong asset path, missing a11y node) is
// user-visible on launch and would otherwise only be caught by eyeballing
// the app. The dispose assertion specifically guards the "..repeat() runs
// forever; the controller MUST be disposed" footgun called out in the
// widget's header.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure widget pump; no network, disk, db, or prefs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/widgets/startup_loading_overlay.dart';

void main() {
  testWidgets('renders the branded emblem asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartupLoadingScreen()));

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, 'assets/branding/loadout_logo.png');
  });

  testWidgets('emblem is driven by a RotationTransition that actually turns',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartupLoadingScreen()));

    // Target THIS emblem transition by key — Material's own tree also
    // contains RotationTransitions, so `find.byType` would be ambiguous.
    final rt = tester.widget<RotationTransition>(
      find.byKey(const ValueKey('startupLogoRotation')),
    );
    final turns = rt.turns;
    final t0 = turns.value;

    // Advance partway through a revolution; a repeating controller must
    // have moved. (Asserting motion, not an exact value — exact values
    // would be brittle against any future duration tweak.)
    await tester.pump(const Duration(milliseconds: 900));
    expect(turns.value, isNot(equals(t0)),
        reason: 'RotationTransition did not advance — controller is not '
            'repeating, so the emblem would sit static on every cold start.');
  });

  testWidgets('exposes a single Loading semantics node', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartupLoadingScreen()));

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('disposes its ticker cleanly when the gate rebuilds away',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartupLoadingScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    // Simulate the gate rebuilding into the real UI (the actual lifecycle
    // in lib/app.dart). A leaked AnimationController ticker would trip the
    // test binding's pending-timer / disposed-ticker assertions here.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(StartupLoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
