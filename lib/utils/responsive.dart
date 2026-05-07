// FILE: lib/utils/responsive.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Tiny set of breakpoint helpers used throughout the app to choose between
// phone, tablet, and desktop layouts. The goal is to keep all the "is this
// a wide screen?" checks in one place so individual screens can read
// `Breakpoints.isPhone(context)` instead of hard-coding pixel cutoffs.
//
// Phone   : width  <  600
// Tablet  : 600   <= width < 1024
// Desktop : width >= 1024
//
// These map cleanly to:
//   - phone   → bottom-nav layout
//   - tablet  → NavigationRail (icons only, narrow)
//   - desktop → NavigationRail extended (icons + labels)
//
// `widthClass(context)` returns the enum form for switch statements.
//
// ============================================================================
// USAGE
// ============================================================================
//
//   if (Breakpoints.isPhone(context)) {
//     return const _PhoneLayout();
//   }
//   return const _WideLayout();
//
// Always read width from `MediaQuery.of(context).size.width` rather than
// `LayoutBuilder` constraints when you want the full screen width — a
// `LayoutBuilder` inside a master-detail split would only see one pane's
// width, which is not the same thing.

import 'package:flutter/widgets.dart';

/// Logical width buckets that drive layout decisions across the app.
enum WidthClass { phone, tablet, desktop }

/// Pixel breakpoints used by the responsive layout helpers.
class Breakpoints {
  const Breakpoints._();

  /// Width (in logical pixels) at and above which we treat the device as
  /// a tablet rather than a phone. iPad mini in portrait is ~744 px, so
  /// the 600 cutoff comfortably catches every iPad orientation and the
  /// vast majority of Android tablets, while leaving every iPhone in
  /// the phone bucket.
  static const double tablet = 600;

  /// Width (in logical pixels) at and above which we treat the surface
  /// as desktop-class — full NavigationRail labels, side-by-side detail,
  /// etc. iPad Pro 12.9" landscape is 1366 px; a typical macOS window
  /// hovers at 1280–1440 px. 1024 catches both cleanly.
  static const double desktop = 1024;

  /// True when the current screen width is below the tablet cutoff.
  static bool isPhone(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < tablet;

  /// True when the current screen width sits in the tablet range
  /// (>= 600 and < 1024).
  static bool isTablet(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    return w >= tablet && w < desktop;
  }

  /// True when the current screen width is at or above the desktop cutoff.
  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= desktop;

  /// True when the screen is wide enough to use the desktop-class
  /// layout (NavigationRail, master-detail, multi-column forms).
  /// Equivalent to `!isPhone(ctx)`.
  static bool isWide(BuildContext ctx) => !isPhone(ctx);

  /// Returns the [WidthClass] for the current context. Convenient when
  /// you want to switch on the bucket rather than chain three boolean
  /// helpers.
  static WidthClass widthClass(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w < tablet) return WidthClass.phone;
    if (w < desktop) return WidthClass.tablet;
    return WidthClass.desktop;
  }
}
