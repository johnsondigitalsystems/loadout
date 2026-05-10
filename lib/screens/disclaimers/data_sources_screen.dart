// FILE: lib/screens/disclaimers/data_sources_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Renders the "Data Sources & Credits" screen — a respectful, user-facing
// thank-you note that doubles as IP coverage. It opens with an
// appreciative paragraph, a clear non-affiliation statement, and a quiet
// support email for corrections. Below the intro, a stack of category
// cards lists every brand whose published data we ship in the on-device
// reference catalog: powders, primers, brass, bullets, cartridge specs
// (SAAMI / CIP), firearms, optics, firearm parts, and manufactured
// ammunition. Two extra cards cover ballistic-math literature and the
// open-source software the app is built on.
//
// Each brand list is a `const` constant compiled into the screen — we
// intentionally do NOT hit the SQLite catalog or the asset bundle at
// render time. The lists are generated once at build time by reading
// the `assets/seed_data/*.json` files, alphabetized, and pasted in
// here. Re-running the snapshot is a manual step the next time we add
// or remove a brand from the catalog.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// LoadOut's marketing posture says "we use real component data from
// real companies." This screen is the user-facing acknowledgment that
// makes that claim concrete: every brand whose published numbers
// underpin a recipe in LoadOut shows up here, alphabetized, with a
// short note describing what we use it for. It also surfaces the
// non-affiliation statement and a single contact channel
// (`support@loadoutapp.com`) for any company that wants a correction
// or removal.
//
// Splitting credits out of the disclaimer / privacy screens keeps each
// surface narrow. The disclaimer is a binding consent gate; the
// privacy screen is about user data; this screen is a thank-you note
// to the catalog providers. Different audiences, different tone.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Hardcoding the brand lists is a deliberate choice. Reading the
//     SQLite catalog at runtime would (a) cost a frame on every open,
//     (b) couple the credits surface to seed-loader timing on first
//     launch, and (c) fail silently if a future migration renames a
//     manufacturer. A snapshot pasted in here is honest about its
//     provenance and easy to diff in PR review.
//   * Tone is load-bearing. The screen is a thank-you note, not a
//     legal CYA paragraph. Read every sentence and ask: "Would a
//     PR / brand person at the named company read this and feel
//     respected?" If the answer is no, rewrite warmer.
//   * The optics card has an extra reticle paragraph because LoadOut
//     does NOT reproduce trademarked / licensed reticle designs. The
//     card explicitly names Horus Vision LLC so a Horus PR person
//     reading it sees we know who owns the IP. The "Find by Scope"
//     helper in the firearm form already routes brand-specific
//     reticles to the closest LoadOut archetype with the same
//     hold-off math — this is the screen where we say so out loud.
//   * No emojis on this screen. The reloader audience reads emoji
//     as marketing tone rather than care; respect is communicated
//     through plain text and accurate attribution.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/screens/settings/settings_screen.dart` — the Settings
//     directory pushes `DataSourcesScreen()` from the new
//     "Data Sources & Credits" tile, between "Privacy & Data" and
//     "Help & Support".
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure Dart + Flutter widgets. No DB reads, no network, no
// SharedPreferences, no platform channels. The constant tables baked
// into the file are the only data source.

import 'package:flutter/material.dart';

class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Data Sources & Credits')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _IntroBlock(theme: theme),
            const SizedBox(height: 16),
            for (final spec in _kCategories)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CategoryCard(spec: spec),
              ),
            const _OpticsAddendumCard(),
            const SizedBox(height: 14),
            const _BallisticsMathCard(),
            const SizedBox(height: 14),
            const _OpenSourceCard(),
            const SizedBox(height: 24),
            Text(
              'Thank you to every company, designer, and contributor '
              'whose work made LoadOut possible.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Intro ───────────────────────

class _IntroBlock extends StatelessWidget {
  const _IntroBlock({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LoadOut's component catalog is built from public manufacturer "
          'data — load tables, ballistic coefficients, brass dimensions, '
          "scope specs, and more. We're grateful to every company below "
          'for publishing this information openly. Their work made an '
          'honest reloading and ballistics tool possible.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'All product names, model designations, and specifications '
          'belong to their respective owners. LoadOut is not affiliated '
          'with, sponsored by, or endorsed by any company listed here. '
          "Their data is shipped solely to help shooters identify the "
          "components they're using.",
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'If you represent any company below and would like a '
          'correction, removal, or change in attribution, please email '
          'support@loadoutapp.com — we will respond promptly and '
          'respectfully.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

// ─────────────────────── Categories ───────────────────────

/// Pure-data spec for a category card. A header, an intro paragraph,
/// the alphabetized list of brand names, and a footer line. Optics
/// gets a custom `_OpticsAddendumCard` immediately after this card so
/// its reticle paragraph stays close to the brand list.
class _CategorySpec {
  const _CategorySpec({
    required this.heading,
    required this.intro,
    required this.brands,
    required this.footer,
  });

  final String heading;
  final String intro;
  final List<String> brands;
  final String footer;
}

const String _kCatalogFooter =
    'Their published data is the foundation of every recipe in LoadOut. '
    "We never ship reloading data we couldn't trace to a manufacturer's "
    'published source.';

/// Brand snapshots compiled from `assets/seed_data/*.json` on
/// 2026-05-09. To refresh: open the relevant JSON, pull each
/// `manufacturer.name` (or top-level `manufacturer` field for
/// manufactured ammo), dedupe + alphabetize, paste in.
const List<_CategorySpec> _kCategories = [
  _CategorySpec(
    heading: 'Powder',
    intro:
        'Burn rates, suggested loads, and load tables published by:',
    brands: [
      'Accurate',
      'Alliant',
      'Hodgdon',
      'IMR',
      'Lovex / Sellier & Bellot',
      'Norma',
      'Ramshot',
      "Shooter's World",
      'Vihtavuori',
      'Winchester',
    ],
    footer: _kCatalogFooter,
  ),
  _CategorySpec(
    heading: 'Primers',
    intro:
        'Primer dimensions, sensitivity tiers, and magnum-flag data '
        'published by:',
    brands: [
      'CCI',
      'Federal',
      'Fiocchi',
      'Ginex',
      'Murom',
      'Remington',
      'RWS',
      'Sellier & Bellot',
      'Tula',
      'Vihtavuori',
      'Winchester',
      'Wolf',
    ],
    footer: _kCatalogFooter,
  ),
  _CategorySpec(
    heading: 'Brass',
    intro:
        'Case dimensions, caliber availability, and tier classifications '
        'published by:',
    brands: [
      'ADG / Atlas Development Group',
      'Alpha Munitions',
      'Capstone / Berger',
      'Federal',
      'Hornady',
      'IMI / Israel Military Industries',
      'Lapua',
      'Norma',
      'Nosler',
      'Peterson Cartridge',
      'Prvi Partizan / PPU',
      'Remington',
      'Sako',
      'Sellier & Bellot',
      'Starline',
      'Top Brass',
      'Weatherby',
      'Winchester',
    ],
    footer: _kCatalogFooter,
  ),
  _CategorySpec(
    heading: 'Bullets',
    intro:
        'Bullet weights, diameters, designs, jackets, and ballistic '
        'coefficients published by:',
    brands: [
      'Barnes',
      'Berger',
      'Federal',
      'Hammer Bullets',
      'Hornady',
      'Lapua',
      'Lehigh Defense',
      'Nosler',
      'Sierra',
      'Speer',
    ],
    footer: _kCatalogFooter,
  ),
  _CategorySpec(
    heading: 'Cartridge Specifications',
    intro:
        'Maximum dimensions, chamber drawings, and pressure standards '
        'published by:',
    brands: [
      'CIP (Commission Internationale Permanente)',
      'SAAMI (Sporting Arms and Ammunition Manufacturers Institute)',
    ],
    footer:
        "SAAMI and CIP are the two independent standards bodies that "
        'publish cartridge specifications used worldwide. Their open '
        'documentation is what makes interchangeable, safe ammunition '
        'possible.',
  ),
  _CategorySpec(
    heading: 'Firearms',
    intro:
        'Make, model, action, twist rate, and chambering data published '
        'by:',
    brands: [
      'Accuracy International',
      'Aero Precision',
      'Barrett',
      'Benelli',
      'Beretta',
      'Bergara',
      'Big Horn Armory',
      'Bravo Company Manufacturing (BCM)',
      'Browning',
      'Christensen Arms',
      'Colt',
      'CZ',
      'Daniel Defense',
      'FN America',
      'Franchi',
      'Glock',
      'Heckler & Koch',
      'Henry Repeating Arms',
      'Howa',
      'JP Enterprises',
      'Kimber',
      "Knight's Armament",
      'LWRC International',
      'Marlin (Ruger)',
      'Mossberg',
      'Remington',
      'Ruger',
      'Sako',
      'Savage Arms',
      'Sig Sauer',
      'Smith & Wesson',
      'Springfield Armory',
      'Stevens',
      'Stoeger',
      'Taurus',
      'Tikka',
      'Walther',
      'Weatherby',
      'Wilson Combat',
      'Winchester',
    ],
    footer: _kCatalogFooter,
  ),
  _CategorySpec(
    heading: 'Optics',
    intro:
        'Tube diameters, click values, max travel, focal-plane '
        'designations, and reticle catalogs published by:',
    brands: [
      'Aimpoint',
      'Arken Optics',
      'Athlon Optics',
      'Burris',
      'Bushnell',
      'Carl Zeiss',
      'DEON Optical Design (March)',
      'Element Optics',
      'EOTech',
      'Hensoldt',
      'Holosun',
      'Kahles',
      'Leupold',
      'Meopta',
      'Nightforce Optics',
      'Primary Arms',
      'Riton Optics',
      'Schmidt & Bender',
      'Sig Sauer',
      'Sightron',
      'Swarovski Optik',
      'Tangent Theta',
      'Trijicon',
      'Vortex Optics',
      'Zero Compromise Optic',
      'ZeroTech Optics',
    ],
    footer:
        "Their published scope data is what lets a shooter dial a "
        'firing solution with confidence. See the addendum below for '
        'how LoadOut handles reticle designs.',
  ),
  _CategorySpec(
    heading: 'Firearm Parts & Accessories',
    intro:
        'Trigger, barrel, stock, chassis, bipod, suppressor, and mount '
        'specifications published by:',
    brands: [
      'Accu-Tac',
      'Aero Precision',
      'AG Composites',
      'ALG Defense',
      'Apex Tactical Specialties',
      'ARC (American Rifle Company)',
      'Area 419',
      'Atlas Bipods',
      'Bartlein Barrels',
      'BCM',
      'Bell & Carlson',
      'Bergara',
      "Bix'n Andy",
      'Boyds Gun Stocks',
      'Brux Barrels',
      'Cadex Defence',
      'Christensen Arms',
      'CMC Triggers',
      'Dead Air Silencers',
      'Foundation Stocks',
      'Geissele Automatics',
      'Grayboe',
      'GRS Riflestocks',
      'Harris Engineering',
      'Hawk Hill Custom',
      'Hawkins Precision',
      'Hipertouch (Hiperfire)',
      'Jewell Triggers',
      'KRG',
      'Krieger Barrels',
      'LaRue Tactical',
      'Magpul Industries',
      'Manners Composite Stocks',
      'McMillan Fiberglass Stocks',
      'MDT',
      'Nightforce Optics',
      'Pacific Tool & Gauge',
      'Proof Research',
      'Reptilia Corp',
      'Rise Armament',
      'Rock Creek Barrels',
      'SilencerCo',
      'Spartan Precision',
      'Spuhr',
      'SureFire',
      'Thunder Beast Arms Corporation',
      'Timney Triggers',
      'TriggerTech',
      'Vortex Optics',
      'XLR Industries',
    ],
    footer: _kCatalogFooter,
  ),
  _CategorySpec(
    heading: 'Manufactured Ammunition',
    intro:
        'Factory-load muzzle velocities, bullet selections, and '
        'ballistic coefficients published by:',
    brands: [
      'Berger',
      'CCI',
      'Federal',
      'Hornady',
      'Sierra',
    ],
    footer:
        'Factory ammunition specifications give every shooter a '
        'starting point — even those who never reload — and let our '
        'ballistics solver line up against published numbers.',
  ),
];

/// Renders one category card. Uses a `Card` instead of an `ExpansionTile`
/// because the lists are short enough to read inline; collapsing them
/// would hide the actual point of the screen.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.spec});

  final _CategorySpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(spec.intro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              spec.brands.join(', '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              spec.footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Optics addendum ───────────────────────

/// Sits directly below the Optics card. Calls out the reticle-IP
/// posture (we use scope specs but ship our own reticle archetypes
/// rather than reproducing trademarked / licensed designs). This is
/// the screen where we name Horus Vision LLC explicitly so a Horus
/// reader sees that we know who owns the IP and respect it.
class _OpticsAddendumCard extends StatelessWidget {
  const _OpticsAddendumCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reticles — a note',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'We use scope manufacturer specifications (tube diameter, '
              'click value, max travel, focal plane) so users can match '
              'the math to their own scope. Reticle designs in LoadOut '
              'are LoadOut originals or public-domain patterns; we do '
              'not reproduce trademarked or licensed reticle designs '
              '(such as those owned by Horus Vision LLC or licensed to '
              "specific scope brands). If a user's scope ships with a "
              "brand-specific reticle, our 'Find by Scope' helper "
              'recommends the closest LoadOut archetype with the same '
              'hold-off math.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Ballistics math ───────────────────────

class _BallisticsMathCard extends StatelessWidget {
  const _BallisticsMathCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ballistic Math',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "LoadOut's solver builds on public ballistic-math "
              "literature: Pejsa stability formulas, Don Miller's "
              "stability formula, McCoy's exterior ballistics, and "
              "published exterior-ballistics math "
              '(Applied Ballistics for Long-Range Shooting, 2nd ed., '
              '2016). These are reference works in the public-shooting-'
              'science literature; LoadOut is not affiliated with '
              'Applied Ballistics LLC.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Open source software ───────────────────────

/// Pulled from the top-level `dependencies:` block in `pubspec.yaml`
/// on 2026-05-09. To refresh: re-read `pubspec.yaml` and update the
/// entries below — keep the list short, focused on packages a reader
/// would recognize, not the entire transitive tree.
const List<({String name, String credit, String role})> _kOssPackages = [
  (
    name: 'Flutter',
    credit: 'Google',
    role: 'The cross-platform UI framework underneath every screen.',
  ),
  (
    name: 'drift',
    credit: 'Simon Binder',
    role: 'Typed SQLite ORM that powers the on-device catalog and '
        'every user-data table.',
  ),
  (
    name: 'sqlite3 / sqlite3_flutter_libs',
    credit: 'Simon Binder, with the SQLite project',
    role: 'The bundled SQLite engine the app stores everything in.',
  ),
  (
    name: 'provider',
    credit: 'Remi Rousselet',
    role: 'Dependency injection and state propagation across the '
        'widget tree.',
  ),
  (
    name: 'intl / flutter_localizations',
    credit: 'Dart team',
    role: 'Internationalization plumbing — six languages today.',
  ),
  (
    name: 'firebase_core / firebase_auth',
    credit: 'Google',
    role: 'Authentication for the optional cloud-backup feature.',
  ),
  (
    name: 'cryptography',
    credit: 'Gohilla Ltd.',
    role: 'AES-256-GCM and PBKDF2 for end-to-end-encrypted backups.',
  ),
  (
    name: 'flutter_blue_plus',
    credit: 'Charles Crete and contributors',
    role: 'Bluetooth Low Energy support for Kestrel meters and '
        'rangefinders.',
  ),
  (
    name: 'sensors_plus',
    credit: 'Flutter Community',
    role: 'Accelerometer, gyroscope, and magnetometer streams for the '
        'Range Day setup card.',
  ),
  (
    name: 'google_mlkit_text_recognition',
    credit: 'Google',
    role: 'On-device OCR for the photo-import flow — runs entirely '
        'offline.',
  ),
  (
    name: 'pdf',
    credit: 'David PHAM-VAN',
    role: 'Pure-Dart PDF generation for the printable notebook page.',
  ),
  (
    name: 'qr_flutter / mobile_scanner',
    credit: 'Lukas Klingsbo, Julian Steenbakker, and contributors',
    role: 'QR encode and decode for the offline peer-to-peer recipe '
        'share.',
  ),
];

class _OpenSourceCard extends StatelessWidget {
  const _OpenSourceCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open Source Software',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'A few of the major open-source packages LoadOut is '
              'built on:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (final pkg in _kOssPackages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: pkg.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' — '),
                      TextSpan(text: '${pkg.credit}. '),
                      TextSpan(
                        text: pkg.role,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              "LoadOut wouldn't exist without the Flutter ecosystem. "
              'Thank you to every contributor.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
