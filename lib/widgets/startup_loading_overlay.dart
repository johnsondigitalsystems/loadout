// FILE: lib/widgets/startup_loading_overlay.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Provides [StartupLoadingScreen], a full-screen branded loading view: the
// LoadOut target/crosshair emblem (assets/branding/loadout_logo.png) slowly
// rotating on the app's dark gunmetal background. It is a drop-in
// replacement for the bare `Scaffold(body: Center(child:
// CircularProgressIndicator()))` placeholders that briefly show during the
// two cold-start async gaps in `lib/app.dart` (reading the disclaimer-
// accepted pref in `_DisclaimerGate`, and hydrating `BiometricService` in
// `_AuthGate`). A continuous [RotationTransition] driven by a repeating
// [AnimationController] spins the emblem; the controller is disposed with
// the State. No ballistics inputs flow through this widget — it is pure
// presentation (CLAUDE.md §0: this file has zero ballistics-affecting
// fields).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The post-launch / post-login init delay was rendering a generic Material
// spinner, which reads as unbranded and slightly broken for the half-second
// it shows on every cold start. A precision-tool audience notices that. A
// rotating scope-reticle emblem turns the unavoidable async gap into a
// brand moment that fits the product (a reticle settling onto target). If
// this file were deleted, `_DisclaimerGate` and `_AuthGate` would each have
// to re-inline an ad-hoc loading widget and the branded treatment would
// drift out of sync between the two sites — centralizing it here keeps the
// startup look identical wherever a brief async gate exists.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The asset is pre-centered and square (autocropped + padded during
//     rasterization) specifically so the rotation pivot — the widget's
//     center — coincides with the emblem's visual center. An off-center
//     emblem would visibly wobble as it spins. Do not swap the asset for a
//     non-centered crop without re-centering it.
//   * `..repeat()` runs forever; the [AnimationController] MUST be disposed
//     or it leaks a ticker past the (very short-lived) loading screen.
//     Because these gates rebuild into the real UI within ~50–300 ms, a
//     leaked ticker would be subtle but real — hence the explicit dispose.
//   * The rotating image is wrapped in a [RepaintBoundary]. The bitmap is
//     static; only its transform changes each frame. The boundary keeps the
//     per-frame raster work to the logo layer instead of repainting the
//     whole screen subtree behind it.
//   * Linear (not eased) rotation is deliberate — a steady mechanical sweep
//     reads as an instrument, an ease-in/out reads as a toy. Keep
//     `Curves.linear`.
//   * No visible text. The emblem alone is the loading affordance; a
//     "Loading…" label would just be churn to localize for a screen that
//     shows for a few hundred milliseconds. Accessibility is covered by a
//     single [Semantics] node instead.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * lib/app.dart — `_DisclaimerGate.build` (the `_loading` branch) and
//     `_AuthGate.build` (the `!biometric.isHydrated` branch) both return
//     `const StartupLoadingScreen()`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * Starts a repeating [AnimationController] ticker while mounted
//     (disposed with the State). Decodes one bundled PNG asset
//     (assets/branding/loadout_logo.png) on first build. No network, no
//     disk writes, no database, no preferences.

import 'package:flutter/material.dart';

/// Full-screen branded startup loading view — a slowly rotating LoadOut
/// emblem on the dark theme background. Const-constructible so the call
/// sites in `lib/app.dart` can return `const StartupLoadingScreen()`.
class StartupLoadingScreen extends StatefulWidget {
  const StartupLoadingScreen({super.key});

  @override
  State<StartupLoadingScreen> createState() => _StartupLoadingScreenState();
}

class _StartupLoadingScreenState extends State<StartupLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// One full revolution every 3.6 s. Slow enough to read as a deliberate
  /// instrument sweep, fast enough that the ~0.05–0.3 s the screen is
  /// actually visible still shows obvious motion.
  static const _revolution = Duration(milliseconds: 3600);

  /// Logical size of the emblem. Large enough to be unmistakably the brand
  /// mark, small enough to read as a loading state rather than a splash.
  static const _logoSize = 104.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _revolution)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Bare Scaffold inherits the dark theme's gunmetal
      // scaffoldBackgroundColor. The app forces ThemeMode.dark
      // (lib/app.dart), and the brass line-art emblem is designed to read
      // on that surface — so we deliberately do NOT hardcode a colour here;
      // it tracks the theme.
      body: Center(
        child: Semantics(
          label: 'Loading',
          container: true,
          child: RepaintBoundary(
            child: RotationTransition(
              // Stable key so the widget regression test can target THIS
              // emblem transition unambiguously — Material's own widget
              // tree (route/scaffold machinery) also contains
              // RotationTransitions, so a bare `find.byType` is ambiguous.
              key: const ValueKey('startupLogoRotation'),
              turns: _controller,
              child: Image.asset(
                'assets/branding/loadout_logo.png',
                width: _logoSize,
                height: _logoSize,
                // Bundled square asset; no runtime scaling surprises.
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
