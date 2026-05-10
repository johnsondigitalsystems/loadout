// FILE: lib/screens/resources/resources_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Top-level "Resources" directory — the home for read-only reference
// data screens that aren't user data and aren't settings. Reference
// data is the catalog material LoadOut ships with (SAAMI cartridge
// specs today; potentially Reloading Guide, Powder Burn-Rate
// Charts, and similar in future releases). Settings was the wrong
// home for these — they aren't preferences, they're reference
// material — so they moved here.
//
// Each tile pushes its destination via a standard `MaterialPageRoute`.
// The screen mirrors the visual language of the Settings directory
// (`_CategoryTile` rows with icon + title + subtitle + chevron) so
// users navigate consistently across the two.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// SAAMI Specs were originally a bottom-nav tab, then moved into
// Settings to declutter. Settings became cluttered too, and SAAMI
// reads as a *reference resource* rather than a *preference* — the
// user looks up cartridge dimensions, they don't configure
// anything. Splitting Resources out from Settings gives reference
// material a coherent home and keeps Settings focused on
// preferences (account, app prefs, privacy, sync).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Trivial today (one tile). The discipline is keeping it that way:
// every new resource gets its own `_ResourceTile` row, with the
// same shape as Settings tiles. Resist any temptation to add
// *behaviour* to this screen — search, filtering, etc. — until at
// least four resources live here. With one tile, anything beyond a
// directory list is over-engineered. The point is that users find
// SAAMI Specs in a sane place, not that they discover it through a
// rich UI.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/home/home_screen.dart — `_MainDrawer` pushes
//   `ResourcesScreen()` from the new "Resources" tile.
// - lib/screens/how_it_works/how_it_works_screen.dart — the SAAMI
//   topic CTA pushes here so the user lands on the same screen the
//   drawer surface points to.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None — just a directory of MaterialPageRoute pushes.

import 'package:flutter/material.dart';

import '../saami/saami_screen.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: SafeArea(
        child: ListView(
          children: [
            _ResourceTile(
              icon: Icons.straighten_outlined,
              title: 'SAAMI Specs',
              subtitle:
                  'Reference dimensions and pressures for every '
                  'cartridge in the SAAMI catalog.',
              destinationBuilder: (_) => const SaamiScreen(),
            ),
            // Future resources land here as they ship. Examples:
            //   * Reloading Guide (text reference)
            //   * Powder Burn-Rate Chart
            //   * Cartridge cross-reference / wildcat-parent map
            // Add a new `_ResourceTile` row above this comment when
            // a new screen is ready; the layout takes any number.
          ],
        ),
      ),
    );
  }
}

/// Re-usable directory row for the Resources screen. Same shape as
/// the Settings directory's `_CategoryTile` so users navigate
/// between the two screens with no friction.
class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destinationBuilder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder destinationBuilder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: destinationBuilder),
        );
      },
    );
  }
}
