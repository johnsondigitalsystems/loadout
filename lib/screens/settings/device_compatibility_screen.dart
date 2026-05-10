// FILE: lib/screens/settings/device_compatibility_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Renders the user-facing list of "feature → OS-version requirement →
// what you're on" rows so a user on an older device can audit which
// hardware-linked Pro features are unavailable to them, without
// surprises.
//
// Layout (top → bottom):
//
//   1. Device-info banner — "You're On Android 10". Calm, factual.
//   2. Section header — "Available On This Device" — lists the rows
//      that report `isAvailable == true`. Hidden if zero rows pass.
//   3. Section header — "Requires a Newer OS Version" — lists the
//      rows that report `isAvailable == false`. Hidden if zero rows
//      fail. Each row has the feature name, the requirement
//      ("Requires Android 11 or newer (you're on Android 10)"), and a
//      one-sentence description of what the feature does.
//   4. Footer — "Why The OS Version Matters" expansion that explains
//      that LoadOut deliberately keeps the OS floor low (Android 10 /
//      iOS 15) so the install base stays wide, and that the gates
//      reflect real platform / firmware limitations, not licensing.
//
// The screen is read-only — there are no toggles, no upgrade CTAs.
// The user knows whether they want a newer phone; we don't lecture.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Pattern C of the device-compatibility UX rollout: hide hardware-
// linked features on devices that can't support them, AND give the
// user a single screen that documents "what your device supports."
// The alternative (silent gating) burns trust — a user on Android 10
// who buys Pro and discovers Bluetooth devices won't pair would
// reasonably feel mis-sold. This screen exists so that disclosure
// is reachable from the paywall footer, the Settings directory, and
// the onboarding privacy slide, BEFORE the user makes a purchase
// decision.
//
// The data model is owned by `DeviceCompatibilityService`; this
// screen is purely the renderer.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * **Rows are calm, not alarming.** No red icons, no "upgrade to
//     unlock" CTAs, no scare copy. The audience is precision shooters
//     who appreciate factual information; the visual language matches
//     the Internal Ballistics Calculator's disclaimer banner — a
//     subtle yellow-tint card, no shouting.
//   * **The screen MUST hide the upgrade path entirely.** No "Open
//     paywall" button, no "Tap here to subscribe." That's a deliberate
//     UX choice: this screen is the answer to "what does my device
//     support?", not "what should I buy?" The paywall has its own
//     copy.
//   * **Empty state matters.** A modern user (Android 12+ on a
//     handset, iOS 15+ on iPhone) who navigates here directly sees
//     a calm "All Pro features run on this device" message. We do
//     not want them to feel they wandered into something for older
//     devices only.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/settings/settings_screen.dart — pushes this screen
//   from the conditional "Device Compatibility" tile.
// - lib/screens/paywall/paywall_screen.dart — pushes this screen
//   from the footer "What Does My Device Support?" link.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure render off `DeviceCompatibilityService`, which is itself
// a one-shot snapshot read at app startup.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/device_compatibility_service.dart';

class DeviceCompatibilityScreen extends StatelessWidget {
  const DeviceCompatibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = context.read<DeviceCompatibilityService>();
    final available = svc.gatedFeatures.where((f) => f.isAvailable).toList();
    final blocked = svc.gatedFeatures.where((f) => !f.isAvailable).toList();
    // "All fine" = nothing is blocked. Modern Android (API 31+) reports
    // every feature as available; iOS / macOS / web report no
    // gated-features list at all. Both states show the same empty-state
    // card so the user reads "your device supports everything," not
    // "you have several available features."
    final allFine = blocked.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Device Compatibility')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _DeviceInfoBanner(osDisplay: svc.profile.osDisplay),
            const SizedBox(height: 16),
            if (allFine) ...[
              _AllFineCard(),
            ] else ...[
              _SectionHeader('Requires a Newer OS Version'),
              for (final f in blocked) _FeatureRow(feature: f),
              const SizedBox(height: 16),
              if (available.isNotEmpty) ...[
                _SectionHeader('Available on This Device'),
                for (final f in available) _FeatureRow(feature: f),
                const SizedBox(height: 16),
              ],
            ],
            const SizedBox(height: 8),
            _WhyOsVersionMatters(theme: theme),
          ],
        ),
      ),
    );
  }
}

/// Compact "you're on …" card at the top of the screen. Calm tone:
/// states the OS version, no judgment.
class _DeviceInfoBanner extends StatelessWidget {
  const _DeviceInfoBanner({required this.osDisplay});
  final String osDisplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.smartphone_outlined,
                color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're On",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    osDisplay,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header above each row group. Matches the small-caps
/// styling used elsewhere in Settings (see WatchSettingsScreen).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One feature row. Available rows have a calm primary-tint icon;
/// blocked rows have a softer onSurfaceVariant icon (no red, no
/// danger styling — the user already knows what they're on).
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});
  final GatedFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = feature.isAvailable
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final icon = feature.isAvailable
        ? Icons.check_circle_outline
        : Icons.lock_outline;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.requirement,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    feature.shortDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Everything works on your device" empty state — shown to modern-
/// device users who navigated here directly. Phrased so the user
/// doesn't think they wandered into something for older devices only.
class _AllFineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.verified_outlined,
                color: theme.colorScheme.primary, size: 36),
            const SizedBox(height: 12),
            Text(
              'All Features Run on This Device',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your device meets every OS-version requirement LoadOut '
              'has. There are no hardware-linked features hidden by '
              'your operating system.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Expansion tile at the bottom that explains LoadOut's stance on
/// older OS versions. Calm, factual, non-defensive.
class _WhyOsVersionMatters extends StatelessWidget {
  const _WhyOsVersionMatters({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        title: Text(
          'Why the OS Version Matters',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Icon(Icons.info_outline,
            color: theme.colorScheme.primary, size: 22),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'LoadOut deliberately keeps its OS floor low — Android 10 '
            'and iOS 15 — so the install base stays wide. The gates '
            'above reflect real platform or firmware limitations, not '
            'licensing decisions:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _ReasonRow(
            theme: theme,
            text: 'Bluetooth Devices need the modern '
                'BLUETOOTH_SCAN / BLUETOOTH_CONNECT permissions '
                "introduced in Android 12. Earlier versions can scan "
                'with location permission, but OEM stack quality '
                'varies — we hide the affordance rather than ship '
                'a feature that mis-pairs.',
          ),
          const SizedBox(height: 8),
          _ReasonRow(
            theme: theme,
            text: 'Wear OS Watch Pairing requires Wear OS 3, which '
                'has a host requirement of Android 11. Compose for '
                'Wear OS will not load on older hosts.',
          ),
          const SizedBox(height: 8),
          _ReasonRow(
            theme: theme,
            text: 'Watch Motion Sensors depend on the same Wear OS '
                "host requirements; without the watch link, there's "
                'no sensor pipeline to read.',
          ),
          const SizedBox(height: 12),
          Text(
            "Manual entry is always free. None of the gated features "
            "are required to track loads, firearms, brass lots, or "
            "to use the ballistics calculator.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bullet-style reason row with a subtle dot, used inside the
/// "Why the OS version matters" expansion.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.theme, required this.text});
  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.fiber_manual_record,
            size: 8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
